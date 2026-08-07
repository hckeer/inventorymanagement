import type { Express } from "express";
import { z } from "zod";
import { fail, ok } from "../lib/api/envelope.js";
import { SupabaseRestError, SupabaseRestClient } from "../lib/supabase_rest_client.js";
import type { SupabaseAuthenticatedRequest } from "../middleware/supabase_auth.js";

const productSchema = z.object({ name: z.string().min(1), sku: z.string().optional(), category_id: z.string().uuid().nullable().optional(), manufacturer_id: z.string().uuid().nullable().optional(), tracking_mode: z.enum(["serialized", "quantity"]), daily_rate: z.number().nonnegative().default(0), notes: z.string().optional(), identifiers: z.array(z.object({ identifier: z.string().min(1), identifier_type: z.enum(["ean_13", "upc_a", "internal"]) })).default([]), initial_quantity: z.number().int().nonnegative().default(0) });

export function registerInventoryV1Routes(app: Express, auth: ReturnType<typeof import("../middleware/supabase_auth.js").createSupabaseAuthMiddleware>, database: SupabaseRestClient): void {
  app.get("/api/v1/auth/me", auth, (req: SupabaseAuthenticatedRequest, res) => res.json(ok({ id: req.user?.id, email: req.user?.email })));
  app.get("/api/v1/barcodes/:identifier", auth, async (req, res) => {
    try { res.json(ok({ lookup: await database.rpc("lookup_barcode", { p_identifier: String(req.params.identifier).trim() }) })); }
    catch (error) { handleError(res, error); }
  });
  app.post("/api/v1/products", auth, async (req, res) => {
    const parsed = productSchema.safeParse(req.body);
    if (!parsed.success) { res.status(422).json(fail("VALIDATION_ERROR", "Invalid product payload")); return; }
    try { res.status(201).json(ok({ product: await database.rpc("create_product", { p_name: parsed.data.name, p_sku: parsed.data.sku ?? "", p_category_id: parsed.data.category_id ?? null, p_manufacturer_id: parsed.data.manufacturer_id ?? null, p_tracking_mode: parsed.data.tracking_mode, p_daily_rate: parsed.data.daily_rate, p_notes: parsed.data.notes ?? "", p_identifiers: parsed.data.identifiers, p_initial_quantity: parsed.data.initial_quantity }) })); }
    catch (error) { handleError(res, error); }
  });
}
function handleError(res: import("express").Response, error: unknown): void { const status = error instanceof SupabaseRestError ? error.status : 502; res.status(status).json(fail(status === 409 ? "VALIDATION_ERROR" : "ERPNEXT_UNAVAILABLE", error instanceof Error ? error.message : "Supabase request failed")); }
