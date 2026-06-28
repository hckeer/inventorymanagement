import "dotenv/config";
import express from "express";

import {
  createAppConfigFromEnv,
  createWarehouseService,
  registerRoutes,
} from "./app.js";
import { SessionStore } from "./lib/auth/session_store.js";
import { registerMcpServer } from "./mcp.js";

async function main(): Promise<void> {
  const config = createAppConfigFromEnv();
  const service = createWarehouseService(config);
  const sessionStore = new SessionStore(config.sessionTtlSeconds * 1000);

  if (process.argv.includes("--stdio")) {
    await registerMcpServer(service);
    return;
  }

  const app = express();
  app.use(express.json());
  app.use((_req, res, next) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader(
      "Access-Control-Allow-Headers",
      "Content-Type, X-Api-Key, Authorization",
    );
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, PATCH, OPTIONS");
    next();
  });
  app.options(/.*/, (_req, res) => res.sendStatus(204));

  registerRoutes(app, service, config, sessionStore);

  app.listen(config.port, () => {
    console.log(
      `lightbenders-mcp-server listening on http://0.0.0.0:${config.port}`,
    );
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
