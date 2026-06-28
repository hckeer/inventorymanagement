/**
 * U3 integration gate — requires live ERPNext + MCP.
 * Run: RUN_INTEGRATION=1 npm test -- test/rentals.integration.test.ts
 */
import { describe, expect, it } from "vitest";

const runIntegration = process.env.RUN_INTEGRATION === "1";
const baseUrl = process.env.MCP_BASE_URL ?? "http://localhost:3001";
const username = process.env.MCP_TEST_USER ?? "Administrator";
const password = process.env.MCP_TEST_PASSWORD ?? "admin";

async function login(): Promise<string> {
  const response = await fetch(`${baseUrl}/api/v1/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username, password }),
  });
  const payload = await response.json();
  if (!payload.ok) {
    throw new Error(`Login failed: ${JSON.stringify(payload)}`);
  }
  return payload.data.access_token as string;
}

async function api(
  token: string,
  method: string,
  path: string,
  body?: unknown,
): Promise<{ status: number; json: Record<string, unknown> }> {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = (await response.json()) as Record<string, unknown>;
  return { status: response.status, json };
}

describe.runIf(runIntegration)("rentals integration (U3 gate)", () => {
  it("create → submit → return flow", async () => {
    const token = await login();

    const serialsResp = await api(
      token,
      "GET",
      "/api/v1/items/ARRI-LAMP-HEAD/serials",
    );
    expect(serialsResp.json.ok).toBe(true);
    const serials = (serialsResp.json.data as { serials: Array<{ name: string }> })
      .serials;
    expect(serials.length).toBeGreaterThan(0);
    const serial = serials[0].name;

    const createResp = await api(token, "POST", "/api/v1/rentals", {
      customer: "RENTAL-GATE-TEST",
      start_date: "2026-07-01",
      end_date: "2026-07-03",
      items: [
        {
          line_type: "serialized",
          item_code: "ARRI-LAMP-HEAD",
          serial_no: serial,
          qty: 1,
        },
      ],
    });
    expect(createResp.json.ok).toBe(true);
    const rentalName = (
      (createResp.json.data as { rental: { name: string } }).rental
    ).name;

    const submitResp = await api(
      token,
      "POST",
      `/api/v1/rentals/${encodeURIComponent(rentalName)}/submit`,
    );
    expect(submitResp.json.ok).toBe(true);
    expect(
      ((submitResp.json.data as { rental: { status: string } }).rental).status,
    ).toBe("Active");

    const doubleBook = await api(token, "POST", "/api/v1/rentals", {
      customer: "RENTAL-GATE-TEST",
      start_date: "2026-07-01",
      end_date: "2026-07-03",
      items: [
        {
          line_type: "serialized",
          item_code: "ARRI-LAMP-HEAD",
          serial_no: serial,
          qty: 1,
        },
      ],
    });
    const draftName = (
      (doubleBook.json.data as { rental: { name: string } }).rental
    ).name;
    const conflict = await api(
      token,
      "POST",
      `/api/v1/rentals/${encodeURIComponent(draftName)}/submit`,
    );
    expect(conflict.json.ok).toBe(false);
    expect((conflict.json.error as { code: string }).code).toBe(
      "SERIAL_ALREADY_RENTED",
    );

    const returnResp = await api(
      token,
      "POST",
      `/api/v1/rentals/${encodeURIComponent(rentalName)}/return`,
    );
    expect(returnResp.json.ok).toBe(true);
    expect(
      ((returnResp.json.data as { rental: { status: string } }).rental).status,
    ).toBe("Returned");
  }, 120_000);
});
