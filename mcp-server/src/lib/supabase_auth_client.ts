interface SupabaseAuthClientOptions {
  url: string;
  publishableKey: string;
  fetchImpl?: typeof fetch;
}

export interface SupabaseUser {
  id: string;
  email: string | null;
}

export class SupabaseAuthClient {
  constructor({ url, publishableKey, fetchImpl = fetch }: SupabaseAuthClientOptions) {
    this.baseUrl = url.replace(/\/$/, "");
    this.publishableKey = publishableKey;
    this.fetchImpl = fetchImpl;
  }

  private readonly baseUrl: string;
  private readonly publishableKey: string;
  private readonly fetchImpl: typeof fetch;

  async getUser(accessToken: string): Promise<SupabaseUser | null> {
    const response = await this.fetchImpl(`${this.baseUrl}/auth/v1/user`, {
      headers: {
        Accept: "application/json",
        apikey: this.publishableKey,
        Authorization: `Bearer ${accessToken}`,
      },
    });
    if (response.status === 401) return null;
    if (!response.ok) {
      const text = await response.text().catch(() => "");
      throw new Error(`Supabase Auth failed: ${response.status} ${text}`);
    }

    const body = await response.json() as { id?: unknown; email?: unknown };
    if (typeof body.id !== "string") return null;
    return { id: body.id, email: typeof body.email === "string" ? body.email : null };
  }
}
