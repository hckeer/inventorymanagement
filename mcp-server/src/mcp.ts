import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

import type { WarehouseService } from "./app.js";

export async function registerMcpServer(service: WarehouseService): Promise<void> {
  const server = new McpServer({
    name: "lightbenders-warehouse",
    version: "0.1.0",
  });

  server.registerTool(
    "audit_container",
    {
      title: "Audit warehouse container",
      description:
        "Compare container expected contents (with assembly expansion) vs Stock Balance in ERPNext.",
      inputSchema: {
        container_barcode: z.string().describe("Container sticker barcode, e.g. TRAY-004"),
      },
    },
    async ({ container_barcode }) => {
      const result = await service.auditContainer(container_barcode);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.registerTool(
    "start_session",
    {
      title: "Start dispatch or return scan session",
      inputSchema: {
        mode: z.enum(["dispatch", "return"]),
        source_barcode: z.string(),
        destination_barcode: z.string(),
      },
    },
    async (input) => {
      const result = await service.startSession(input);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.registerTool(
    "scan_serial",
    {
      title: "Add serial to open session",
      inputSchema: {
        session_id: z.string(),
        serial: z.string(),
      },
    },
    async (input) => {
      const result = await service.scanSerial(input);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.registerTool(
    "end_session",
    {
      title: "Reconcile scanned serials vs expected",
      inputSchema: {
        session_id: z.string(),
      },
    },
    async ({ session_id }) => {
      const result = await service.endSession({ session_id });
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  server.registerTool(
    "confirm_session",
    {
      title: "Confirm session and create Stock Entry",
      inputSchema: {
        session_id: z.string(),
        proceed_anyway: z.boolean().optional(),
        reason: z.string().optional(),
      },
    },
    async (input) => {
      const result = await service.confirmSession(input);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  const transport = new StdioServerTransport();
  await server.connect(transport);
}
