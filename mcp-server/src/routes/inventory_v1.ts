import type { Express } from "express";
import { z } from "zod";
import { fail, ok } from "../lib/api/envelope.js";
import { SupabaseRestError, SupabaseRestClient } from "../lib/supabase_rest_client.js";
import type { SupabaseAuthenticatedRequest } from "../middleware/supabase_auth.js";

const productSchema = z.object({ name: z.string().min(1), sku: z.string().optional(), category_id: z.string().uuid().nullable().optional(), manufacturer_id: z.string().uuid().nullable().optional(), tracking_mode: z.enum(["serialized", "quantity"]), daily_rate: z.number().nonnegative().default(0), notes: z.string().optional(), initial_quantity: z.number().int().nonnegative().default(0), asset_barcode: z.string().trim().min(1).max(200).optional() }).strict();
const productPatchSchema = z.object({ name: z.string().min(1), sku: z.string().nullable(), category_id: z.string().uuid().nullable(), manufacturer_id: z.string().uuid().nullable(), daily_rate: z.number().nonnegative(), notes: z.string().nullable(), is_active: z.boolean() }).partial().strict();
const clientSchema = z.object({ full_name: z.string().min(1), phone: z.string().optional(), email: z.string().email().optional().or(z.literal("")), id_document: z.string().optional(), notes: z.string().optional() }).strict();
const clientPatchSchema = clientSchema.partial().strict();
const assetLinkEntrySchema = z.object({ barcode: z.string().trim().min(1), name: z.string().trim().min(1).max(200).optional() }).strict();
const assetLinkSchema = z.object({ parent: assetLinkEntrySchema, children: z.array(assetLinkEntrySchema).min(1).max(200) }).strict();
const rentalSchema = z.object({ client_id: z.string().uuid(), start_date: z.string().date(), end_date: z.string().date(), deposit_amount: z.number().nonnegative().default(0), deposit_paid: z.boolean().default(false), notes: z.string().optional(), items: z.array(z.object({ product_id: z.string().uuid(), asset_id: z.string().uuid().optional(), quantity: z.number().int().positive().optional() })).min(1), override_asset_ids: z.array(z.string().uuid()).default([]), override_reason: z.string().trim().min(1).max(500).optional() });
const quantityAdjustmentSchema = z.object({ product_id: z.string().uuid(), expected_on_hand_quantity: z.number().int().nonnegative(), notes: z.string().trim().max(500).optional() }).strict();
const serializedDispositionSchema = z.object({ rental_item_id: z.string().uuid(), disposition: z.enum(["returned", "damaged", "lost"]) }).strict();

