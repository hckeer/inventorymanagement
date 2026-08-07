import { describe, expect, it, vi } from "vitest";

import { SupabaseRestClient } from "../src/lib/supabase_rest_client.js";

describe("SupabaseRestClient", () => {
  it("uses the service-role key only for an RPC call", async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ result_type: "unknown" }), { status: 200 }),
    );
    const client = new SupabaseRestClient({
      url: "https://project.supabase.co",
      serviceRoleKey: "service-role-key",
      fetchImpl,
    });

    await expect(client.rpc("lookup_barcode", { p_identifier: "123" })).resolves.toEqual({
      result_type: "unknown",
    });

    expect(fetchImpl).toHaveBeenCalledWith(
      "https://project.supabase.co/rest/v1/rpc/lookup_barcode",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          apikey: "service-role-key",
          Authorization: "Bearer service-role-key",
        }),
      }),
    );
  });

  it("throws a typed error when Supabase rejects a request", async () => {
    const client = new SupabaseRestClient({
      url: "https://project.supabase.co",
      serviceRoleKey: "service-role-key",
      fetchImpl: vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ message: "duplicate" }), { status: 409 }),
      ),
    });

    await expect(client.rpc("create_product", {})).rejects.toMatchObject({
      status: 409,
      message: "duplicate",
    });
  });
});
