import { describe, expect, it } from "vitest";

import { expandAssembly } from "../src/lib/expand_assembly.js";
import { diffExpectedVsActual, reconcileScannedVsExpected } from "../src/lib/diff.js";
import type { ExpectedContentRow } from "../src/lib/types.js";

const assemblies: Record<string, Array<{ item_code: string; qty: number }>> = {
  "ARRI-LIGHT-SET": [
    { item_code: "ARRI-LAMP-HEAD", qty: 1 },
    { item_code: "ARRI-LENS", qty: 1 },
    { item_code: "ARRI-DIFFUSER", qty: 1 },
  ],
};

describe("expandAssembly", () => {
  it("expands direct serialized lines", () => {
    const rows: ExpectedContentRow[] = [
      { item_code: "ARRI-LAMP-HEAD", qty: 4, tracking: "serialized" },
      { item_code: "ARRI-LENS", qty: 4, tracking: "serialized" },
    ];

    const result = expandAssembly(rows, (name) => assemblies[name] ?? []);

    expect(result.audited).toEqual([
      { item_code: "ARRI-LAMP-HEAD", qty: 4 },
      { item_code: "ARRI-LENS", qty: 4 },
    ]);
    expect(result.informational).toEqual([]);
  });

  it("expands assembly rows and keeps qty_only informational", () => {
    const rows: ExpectedContentRow[] = [
      { item_code: "C-STAND-ARM", qty: 4, tracking: "serialized" },
      { equipment_assembly: "ARRI-LIGHT-SET", qty: 2, tracking: "serialized" },
      { item_code: "SANDBAG-25LB", qty: 8, tracking: "qty_only" },
    ];

    const result = expandAssembly(rows, (name) => assemblies[name] ?? []);

    expect(result.audited).toEqual([
      { item_code: "ARRI-DIFFUSER", qty: 2 },
      { item_code: "ARRI-LAMP-HEAD", qty: 2 },
      { item_code: "ARRI-LENS", qty: 2 },
      { item_code: "C-STAND-ARM", qty: 4 },
    ]);
    expect(result.informational).toEqual([
      { item_code: "SANDBAG-25LB", qty: 8, tracking: "qty_only" },
    ]);
  });
});

describe("diffExpectedVsActual", () => {
  it("finds missing and surplus items", () => {
    const { missing, surplus } = diffExpectedVsActual(
      [
        { item_code: "ARRI-DIFFUSER", qty: 4 },
        { item_code: "ARRI-LENS", qty: 4 },
      ],
      {
        "ARRI-DIFFUSER": 3,
        "ARRI-LENS": 4,
        "C-STAND-ARM": 1,
      },
    );

    expect(missing).toEqual([
      {
        item_code: "ARRI-DIFFUSER",
        expected: 4,
        actual: 3,
        delta: 1,
      },
    ]);
    expect(surplus).toEqual([
      {
        item_code: "C-STAND-ARM",
        expected: 0,
        actual: 1,
        delta: 1,
      },
    ]);
  });
});

describe("reconcileScannedVsExpected", () => {
  it("flags under-packed and unexpected serials", () => {
    const result = reconcileScannedVsExpected(
      [{ item_code: "C-STAND-ARM", qty: 4 }],
      [
        { serial: "LB-CS-ARM-001", item_code: "C-STAND-ARM" },
        { serial: "LB-CS-ARM-002", item_code: "C-STAND-ARM" },
        { serial: "LB-CS-ARM-003", item_code: "C-STAND-ARM" },
        { serial: "LB-LAMP-0001", item_code: "ARRI-LAMP-HEAD" },
      ],
    );

    expect(result.complete).toBe(false);
    expect(result.missing).toEqual([
      {
        item_code: "C-STAND-ARM",
        expected: 4,
        actual: 3,
        delta: 1,
      },
    ]);
    expect(result.unexpected).toEqual([
      { serial: "LB-LAMP-0001", item_code: "ARRI-LAMP-HEAD" },
    ]);
  });
});
