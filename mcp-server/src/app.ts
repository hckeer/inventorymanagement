import type { Express } from "express";
import { loadConfig, type AppConfig } from "./lib/config.js";
import { SupabaseAuthClient } from "./lib/supabase_auth_client.js";
import { SupabaseRestClient } from "./lib/supabase_rest_client.js";
import { createSupabaseAuthMiddleware } from "./middleware/supabase_auth.js";
import { registerInventoryV1Routes } from "./routes/inventory_v1.js";

/** @deprecated ERPNext warehouse service is disabled in the V1 runtime. */
export type WarehouseService = any;

export function registerRoutes(app: Express, config: AppConfig): void {
  app.get("/health", (_req, res) => res.json({ status: "ok", service: "inventory-mcp" }));
  const auth = createSupabaseAuthMiddleware(new SupabaseAuthClient({ url: config.supabaseUrl, publishableKey: config.supabasePublishableKey }));
  const database = new SupabaseRestClient({ url: config.supabaseUrl, serviceRoleKey: config.supabaseSecretKey });
  registerInventoryV1Routes(app, auth, database);
}
export function createAppConfigFromEnv(): AppConfig { return loadConfig(); }
