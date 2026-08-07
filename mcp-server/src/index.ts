import { config as loadEnvironment } from "dotenv";
import express from "express";

import {
  createAppConfigFromEnv,
  registerRoutes,
} from "./app.js";

loadEnvironment();
loadEnvironment({ path: ".env.supabase", override: false });

async function main(): Promise<void> {
  const config = createAppConfigFromEnv();

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

  registerRoutes(app, config);

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