export function registerInventoryV1Routes(app: Express, auth: ReturnType<typeof import("../middleware/supabase_auth.js").createSupabaseAuthMiddleware>, database: SupabaseRestClient): void {
  app.get("/api/v1/auth/me", auth, (req: SupabaseAuthenticatedRequest, res) => res.json(ok({ id: req.user?.id, email: req.user?.email })));
  app.get("/api/v1/dashboard/stats", auth, async (_req,res)=>{try{const [active,assets]=await Promise.all([database.count("rentals?status=eq.active"),database.count("assets?status=eq.available")]);res.json(ok({active_rentals:active,overdue_rentals:0,available_serialized:assets}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/products", auth, async (_req,res)=>{try{res.json(ok({products:await database.get("products?select=*,stock_balances(*),assets(status)&order=name.asc")}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/products/:id", auth, async (req,res)=>{try{const rows=await database.get<Array<unknown>>(`products?id=eq.${encodeURIComponent(String(req.params.id))}&select=*,stock_balances(*)`);if(!rows || rows.length===0){res.status(404).json(fail("NOT_FOUND","Product not found"));return;}res.json(ok({product:rows[0]}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/products/:id/assets", auth, async (req,res)=>{try{res.json(ok({assets:await database.get(`assets?product_id=eq.${encodeURIComponent(String(req.params.id))}&select=*&order=asset_id.asc`)}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/categories", auth, async (_req,res)=>{try{res.json(ok({categories:await database.get("categories?select=*&order=name.asc")}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/clients", auth, async (_req,res)=>{try{res.json(ok({clients:await database.get("clients?select=*&order=full_name.asc")}));}catch(error){handleError(res,error);}});
  app.post("/api/v1/clients",auth,async(req,res)=>{try{const parsed=clientSchema.safeParse(req.body);if(!parsed.success){res.status(422).json(fail("VALIDATION_ERROR","Invalid client payload"));return;}const rows=await database.post<Array<unknown>>("clients",parsed.data);res.status(201).json(ok({client:rows[0]}));}catch(error){handleError(res,error);}});
  app.patch("/api/v1/clients/:id",auth,async(req,res)=>{try{const parsed=clientPatchSchema.safeParse(req.body);if(!parsed.success){res.status(422).json(fail("VALIDATION_ERROR","Invalid client payload"));return;}const rows=await database.patch<Array<unknown>>(`clients?id=eq.${encodeURIComponent(String(req.params.id))}`,parsed.data);if(!rows || rows.length===0){res.status(404).json(fail("NOT_FOUND","Client not found"));return;}res.json(ok({client:rows[0]}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/rentals",auth,async(_req,res)=>{try{res.json(ok({rentals:await database.get("rentals?select=*,clients(full_name)&order=created_at.desc")}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/rentals/:id",auth,async(req,res)=>{try{const rows=await database.get<Array<unknown>>(`rentals?id=eq.${encodeURIComponent(String(req.params.id))}&select=*,clients(full_name)`);if(!rows || rows.length===0){res.status(404).json(fail("NOT_FOUND","Rental not found"));return;}res.json(ok({rental:rows[0]}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/rentals/:id/items",auth,async(req,res)=>{try{res.json(ok({items:await database.get(`rental_items?rental_id=eq.${encodeURIComponent(String(req.params.id))}&select=*`)}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/rentals/:id/parent-snapshots/:parentId",auth,async(req,res)=>{try{res.json(ok({snapshots:await database.get(`rental_parent_snapshots?rental_id=eq.${encodeURIComponent(String(req.params.id))}&parent_asset_id=eq.${encodeURIComponent(String(req.params.parentId))}&select=child_asset_id`)}));}catch(error){handleError(res,error);}});
  app.patch("/api/v1/rental-items/:id/damage",auth,async(req,res)=>{try{const rows=await database.patch<Array<unknown>>(`rental_items?id=eq.${encodeURIComponent(String(req.params.id))}`,{damage_notes:String(req.body?.damage_notes??"")});if(!rows || rows.length===0){res.status(404).json(fail("NOT_FOUND","Rental item not found"));return;}res.json(ok({item:rows[0]}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/barcodes/:identifier", auth, async (req, res) => {
    try { res.json(ok({ lookup: await database.rpc("lookup_barcode", { p_identifier: String(req.params.identifier).trim() }) })); }
    catch (error) { handleError(res, error); }
  });
  app.post("/api/v1/products", auth, async (req, res) => {
    const parsed = productSchema.safeParse(req.body);
    if (!parsed.success) { res.status(422).json(fail("VALIDATION_ERROR", "Invalid product payload")); return; }
    if (parsed.data.asset_barcode != null && parsed.data.tracking_mode !== "serialized") { res.status(422).json(fail("VALIDATION_ERROR", "A physical asset barcode requires serialized tracking")); return; }
    try { res.status(201).json(ok({ product: await database.rpc("create_product_with_asset", { p_name: parsed.data.name, p_sku: parsed.data.sku ?? "", p_category_id: parsed.data.category_id ?? null, p_manufacturer_id: parsed.data.manufacturer_id ?? null, p_tracking_mode: parsed.data.tracking_mode, p_daily_rate: parsed.data.daily_rate, p_notes: parsed.data.notes ?? "", p_identifiers: [], p_initial_quantity: parsed.data.initial_quantity, p_asset_barcode: parsed.data.asset_barcode ?? null }) })); }
    catch (error) { handleError(res, error); }
  });
  app.post("/api/v1/assets/link", auth, async (req, res) => {
    try {
      const parsed = assetLinkSchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(422).json(fail("VALIDATION_ERROR", "Invalid asset link payload"));
        return;
      }
      await database.rpc("link_assets_to_parent", { p_parent: parsed.data.parent, p_children: parsed.data.children });
      res.json(ok({ success: true }));
    } catch (error) {
      handleError(res, error);
    }
  });
  app.post("/api/v1/rentals", auth, async (req: SupabaseAuthenticatedRequest, res) => { const parsed=rentalSchema.safeParse(req.body); if(!parsed.success || !req.user){res.status(422).json(fail("VALIDATION_ERROR","Invalid rental payload"));return;} try {res.status(201).json(ok({rental:await database.rpc("create_rental",{p_client_id:parsed.data.client_id,p_created_by:req.user.id,p_start_date:parsed.data.start_date,p_end_date:parsed.data.end_date,p_deposit_amount:parsed.data.deposit_amount,p_deposit_paid:parsed.data.deposit_paid,p_notes:parsed.data.notes??"",p_items:parsed.data.items,p_override_asset_ids:parsed.data.override_asset_ids,p_override_reason:null})}));}catch(error){handleError(res,error);} });
  app.post("/api/v1/rentals/quick-checkout", auth, async (req: SupabaseAuthenticatedRequest, res) => { const parsed=rentalSchema.safeParse(req.body); const requestId=String(req.header("idempotency-key")??""); const parentAssetIds=req.body?.parent_asset_ids??[]; if(!parsed.success || !req.user || !isUuid(requestId) || !isUuidArray(parentAssetIds) || (parsed.data.override_asset_ids.length > 0 && !parsed.data.override_reason)){res.status(422).json(fail("VALIDATION_ERROR","Invalid quick checkout payload"));return;} try {res.status(201).json(ok({rental:await database.rpc("create_and_checkout_rental",{p_client_id:parsed.data.client_id,p_created_by:req.user.id,p_start_date:parsed.data.start_date,p_end_date:parsed.data.end_date,p_deposit_amount:parsed.data.deposit_amount,p_deposit_paid:parsed.data.deposit_paid,p_notes:parsed.data.notes??"",p_items:parsed.data.items,p_parent_asset_ids:parentAssetIds,p_request_id:requestId,p_override_asset_ids:parsed.data.override_asset_ids,p_override_reason:parsed.data.override_reason??null})}));}catch(error){handleError(res,error);} });
  
  app.patch("/api/v1/products/:id", auth, async (req, res) => {
    try {
      const parsed = productPatchSchema.safeParse(req.body);
      if (!parsed.success) { res.status(422).json(fail("VALIDATION_ERROR", "Invalid product payload")); return; }
      const rows = await database.patch<Array<unknown>>(
        `products?id=eq.${encodeURIComponent(String(req.params.id))}`,
        parsed.data
      );
      if(!rows || rows.length===0){res.status(404).json(fail("NOT_FOUND","Product not found"));return;}
      res.json(ok({ product: rows[0] }));
    } catch (error) {
      handleError(res, error);
    }
  });
  app.post("/api/v1/rentals/:id/checkout", auth, async (req: SupabaseAuthenticatedRequest,res)=>{
    const requestId = String(req.header("idempotency-key") ?? "");
    const verifiedRentalItemIds = req.body?.verified_rental_item_ids;
    const parentAssetIds = req.body?.parent_asset_ids ?? [];
    if (!req.user || !isUuid(requestId) || !isUuidArray(verifiedRentalItemIds) || !isUuidArray(parentAssetIds)) {
      res.status(422).json(fail("VALIDATION_ERROR", "A request ID and scanned rental item IDs are required"));
      return;
    }
    try { res.json(ok({rental:await database.rpc("confirm_checkout",{p_rental_id:req.params.id,p_created_by:req.user.id,p_verified_rental_item_ids:verifiedRentalItemIds,p_parent_asset_ids:parentAssetIds,p_request_id:requestId})})); }
    catch(error){handleError(res,error);}
  });
  app.post("/api/v1/rentals/:id/return", auth, async (req: SupabaseAuthenticatedRequest,res)=>{
    const requestId = String(req.header("idempotency-key") ?? "");
    const verifiedRentalItemIds = req.body?.verified_rental_item_ids;
    const returnedQuantities = req.body?.returned_quantities;
    const serializedDispositions = serializedDispositionSchema.array().safeParse(req.body?.serialized_dispositions ?? []);
    if (!req.user || !isUuid(requestId) || !isUuidArray(verifiedRentalItemIds) || !Array.isArray(returnedQuantities) || !serializedDispositions.success) {
      res.status(422).json(fail("VALIDATION_ERROR", "A request ID, scanned rental item IDs, and return quantities are required"));
      return;
    }
    try { res.json(ok({rental:await database.rpc("confirm_return",{p_rental_id:req.params.id,p_created_by:req.user.id,p_verified_rental_item_ids:verifiedRentalItemIds,p_returned_quantities:returnedQuantities,p_request_id:requestId,p_serialized_dispositions:serializedDispositions.data})})); }
    catch(error){handleError(res,error);}
  });
  app.post("/api/v1/inventory/quantity-adjustments", auth, async (req: SupabaseAuthenticatedRequest, res) => {
    const parsed = quantityAdjustmentSchema.safeParse(req.body);
    if (!parsed.success || !req.user) { res.status(422).json(fail("VALIDATION_ERROR", "Invalid inventory adjustment")); return; }
    try { res.json(ok({ balance: await database.rpc("adjust_quantity_inventory", { p_product_id: parsed.data.product_id, p_expected_on_hand_quantity: parsed.data.expected_on_hand_quantity, p_created_by: req.user.id, p_notes: parsed.data.notes ?? null }) })); }
    catch (error) { handleError(res, error); }
  });
}
function handleError(res: import("express").Response, error: unknown): void { const status = error instanceof SupabaseRestError ? error.status : 502; res.status(status).json(fail(status === 409 ? "VALIDATION_ERROR" : "ERPNEXT_UNAVAILABLE", error instanceof Error ? error.message : "Supabase request failed")); }
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function isUuid(value: unknown): value is string { return typeof value === "string" && uuidPattern.test(value); }
function isUuidArray(value: unknown): value is string[] { return Array.isArray(value) && value.every(isUuid); }
