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

  private static constCacheTtlMs = 30_000;
  private readonly baseUrl: string;
  private readonly publishableKey: string;
  private readonly fetchImpl: typeof fetch;
  private readonly userCache = new Map<string, { user: SupabaseUser; expiresAt: number }>();
  private readonly pendingLookups = new Map<string, Promise<SupabaseUser | null>>();

  async getUser(accessToken: string): Promise<SupabaseUser | null> {
    const cached = this.userCache.get(accessToken);
    if (cached && cached.expiresAt > Date.now()) return cached.user;

    const pending = this.pendingLookups.get(accessToken);
    if (pending) return pending;

    const lookup = this.fetchUser(accessToken);
    this.pendingLookups.set(accessToken, lookup);
    try {
      return await lookup;
    } finally {
      this.pendingLookups.delete(accessToken);
    }
  }

  private async fetchUser(accessToken: string): Promise<SupabaseUser | null> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10_000);
    try {
      const response = await this.fetchImpl(`${this.baseUrl}/auth/v1/user`, {
        headers: {
          Accept: "application/json",
          apikey: this.publishableKey,
          Authorization: `Bearer ${accessToken}`,
        },
        signal: controller.signal,
      });
      // If token is invalid/expired (401) or signature is bad (403), treat as no session.
      if (response.status === 401 || response.status === 403) return null;
      const text = await response.text();
      if (!response.ok) {
        throw new Error(`Supabase Auth failed: ${response.status} ${text}`);
      }

      const body = JSON.parse(text) as { id?: unknown; email?: unknown };
      if (typeof body.id !== "string") return null;
      const user = { id: body.id, email: typeof body.email === "string" ? body.email : null };
      this.userCache.set(accessToken, {
        user,
        expiresAt: Date.now() + SupabaseAuthClient.constCacheTtlMs,
      });
      return user;
    } finally {
      clearTimeout(timeoutId);
    }
  }
}
