import { existsSync, readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const migrationsDirectory = resolve(import.meta.dirname, "../../supabase/migrations");

function schemaSql(): string {
  const migration = resolve(migrationsDirectory, migrationFileName());
  return readFileSync(migration, "utf8");
}

function migrationFileName(): string {
  return readdirSync(migrationsDirectory).find((name) =>
    /_initial_inventory_v1\.sql$/.test(name),
  ) ?? "";
}

describe("initial inventory schema", () => {
  it("is supplied as a versioned migration", () => {
    expect(
      existsSync(resolve(migrationsDirectory, migrationFileName())),
    ).toBe(true);
  });

  it("defines the normalized V1 tables without legacy equipment", () => {
    const sql = schemaSql();

    for (const table of [
      "categories",
      "manufacturers",
      "products",
      "product_identifiers",
      "assets",
      "stock_balances",
      "clients",
      "rentals",
      "rental_items",
      "inventory_events",
      "kits",
      "kit_components",
    ]) {
      expect(sql).toMatch(new RegExp(`create table public\\.${table}\\b`, "i"));
    }

    expect(sql).not.toMatch(/create table public\.equipment\b/i);
    expect(sql).not.toMatch(/insert into public\.(categories|products|assets)/i);
  });

  it("enforces product and asset identifier uniqueness", () => {
    const sql = schemaSql();

    expect(sql).toMatch(/identifier text not null unique/i);
    expect(sql).toMatch(/manufacturer_serial text unique/i);
    expect(sql).toMatch(/internal_qr text unique/i);
  });
});
