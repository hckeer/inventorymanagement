import type { Express, RequestHandler, Response } from "express";
import { z } from "zod";

import { fail, ok } from "../lib/api/envelope.js";
import {
  ErrorCodes,
  httpStatusForCode,
  mapErpnextError,
} from "../lib/api/codes.js";
import { ErpnextError } from "../lib/erpnext_client.js";
import type { AuthenticatedRequest } from "../middleware/auth.js";

const rentalLineSchema = z.object({
  line_type: z.enum(["serialized", "qty"]),
  item_code: z.string().min(1),
  serial_no: z.string().optional(),
  qty: z.number().positive().optional(),
  daily_rate_snapshot: z.number().nonnegative().optional(),
});

const rentalCreateSchema = z.object({
  customer: z.string().min(1),
  start_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  end_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  deposit_amount: z.number().nonnegative().optional(),
  deposit_paid: z.boolean().optional(),
  notes: z.string().optional(),
  items: z.array(rentalLineSchema).min(1),
});

const rentalUpdateSchema = z.object({
  customer: z.string().min(1).optional(),
  start_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  end_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  deposit_amount: z.number().nonnegative().optional(),
  deposit_paid: z.boolean().optional(),
  notes: z.string().optional(),
  items: z.array(rentalLineSchema).min(1).optional(),
});

const damageNotesSchema = z.object({
  damage_notes: z.string(),
});

const DOCTYPE = "Equipment Rental";

