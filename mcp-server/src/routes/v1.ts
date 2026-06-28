import type { Express, Response } from "express";
import { z } from "zod";

import { fail, ok } from "../lib/api/envelope.js";
import {
  ErrorCodes,
  httpStatusForCode,
  mapErpnextError,
} from "../lib/api/codes.js";
import { createAccessToken } from "../lib/auth/jwt.js";
import {
  loginToErpnext,
  logoutFromErpnext,
} from "../lib/auth/erpnext_login.js";
import type { SessionStore } from "../lib/auth/session_store.js";
import type { AppConfig } from "../lib/config.js";
import { ErpnextError } from "../lib/erpnext_client.js";
import {
  createAuthMiddleware,
  type AuthenticatedRequest,
} from "../middleware/auth.js";
import type { WarehouseService } from "../app.js";
import { registerV1WriteRoutes } from "./v1_writes.js";
import { registerV1RentalRoutes } from "./v1_rentals.js";

const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

function handleV1Error(res: Response, error: unknown): void {
  if (error instanceof ErpnextError) {
    const code = mapErpnextError(error.status, error.message, error.detail);
    res.status(httpStatusForCode(code)).json(
      fail(code, error.message, {
        status: error.status,
        detail: error.detail,
      }),
    );
    return;
  }
  if (error instanceof Error) {
    res
      .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
      .json(fail(ErrorCodes.VALIDATION_ERROR, error.message));
    return;
  }
  res
    .status(500)
    .json(fail(ErrorCodes.ERPNEXT_UNAVAILABLE, "Unknown error"));
}

