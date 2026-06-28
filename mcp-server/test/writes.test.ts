import { describe, expect, it } from "vitest";

import { slugItemCode } from "../src/routes/v1_writes.js";

describe("slugItemCode", () => {
  it("uppercases and hyphenates item names", () => {
    expect(slugItemCode("Arri Lamp Head")).toBe("ARRI-LAMP-HEAD");
  });

  it("strips leading and trailing separators", () => {
    expect(slugItemCode("  --Sand Bag--  ")).toBe("SAND-BAG");
  });

  it("falls back when name has no alphanumerics", () => {
    expect(slugItemCode("---")).toBe("ITEM");
  });
});
