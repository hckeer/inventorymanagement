export interface AppConfig {
  supabaseUrl: string;
  supabasePublishableKey: string;
  supabaseSecretKey: string;
  erpnextUrl: string;
  erpnextApiKey: string;
  erpnextApiSecret: string;
  company: string | null;
  port: number;
  apiKey: string | null;
  jwtSecret: string;
  sessionTtlSeconds: number;
}

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function loadConfig(): AppConfig {
  return {
    supabaseUrl: required("SUPABASE_URL").replace(/\/$/, ""),
    supabasePublishableKey: required("SUPABASE_PUBLISHABLE_KEY"),
    supabaseSecretKey: required("SUPABASE_SECRET_KEY"),
    erpnextUrl: process.env.ERPNEXT_URL?.replace(/\/$/, "") ?? "",
    erpnextApiKey: process.env.ERPNEXT_API_KEY ?? "",
    erpnextApiSecret: process.env.ERPNEXT_API_SECRET ?? "",
    company: process.env.ERPNEXT_COMPANY?.trim() || null,
    port: Number(process.env.PORT ?? "3001"),
    apiKey: process.env.MCP_API_KEY?.trim() || null,
    jwtSecret: process.env.MCP_JWT_SECRET ?? "",
    sessionTtlSeconds: Number(process.env.MCP_SESSION_TTL_SECONDS ?? "28800"),
  };
}

export function loadConfigOrNull(): AppConfig | null {
  try {
    return loadConfig();
  } catch {
    return null;
  }
}