export function registerV1Routes(
  app: Express,
  config: AppConfig,
  sessionStore: SessionStore,
  warehouse: WarehouseService,
): void {
  const auth = createAuthMiddleware(sessionStore, config.jwtSecret, config.erpnextUrl);

  registerV1WriteRoutes(app, auth);
  registerV1RentalRoutes(app, auth);

  app.post("/api/v1/auth/login", async (req, res) => {
    try {
      const parsed = loginSchema.safeParse(req.body);
      if (!parsed.success) {
        res
          .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
          .json(fail(ErrorCodes.VALIDATION_ERROR, "username and password are required"));
        return;
      }

      const login = await loginToErpnext(
        config.erpnextUrl,
        parsed.data.username,
        parsed.data.password,
      );
      const session = sessionStore.create({
        sid: login.sid,
        userId: login.userId,
        email: login.email,
        fullName: login.fullName,
        roles: login.roles,
      });
      const accessToken = createAccessToken(
        sessionStore.toJwtPayload(session),
        config.jwtSecret,
        config.sessionTtlSeconds,
      );

      res.json(
        ok({
          access_token: accessToken,
          expires_in: config.sessionTtlSeconds,
          user: {
            name: login.fullName,
            email: login.email,
            roles: login.roles,
          },
        }),
      );
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.post("/api/v1/auth/logout", auth, async (req: AuthenticatedRequest, res) => {
    try {
      if (req.sessionId && req.erpnext) {
        const session = sessionStore.get(req.sessionId);
        if (session) {
          await logoutFromErpnext(config.erpnextUrl, session.sid);
          sessionStore.delete(req.sessionId);
        }
      }
      res.json(ok({ logged_out: true }));
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.get("/api/v1/auth/me", auth, (req: AuthenticatedRequest, res) => {
    res.json(
      ok({
        name: req.user?.fullName,
        email: req.user?.email,
        roles: req.user?.roles ?? [],
      }),
    );
  });

  app.get("/api/v1/items", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const filters: unknown[][] = [["Item", "disabled", "=", 0]];
      const group = String(req.query.group ?? "").trim();
      const hasSerial = req.query.has_serial;
      if (group) {
        filters.push(["Item", "item_group", "=", group]);
      }
      if (hasSerial === "1" || hasSerial === "true") {
        filters.push(["Item", "has_serial_no", "=", 1]);
      } else if (hasSerial === "0" || hasSerial === "false") {
        filters.push(["Item", "has_serial_no", "=", 0]);
      }

      const items = await req.erpnext!.listResource<Record<string, unknown>>("Item", {
        fields: [
          "name",
          "item_name",
          "item_group",
          "has_serial_no",
          "standard_rate",
          "disabled",
        ],
        filters,
        orderBy: "item_name asc",
        limit: 500,
      });
      res.json(ok({ items }));
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.get("/api/v1/items/:item_code", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const itemCode = String(req.params.item_code);
      const client = req.erpnext!;
      const item = await client.getResource<Record<string, unknown>>("Item", itemCode);
      const rentalWarehouse = await client.resolveRentalWarehouse();
      const qtyOnHand = await client.getStockBalance(itemCode, rentalWarehouse);
      const serials = await client.listResource<Record<string, unknown>>("Serial No", {
        fields: ["name", "item_code", "warehouse", "status"],
        filters: [["Serial No", "item_code", "=", itemCode]],
        limit: 500,
      });
      res.json(
        ok({
          item,
          serial_count: serials.length,
          serials,
          qty_on_hand: qtyOnHand,
          rental_warehouse: rentalWarehouse,
        }),
      );
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.get("/api/v1/items/:item_code/serials", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const itemCode = String(req.params.item_code);
      const serials = await req.erpnext!.listResource<Record<string, unknown>>("Serial No", {
        fields: ["name", "item_code", "warehouse", "status"],
        filters: [["Serial No", "item_code", "=", itemCode]],
        limit: 500,
      });
      res.json(ok({ serials }));
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.get("/api/v1/serials/:serial", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const serial = await req.erpnext!.getResource<Record<string, unknown>>(
        "Serial No",
        String(req.params.serial),
      );
      res.json(ok({ serial }));
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.get("/api/v1/customers", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const customers = await req.erpnext!.listResource<Record<string, unknown>>("Customer", {
        fields: ["name", "customer_name", "id_document", "mobile_no", "email_id"],
        orderBy: "customer_name asc",
        limit: 500,
      });
      res.json(ok({ customers }));
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.get("/api/v1/customers/:name", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const customer = await req.erpnext!.getResource<Record<string, unknown>>(
        "Customer",
        String(req.params.name),
      );
      res.json(ok({ customer }));
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.get("/api/v1/rentals", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const filters: unknown[][] = [];
      const status = String(req.query.status ?? "").trim();
      const customer = String(req.query.customer ?? "").trim();
      if (status) {
        filters.push(["Equipment Rental", "status", "=", status]);
      }
      if (customer) {
        filters.push(["Equipment Rental", "customer", "=", customer]);
      }

      const rentals = await req.erpnext!.listResource<Record<string, unknown>>(
        "Equipment Rental",
        {
          fields: [
            "name",
            "customer",
            "start_date",
            "end_date",
            "status",
            "deposit_amount",
            "deposit_paid",
            "docstatus",
          ],
          filters,
          orderBy: "modified desc",
          limit: 500,
        },
      );
      res.json(ok({ rentals }));
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.get("/api/v1/rentals/:name", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const rental = await req.erpnext!.getResource<Record<string, unknown>>(
        "Equipment Rental",
        String(req.params.name),
      );
      res.json(ok({ rental }));
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  app.get("/api/v1/dashboard/stats", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const client = req.erpnext!;
      const [activeRentals, overdueRentals, items, activeRentalDocs] = await Promise.all([
        client.getCount("Equipment Rental", [["Equipment Rental", "status", "=", "Active"]]),
        client.getCount("Equipment Rental", [["Equipment Rental", "status", "=", "Overdue"]]),
        client.listResource<Record<string, unknown>>("Item", {
          fields: ["name", "has_serial_no"],
          filters: [["Item", "disabled", "=", 0]],
          limit: 500,
        }),
        client.listResource<Record<string, unknown>>("Equipment Rental", {
          fields: ["name"],
          filters: [["Equipment Rental", "status", "=", "Active"]],
          limit: 500,
        }),
      ]);

      const rentedSerials = new Set<string>();
      for (const rental of activeRentalDocs) {
        const detail = await client.getResource<{
          items?: Array<{ line_type?: string; serial_no?: string }>;
        }>("Equipment Rental", String(rental.name));
        for (const line of detail.items ?? []) {
          if (line.line_type === "serialized" && line.serial_no) {
            rentedSerials.add(line.serial_no);
          }
        }
      }

      const serialItems = items.filter(
        (item: Record<string, unknown>) => Number(item.has_serial_no) === 1,
      );
      let availableSerialized = 0;
      for (const item of serialItems) {
        const serials = await client.listResource<{ name: string }>("Serial No", {
          fields: ["name"],
          filters: [["Serial No", "item_code", "=", String(item.name)]],
          limit: 500,
        });
        availableSerialized += serials.filter(
          (s: { name: string }) => !rentedSerials.has(s.name),
        ).length;
      }

      res.json(
        ok({
          active_rentals: activeRentals,
          overdue_rentals: overdueRentals,
          available_serialized: availableSerialized,
          item_count: items.length,
        }),
      );
    } catch (error) {
      handleV1Error(res, error);
    }
  });

  // Warehouse v1 aliases (scanner-web parity)
  app.post("/api/v1/warehouse/audit", async (req, res) => {
    await forwardWarehouse(warehouse, config, req, res, async () => {
      const containerBarcode = String(req.body?.container_barcode ?? "").trim();
      if (!containerBarcode) {
        throw new Error("container_barcode is required");
      }
      return warehouse.auditContainer(containerBarcode);
    });
  });

  app.post("/api/v1/warehouse/session/start", async (req, res) => {
    await forwardWarehouse(warehouse, config, req, res, async () => {
      const mode = req.body?.mode;
      if (mode !== "dispatch" && mode !== "return") {
        throw new Error('mode must be "dispatch" or "return"');
      }
      return warehouse.startSession({
        mode,
        source_barcode: String(req.body?.source_barcode ?? "").trim(),
        destination_barcode: String(req.body?.destination_barcode ?? "").trim(),
      });
    });
  });

  app.post("/api/v1/warehouse/session/scan", async (req, res) => {
    await forwardWarehouse(warehouse, config, req, res, async () =>
      warehouse.scanSerial({
        session_id: String(req.body?.session_id ?? "").trim(),
        serial: String(req.body?.serial ?? "").trim(),
      }),
    );
  });

  app.post("/api/v1/warehouse/session/end", async (req, res) => {
    await forwardWarehouse(warehouse, config, req, res, async () =>
      warehouse.endSession({
        session_id: String(req.body?.session_id ?? "").trim(),
      }),
    );
  });

  app.post("/api/v1/warehouse/session/confirm", async (req, res) => {
    await forwardWarehouse(warehouse, config, req, res, async () =>
      warehouse.confirmSession({
        session_id: String(req.body?.session_id ?? "").trim(),
        proceed_anyway: Boolean(req.body?.proceed_anyway),
        reason: req.body?.reason ? String(req.body.reason) : undefined,
      }),
    );
  });
}

async function forwardWarehouse(
  _warehouse: WarehouseService,
  config: AppConfig,
  req: AuthenticatedRequest,
  res: Response,
  handler: () => Promise<unknown>,
): Promise<void> {
  if (config.apiKey) {
    const header = req.header("x-api-key");
    if (header !== config.apiKey) {
      res
        .status(httpStatusForCode(ErrorCodes.UNAUTHORIZED))
        .json(fail(ErrorCodes.UNAUTHORIZED, "Unauthorized"));
      return;
    }
  }

  try {
    const result = await handler();
    res.json(ok(result));
  } catch (error) {
    handleV1Error(res, error);
  }
}
