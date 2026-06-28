/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_MCP_URL: string;
  readonly VITE_MCP_API_KEY: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
