import type { Express } from "express";
import { z } from "zod";
import { fail, ok } from "../lib/api/envelope.js";
import { SupabaseRestError, SupabaseRestClient } from "../lib/supabase_rest_client.js";
import type { SupabaseAuthenticatedRequest } from "../middleware/supabase_auth.js";

const productSchema = z.object({ name: z.string().min(1), sku: z.string().optional(), category_id: z.string().uuid().nullable().optional(), manufacturer_id: z.string().uuid().nullable().optional(), tracking_mode: z.enum(["serialized", "quantity"]), daily_rate: z.number().nonnegative().default(0), notes: z.string().optional(), identifiers: z.array(z.object({ identifier: z.string().min(1), identifier_type: z.enum(["ean_13", "upc_a", "internal"]) })).default([]), initial_quantity: z.number().int().nonnegative().default(0) });
const rentalSchema = z.object({ client_id: z.string().uuid(), start_date: z.string().date(), end_date: z.string().date(), deposit_amount: z.number().nonnegative().default(0), deposit_paid: z.boolean().default(false), notes: z.string().optional(), items: z.array(z.object({ product_id: z.string().uuid(), asset_id: z.string().uuid().optional(), quantity: z.number().int().positive().optional() })).min(1) });

export function registerInventoryV1Routes(app: Express, auth: ReturnType<typeof import("../middleware/supabase_auth.js").createSupabaseAuthMiddleware>, database: SupabaseRestClient): void {
  app.get("/api/v1/auth/me", auth, (req: SupabaseAuthenticatedRequest, res) => res.json(ok({ id: req.user?.id, email: req.user?.email })));
  app.get("/api/v1/dashboard/stats", auth, async (_req,res)=>{try{const [active,assets]=await Promise.all([database.get<Array<unknown>>("rentals?status=eq.active&select=id"),database.get<Array<unknown>>("assets?status=eq.available&select=id")]);res.json(ok({active_rentals:active.length,overdue_rentals:0,available_serialized:assets.length}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/products", auth, async (_req,res)=>{try{res.json(ok({products:await database.get("products?select=*,stock_balances(*)&order=name.asc")}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/products/:id/assets", auth, async (req,res)=>{try{res.json(ok({assets:await database.get(`assets?product_id=eq.${encodeURIComponent(String(req.params.id))}&select=*&order=asset_id.asc`)}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/categories", auth, async (_req,res)=>{try{res.json(ok({categories:await database.get("categories?select=*&order=name.asc")}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/clients", auth, async (_req,res)=>{try{res.json(ok({clients:await database.get("clients?select=*&order=full_name.asc")}));}catch(error){handleError(res,error);}});
  app.post("/api/v1/clients",auth,async(req,res)=>{try{const rows=await database.post<Array<unknown>>("clients",req.body as Record<string,unknown>);res.status(201).json(ok({client:rows[0]}));}catch(error){handleError(res,error);}});
  app.patch("/api/v1/clients/:id",auth,async(req,res)=>{try{const rows=await database.patch<Array<unknown>>(`clients?id=eq.${encodeURIComponent(String(req.params.id))}`,req.body as Record<string,unknown>);res.json(ok({client:rows[0]}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/rentals",auth,async(_req,res)=>{try{res.json(ok({rentals:await database.get("rentals?select=*,clients(full_name)&order=created_at.desc")}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/rentals/:id",auth,async(req,res)=>{try{const rows=await database.get<Array<unknown>>(`rentals?id=eq.${encodeURIComponent(String(req.params.id))}&select=*,clients(full_name)`);res.json(ok({rental:rows[0]}));}catch(error){handleError(res,error);}});
  app.get("/api/v1/rentals/:id/items",auth,async(req,res)=>{try{res.json(ok({items:await database.get(`rental_items?rental_id=eq.${encodeURIComponent(String(req.params.id))}&select=*`)}));}catch(error){handleError(res,error);}});
  app.patch("/api/v1/rental-items/:id/damage",auth,async(req,res)=>{try{const rows=await database.patch<Array<unknown>>(`rental_items?id=eq.${encodeURIComponent(String(req.params.id))}`,{damage_notes:String(req.body?.damage_notes??"")});res.json(ok({item:rows[0]}));}catch(error){handleError(res,error);}});
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
  app.post("/api/v1/assets/link", auth, async (req, res) => {
    try {
      const parent = req.body?.parent;
      const children = Array.isArray(req.body?.children) ? req.body.children : [];
      if (!parent || !parent.barcode || children.length === 0) {
        res.status(422).json(fail("VALIDATION_ERROR", "Missing parent.barcode or children array"));
        return;
      }
      await database.rpc("link_assets_to_parent", { p_parent: parent, p_children: children });
      res.json(ok({ success: true }));
    } catch (error) {
      handleError(res, error);
    }
  });
  app.post("/api/v1/rentals", auth, async (req: SupabaseAuthenticatedRequest, res) => { const parsed=rentalSchema.safeParse(req.body); if(!parsed.success || !req.user){res.status(422).json(fail("VALIDATION_ERROR","Invalid rental payload"));return;} try {res.status(201).json(ok({rental:await database.rpc("create_rental",{p_client_id:parsed.data.client_id,p_created_by:req.user.id,p_start_date:parsed.data.start_date,p_end_date:parsed.data.end_date,p_deposit_amount:parsed.data.deposit_amount,p_deposit_paid:parsed.data.deposit_paid,p_notes:parsed.data.notes??"",p_items:parsed.data.items})}));}catch(error){handleError(res,error);} });
  
  app.patch("/api/v1/products/:id", auth, async (req, res) => {
    try {
      const rows = await database.patch<Array<unknown>>(
        `products?id=eq.${encodeURIComponent(String(req.params.id))}`,
        req.body as Record<string, unknown>
      );
      res.json(ok({ product: rows[0] }));
    } catch (error) {
      handleError(res, error);
    }
  });
  app.post("/api/v1/rentals/:id/checkout", auth, async (req: SupabaseAuthenticatedRequest,res)=>{try{res.json(ok({rental:await database.rpc("checkout_rental",{p_rental_id:req.params.id,p_created_by:req.user?.id})}));}catch(error){handleError(res,error);}});
  app.post("/api/v1/rentals/:id/return", auth, async (req: SupabaseAuthenticatedRequest,res)=>{try{res.json(ok({rental:await database.rpc("return_rental",{p_rental_id:req.params.id,p_created_by:req.user?.id})}));}catch(error){handleError(res,error);}});
}
function handleError(res: import("express").Response, error: unknown): void { const status = error instanceof SupabaseRestError ? error.status : 502; res.status(status).json(fail(status === 409 ? "VALIDATION_ERROR" : "ERPNEXT_UNAVAILABLE", error instanceof Error ? error.message : "Supabase request failed")); }
