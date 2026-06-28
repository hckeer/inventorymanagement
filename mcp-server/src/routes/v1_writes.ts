import type { Express, RequestHandler, Response } from "express";
import { z } from "zod";

import { fail, ok } from "../lib/api/envelope.js";
import {
  ErrorCodes,
  httpStatusForCode,
  mapErpnextError,
} from "../lib/api/codes.js";
import { ErpnextError } from "../lib/erpnext_client.js";
import type { ErpnextSessionClient } from "../lib/erpnext_session_client.js";
import type { AuthenticatedRequest } from "../middleware/auth.js";

const customerCreateSchema = z.object({
  customer_name: z.string().min(1),
  mobile_no: z.string().optional(),
  email_id: z.union([z.string().email(), z.literal("")]).optional(),
  id_document: z.string().optional(),
  customer_type: z.string().optional(),
  customer_group: z.string().optional(),
  territory: z.string().optional(),
});

const customerUpdateSchema = z.object({
  customer_name: z.string().min(1).optional(),
  mobile_no: z.string().optional(),
  email_id: z.union([z.string().email(), z.literal("")]).optional(),
  id_document: z.string().optional(),
});

const itemCreateSchema = z.object({
  item_code: z.string().optional(),
  item_name: z.string().min(1),
  item_group: z.string().min(1),
  standard_rate: z.number().nonnegative().optional(),
  has_serial_no: z.boolean().optional(),
  serial_no: z.string().optional(),
});

const itemUpdateSchema = z.object({
  item_name: z.string().min(1).optional(),
  item_group: z.string().min(1).optional(),
  standard_rate: z.number().nonnegative().optional(),
  disabled: z.union([z.literal(0), z.literal(1)]).optional(),
});

const serialCreateSchema = z.object({
  serial_no: z.string().min(1),
  item_code: z.string().min(1),
  warehouse: z.string().optional(),
});

export function slugItemCode(name: string): string {
  const slug = name
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug || "ITEM";
}

function handleWriteError(res: Response, error: unknown): void {
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

function cleanOptional(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

async function createSerialIfNeeded(
  client: ErpnextSessionClient,
  itemCode: string,
  serialNo: string | undefined,
  warehouse?: string,
): Promise<Record<string, unknown> | null> {
  const serial = cleanOptional(serialNo);
  if (!serial) {
    return null;
  }

  const rentalWarehouse = warehouse ?? (await client.resolveRentalWarehouse());
  return client.createResource<Record<string, unknown>>("Serial No", {
    serial_no: serial,
    item_code: itemCode,
    warehouse: rentalWarehouse,
  });
}

export function registerV1WriteRoutes(app: Express, auth: RequestHandler): void {
  app.post("/api/v1/customers", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const parsed = customerCreateSchema.safeParse(req.body);
      if (!parsed.success) {
        res
          .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
          .json(fail(ErrorCodes.VALIDATION_ERROR, "Invalid customer payload"));
        return;
      }

      const body = parsed.data;
      const customer = await req.erpnext!.createResource<Record<string, unknown>>(
        "Customer",
        {
          customer_name: body.customer_name.trim(),
          customer_type: body.customer_type ?? "Individual",
          customer_group: body.customer_group ?? "Individual",
          territory: body.territory ?? "All Territories",
          mobile_no: cleanOptional(body.mobile_no),
          email_id: cleanOptional(body.email_id),
          id_document: cleanOptional(body.id_document),
        },
      );
      res.status(201).json(ok({ customer }));
    } catch (error) {
      handleWriteError(res, error);
    }
  });

  app.patch("/api/v1/customers/:name", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const parsed = customerUpdateSchema.safeParse(req.body);
      if (!parsed.success) {
        res
          .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
          .json(fail(ErrorCodes.VALIDATION_ERROR, "Invalid customer payload"));
        return;
      }

      const patch: Record<string, unknown> = {};
      const body = parsed.data;
      if (body.customer_name !== undefined) {
        patch.customer_name = body.customer_name.trim();
      }
      if (body.mobile_no !== undefined) {
        patch.mobile_no = cleanOptional(body.mobile_no);
      }
      if (body.email_id !== undefined) {
        patch.email_id = cleanOptional(body.email_id);
      }
      if (body.id_document !== undefined) {
        patch.id_document = cleanOptional(body.id_document);
      }

      const customer = await req.erpnext!.updateResource<Record<string, unknown>>(
        "Customer",
        String(req.params.name),
        patch,
      );
      res.json(ok({ customer }));
    } catch (error) {
      handleWriteError(res, error);
    }
  });

  app.post("/api/v1/items", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const parsed = itemCreateSchema.safeParse(req.body);
      if (!parsed.success) {
        res
          .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
          .json(fail(ErrorCodes.VALIDATION_ERROR, "Invalid item payload"));
        return;
      }

      const body = parsed.data;
      const itemCode = cleanOptional(body.item_code) ?? slugItemCode(body.item_name);
      const hasSerial = body.has_serial_no ?? true;

      const item = await req.erpnext!.createResource<Record<string, unknown>>("Item", {
        item_code: itemCode,
        item_name: body.item_name.trim(),
        item_group: body.item_group.trim(),
        stock_uom: "Nos",
        is_stock_item: 1,
        maintain_stock: 1,
        has_serial_no: hasSerial ? 1 : 0,
        standard_rate: body.standard_rate ?? 0,
      });

      const serial = hasSerial
        ? await createSerialIfNeeded(req.erpnext!, itemCode, body.serial_no)
        : null;

      res.status(201).json(ok({ item, serial }));
    } catch (error) {
      handleWriteError(res, error);
    }
  });

  app.patch("/api/v1/items/:item_code", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const parsed = itemUpdateSchema.safeParse(req.body);
      if (!parsed.success) {
        res
          .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
          .json(fail(ErrorCodes.VALIDATION_ERROR, "Invalid item payload"));
        return;
      }

      const patch: Record<string, unknown> = {};
      const body = parsed.data;
      if (body.item_name !== undefined) {
        patch.item_name = body.item_name.trim();
      }
      if (body.item_group !== undefined) {
        patch.item_group = body.item_group.trim();
      }
      if (body.standard_rate !== undefined) {
        patch.standard_rate = body.standard_rate;
      }
      if (body.disabled !== undefined) {
        patch.disabled = body.disabled;
      }

      const item = await req.erpnext!.updateResource<Record<string, unknown>>(
        "Item",
        String(req.params.item_code),
        patch,
      );
      res.json(ok({ item }));
    } catch (error) {
      handleWriteError(res, error);
    }
  });

  app.post("/api/v1/serials", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const parsed = serialCreateSchema.safeParse(req.body);
      if (!parsed.success) {
        res
          .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
          .json(fail(ErrorCodes.VALIDATION_ERROR, "Invalid serial payload"));
        return;
      }

      const body = parsed.data;
      const warehouse =
        cleanOptional(body.warehouse) ??
        (await req.erpnext!.resolveRentalWarehouse());

      const serial = await req.erpnext!.createResource<Record<string, unknown>>(
        "Serial No",
        {
          serial_no: body.serial_no.trim(),
          item_code: body.item_code.trim(),
          warehouse,
        },
      );
      res.status(201).json(ok({ serial }));
    } catch (error) {
      handleWriteError(res, error);
    }
  });
}
