import { describe, expect, it } from "vitest";

import { mapErpnextError } from "../src/lib/api/codes.js";
import { buildRentalItemRows } from "../src/routes/v1_rentals.js";

describe("mapErpnextError rentals", () => {
  it("maps serial overlap to SERIAL_ALREADY_RENTED", () => {
    const code = mapErpnextError(
      417,
      "ValidationError",
      {
        message: "Serial LB-LAMP-0001 is on active rental RENT-2026-00001 for overlapping dates.",
        _server_messages: "[\"Serial Already Rented\"]",
      },
    );
    expect(code).toBe("SERIAL_ALREADY_RENTED");
  });

  it("maps insufficient stock to INSUFFICIENT_QTY", () => {
    const code = mapErpnextError(
      417,
      "ValidationError",
      {
        message: "Insufficient stock for SANDBAG-25LB: requested 100, available 8 in Main Store Floor - I.",
      },
    );
    expect(code).toBe("INSUFFICIENT_QTY");
  });
});

describe("buildRentalItemRows", () => {
  it("normalizes serialized and qty lines", () => {
    const rows = buildRentalItemRows([
      {
        line_type: "serialized",
        item_code: "ARRI-LAMP-HEAD",
        serial_no: "LB-LAMP-0001",
        qty: 2,
      },
      {
        line_type: "qty",
        item_code: "SANDBAG-25LB",
        qty: 4,
      },
    ]);

    expect(rows[0]).toMatchObject({
      line_type: "serialized",
      serial_no: "LB-LAMP-0001",
      qty: 1,
    });
    expect(rows[1]).toMatchObject({
      line_type: "qty",
      qty: 4,
    });
  });
});