function handleRentalError(res: Response, error: unknown): void {
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

export function buildRentalItemRows(
  lines: z.infer<typeof rentalLineSchema>[],
): Record<string, unknown>[] {
  return lines.map((line) => {
    if (line.line_type === "serialized") {
      return {
        line_type: "serialized",
        item_code: line.item_code.trim(),
        serial_no: cleanOptional(line.serial_no),
        qty: 1,
        daily_rate_snapshot: line.daily_rate_snapshot,
      };
    }
    return {
      line_type: "qty",
      item_code: line.item_code.trim(),
      qty: line.qty ?? 1,
      daily_rate_snapshot: line.daily_rate_snapshot,
    };
  });
}

export function buildRentalPayload(
  body: z.infer<typeof rentalCreateSchema> | z.infer<typeof rentalUpdateSchema>,
  partial = false,
): Record<string, unknown> {
  const payload: Record<string, unknown> = {};
  if (!partial || body.customer !== undefined) {
    if ("customer" in body && body.customer !== undefined) {
      payload.customer = body.customer.trim();
    }
  }
  if (!partial || body.start_date !== undefined) {
    if ("start_date" in body && body.start_date !== undefined) {
      payload.start_date = body.start_date;
    }
  }
  if (!partial || body.end_date !== undefined) {
    if ("end_date" in body && body.end_date !== undefined) {
      payload.end_date = body.end_date;
    }
  }
  if (!partial || body.deposit_amount !== undefined) {
    if ("deposit_amount" in body && body.deposit_amount !== undefined) {
      payload.deposit_amount = body.deposit_amount;
    }
  }
  if (!partial || body.deposit_paid !== undefined) {
    if ("deposit_paid" in body && body.deposit_paid !== undefined) {
      payload.deposit_paid = body.deposit_paid ? 1 : 0;
    }
  }
  if (!partial || body.notes !== undefined) {
    if ("notes" in body && body.notes !== undefined) {
      payload.notes = cleanOptional(body.notes);
    }
  }
  if ("items" in body && body.items !== undefined) {
    payload.items = buildRentalItemRows(body.items);
  }
  if (!partial) {
    payload.naming_series = "RENT-.YYYY.-";
    payload.status = "Draft";
  }
  return payload;
}

async function getRentalOrThrow(
  client: AuthenticatedRequest["erpnext"],
  name: string,
): Promise<Record<string, unknown>> {
  const rental = await client!.getResource<Record<string, unknown>>(DOCTYPE, name);
  return rental;
}

export function registerV1RentalRoutes(app: Express, auth: RequestHandler): void {
  app.post("/api/v1/rentals", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const parsed = rentalCreateSchema.safeParse(req.body);
      if (!parsed.success) {
        res
          .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
          .json(fail(ErrorCodes.VALIDATION_ERROR, "Invalid rental payload"));
        return;
      }

      const payload = buildRentalPayload(parsed.data);
      const rental = await req.erpnext!.createResource<Record<string, unknown>>(
        DOCTYPE,
        payload,
      );
      res.status(201).json(ok({ rental }));
    } catch (error) {
      handleRentalError(res, error);
    }
  });

  app.patch("/api/v1/rentals/:name", auth, async (req: AuthenticatedRequest, res) => {
    try {
      const parsed = rentalUpdateSchema.safeParse(req.body);
      if (!parsed.success) {
        res
          .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
          .json(fail(ErrorCodes.VALIDATION_ERROR, "Invalid rental payload"));
        return;
      }

      const name = String(req.params.name);
      const existing = await getRentalOrThrow(req.erpnext, name);
      if (Number(existing.docstatus ?? 0) !== 0) {
        res
          .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
          .json(fail(ErrorCodes.VALIDATION_ERROR, "Only draft rentals can be edited"));
        return;
      }

      const patch = buildRentalPayload(parsed.data, true);
      const rental = await req.erpnext!.updateResource<Record<string, unknown>>(
        DOCTYPE,
        name,
        patch,
      );
      res.json(ok({ rental }));
    } catch (error) {
      handleRentalError(res, error);
    }
  });

  app.post(
    "/api/v1/rentals/:name/submit",
    auth,
    async (req: AuthenticatedRequest, res) => {
      try {
        const name = String(req.params.name);
        const existing = await getRentalOrThrow(req.erpnext, name);
        if (Number(existing.docstatus ?? 0) === 1) {
          res.json(ok({ rental: existing }));
          return;
        }
        if (Number(existing.docstatus ?? 0) !== 0) {
          res
            .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
            .json(fail(ErrorCodes.VALIDATION_ERROR, "Rental cannot be submitted"));
          return;
        }

        await req.erpnext!.submitDocument(DOCTYPE, name);
        const rental = await getRentalOrThrow(req.erpnext, name);
        res.json(ok({ rental }));
      } catch (error) {
        handleRentalError(res, error);
      }
    },
  );

  app.post(
    "/api/v1/rentals/:name/return",
    auth,
    async (req: AuthenticatedRequest, res) => {
      try {
        const name = String(req.params.name);
        await req.erpnext!.runDocMethod<Record<string, unknown>>(
          DOCTYPE,
          name,
          "return_rental",
        );
        const rental = await getRentalOrThrow(req.erpnext, name);
        res.json(ok({ rental }));
      } catch (error) {
        handleRentalError(res, error);
      }
    },
  );

  app.patch(
    "/api/v1/rentals/:name/lines/:idx/damage",
    auth,
    async (req: AuthenticatedRequest, res) => {
      try {
        const parsed = damageNotesSchema.safeParse(req.body);
        if (!parsed.success) {
          res
            .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
            .json(fail(ErrorCodes.VALIDATION_ERROR, "damage_notes is required"));
          return;
        }

        const name = String(req.params.name);
        const idx = Number(req.params.idx);
        if (!Number.isInteger(idx) || idx < 1) {
          res
            .status(httpStatusForCode(ErrorCodes.VALIDATION_ERROR))
            .json(fail(ErrorCodes.VALIDATION_ERROR, "Invalid line index"));
          return;
        }

        const rental = await getRentalOrThrow(req.erpnext, name);
        const items = (rental.items as Array<Record<string, unknown>> | undefined) ?? [];
        const row = items.find((line) => Number(line.idx) === idx);
        if (!row) {
          res
            .status(httpStatusForCode(ErrorCodes.NOT_FOUND))
            .json(fail(ErrorCodes.NOT_FOUND, `Line ${idx} not found`));
          return;
        }

        row.damage_notes = parsed.data.damage_notes;
        const updated = await req.erpnext!.updateResource<Record<string, unknown>>(
          DOCTYPE,
          name,
          { items },
        );
        res.json(ok({ rental: updated }));
      } catch (error) {
        handleRentalError(res, error);
      }
    },
  );
}
