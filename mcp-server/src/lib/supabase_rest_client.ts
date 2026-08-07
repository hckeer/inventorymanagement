export class SupabaseRestError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

interface SupabaseRestClientOptions {
  url: string;
  serviceRoleKey: string;
  fetchImpl?: typeof fetch;
}

export class SupabaseRestClient {
  constructor({ url, serviceRoleKey, fetchImpl = fetch }: SupabaseRestClientOptions) {
    this.baseUrl = url.replace(/\/$/, "");
    this.serviceRoleKey = serviceRoleKey;
    this.fetchImpl = fetchImpl;
  }

  private readonly baseUrl: string;
  private readonly serviceRoleKey: string;
  private readonly fetchImpl: typeof fetch;

  async rpc<T>(name: string, input: Record<string, unknown>): Promise<T> {
    const response = await this.fetchImpl(`${this.baseUrl}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        apikey: this.serviceRoleKey,
        Authorization: `Bearer ${this.serviceRoleKey}`,
      },
      body: JSON.stringify(input),
    });

    const text = await response.text();
    const body = text ? safeJson(text) : null;
    if (!response.ok) {
      throw new SupabaseRestError(errorMessage(body, response.statusText), response.status);
    }
    return body as T;
  }

  async get<T>(path: string): Promise<T> {
    const response = await this.fetchImpl(`${this.baseUrl}/rest/v1/${path}`, { headers: { Accept: "application/json", apikey: this.serviceRoleKey, Authorization: `Bearer ${this.serviceRoleKey}` } });
    const text = await response.text(); const body = text ? safeJson(text) : null;
    if (!response.ok) throw new SupabaseRestError(errorMessage(body, response.statusText), response.status);
    return body as T;
  }
  async post<T>(table: string, body: Record<string, unknown>): Promise<T> { return this.request<T>(`${table}`, "POST", body); }
  async patch<T>(path: string, body: Record<string, unknown>): Promise<T> { return this.request<T>(path, "PATCH", body); }
  private async request<T>(path: string, method: string, body: Record<string, unknown>): Promise<T> { const response=await this.fetchImpl(`${this.baseUrl}/rest/v1/${path}`,{method,headers:{Accept:"application/json","Content-Type":"application/json",Prefer:"return=representation",apikey:this.serviceRoleKey,Authorization:`Bearer ${this.serviceRoleKey}`},body:JSON.stringify(body)}); const text=await response.text();const parsed=text?safeJson(text):null;if(!response.ok)throw new SupabaseRestError(errorMessage(parsed,response.statusText),response.status);return parsed as T; }
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return text;
  }
}

function errorMessage(body: unknown, fallback: string): string {
  if (typeof body === "object" && body !== null && "message" in body) {
    const message = (body as { message?: unknown }).message;
    if (typeof message === "string") return message;
  }
  return fallback || "Supabase request failed";
}
