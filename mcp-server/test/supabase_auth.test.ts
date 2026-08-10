import { describe, expect, it, vi } from "vitest";

import { SupabaseAuthClient } from "../src/lib/supabase_auth_client.js";

describe("SupabaseAuthClient", () => {
  it("validates a bearer token through Supabase Auth", async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ id: "user-1", email: "staff@example.com" }), {
        status: 200,
      }),
    );
    const client = new SupabaseAuthClient({
      url: "https://project.supabase.co",
      publishableKey: "publishable-key",
      fetchImpl,
    });

    await expect(client.getUser("access-token")).resolves.toEqual({
      id: "user-1",
      email: "staff@example.com",
    });
    expect(fetchImpl).toHaveBeenCalledWith(
      "https://project.supabase.co/auth/v1/user",
      expect.objectContaining({
        headers: expect.objectContaining({
          apikey: "publishable-key",
          Authorization: "Bearer access-token",
        }),
      }),
    );
  });

  it("shares concurrent and short-lived repeated token validation", async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ id: "user-1", email: "staff@example.com" }), {
        status: 200,
      }),
    );
    const client = new SupabaseAuthClient({
      url: "https://project.supabase.co",
      publishableKey: "publishable-key",
      fetchImpl,
    });

    await expect(Promise.all([
      client.getUser("access-token"),
      client.getUser("access-token"),
    ])).resolves.toEqual([
      { id: "user-1", email: "staff@example.com" },
      { id: "user-1", email: "staff@example.com" },
    ]);
    await client.getUser("access-token");

    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });
});
