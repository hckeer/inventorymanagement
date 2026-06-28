import type { Express, Request, Response } from "express";

import { loadConfig, type AppConfig } from "./lib/config.js";
import { SessionStore } from "./lib/auth/session_store.js";
import { ErpnextClient } from "./lib/erpnext_client.js";
import { registerV1Routes } from "./routes/v1.js";
import { auditContainer } from "./tools/audit_container.js";
import {
  confirmSession,
  ConfirmBlockedError,
} from "./tools/confirm_session.js";
import { endSession } from "./tools/end_session.js";
import { scanSerial } from "./tools/scan_serial.js";
import { startSession } from "./tools/start_session.js";
import { SessionNotFoundError } from "./lib/sessions.js";
import { ErpnextError } from "./lib/erpnext_client.js";

export function createWarehouseService(config: AppConfig) {
  const client = new ErpnextClient(config);

  return {
    client,
    auditContainer: (containerBarcode: string) =>
      auditContainer(client, containerBarcode),
    startSession: (input: Parameters<typeof startSession>[1]) =>
      startSession(client, input),
    scanSerial: (input: Parameters<typeof scanSerial>[1]) =>
      scanSerial(client, input),
    endSession,
    confirmSession: (input: Parameters<typeof confirmSession>[1]) =>
      confirmSession(client, input),
  };
}

export type WarehouseService = ReturnType<typeof createWarehouseService>;

function requireApiKey(config: AppConfig, req: Request, res: Response): boolean {
  if (!config.apiKey) {
    return true;
  }
  const header = req.header("x-api-key");
  if (header !== config.apiKey) {
    res.status(401).json({ error: "Unauthorized" });
    return false;
  }
  return true;
}

function handleError(res: Response, error: unknown): void {
  if (error instanceof SessionNotFoundError) {
    res.status(404).json({ error: error.message });
    return;
  }
  if (error instanceof ConfirmBlockedError) {
    res.status(409).json({
      error: error.message,
      missing: error.missing,
      unexpected: error.unexpected,
    });
    return;
  }
  if (error instanceof ErpnextError) {
    res.status(error.status >= 400 ? error.status : 502).json({
      error: error.message,
      detail: error.detail,
    });
    return;
  }
  if (error instanceof Error) {
    res.status(400).json({ error: error.message });
    return;
  }
  res.status(500).json({ error: "Unknown error" });
}

export function registerRoutes(
  app: Express,
  service: WarehouseService,
  config: AppConfig,
  sessionStore: SessionStore,
): void {
  app.get("/health", (_req, res) => {
    res.json({ status: "ok", service: "lightbenders-mcp-server" });
  });

  app.post("/api/audit_container", async (req, res) => {
    if (!requireApiKey(config, req, res)) return;
    try {
      const containerBarcode = String(req.body?.container_barcode ?? "").trim();
      if (!containerBarcode) {
        res.status(400).json({ error: "container_barcode is required" });
        return;
      }
      const result = await service.auditContainer(containerBarcode);
      res.json(result);
    } catch (error) {
      handleError(res, error);
    }
  });

  app.post("/api/start_session", async (req, res) => {
    if (!requireApiKey(config, req, res)) return;
    try {
      const mode = req.body?.mode;
      const sourceBarcode = String(req.body?.source_barcode ?? "").trim();
      const destinationBarcode = String(req.body?.destination_barcode ?? "").trim();
      if (mode !== "dispatch" && mode !== "return") {
        res.status(400).json({ error: 'mode must be "dispatch" or "return"' });
        return;
      }
      if (!sourceBarcode || !destinationBarcode) {
        res.status(400).json({ error: "source_barcode and destination_barcode are required" });
        return;
      }
      const result = await service.startSession({
        mode,
        source_barcode: sourceBarcode,
        destination_barcode: destinationBarcode,
      });
      res.json(result);
    } catch (error) {
      handleError(res, error);
    }
  });

  app.post("/api/scan_serial", async (req, res) => {
    if (!requireApiKey(config, req, res)) return;
    try {
      const sessionId = String(req.body?.session_id ?? "").trim();
      const serial = String(req.body?.serial ?? "").trim();
      if (!sessionId || !serial) {
        res.status(400).json({ error: "session_id and serial are required" });
        return;
      }
      const result = await service.scanSerial({ session_id: sessionId, serial });
      res.json(result);
    } catch (error) {
      handleError(res, error);
    }
  });

  app.post("/api/end_session", async (req, res) => {
    if (!requireApiKey(config, req, res)) return;
    try {
      const sessionId = String(req.body?.session_id ?? "").trim();
      if (!sessionId) {
        res.status(400).json({ error: "session_id is required" });
        return;
      }
      const result = await service.endSession({ session_id: sessionId });
      res.json(result);
    } catch (error) {
      handleError(res, error);
    }
  });

  app.post("/api/confirm_session", async (req, res) => {
    if (!requireApiKey(config, req, res)) return;
    try {
      const sessionId = String(req.body?.session_id ?? "").trim();
      if (!sessionId) {
        res.status(400).json({ error: "session_id is required" });
        return;
      }
      const result = await service.confirmSession({
        session_id: sessionId,
        proceed_anyway: Boolean(req.body?.proceed_anyway),
        reason: req.body?.reason ? String(req.body.reason) : undefined,
      });
      res.json(result);
    } catch (error) {
      handleError(res, error);
    }
  });

  registerV1Routes(app, config, sessionStore, service);
}

export function createAppConfigFromEnv(): AppConfig {
  return loadConfig();
}
