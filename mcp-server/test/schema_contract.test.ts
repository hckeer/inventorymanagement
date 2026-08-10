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

describe("product operations schema", () => {
  it("supplies an atomic product creation function", () => {
    const migration = resolve(migrationsDirectory, productOperationsMigration());
    const sql = readFileSync(migration, "utf8");

    expect(sql).toMatch(/create function public\.create_product\(/i);
    expect(sql).toMatch(/insert into public\.products/i);
    expect(sql).toMatch(/insert into public\.product_identifiers/i);
    expect(sql).toMatch(/insert into public\.stock_balances/i);
  });

  it("supplies a barcode resolver that prioritizes serialized assets", () => {
    const migration = resolve(migrationsDirectory, productOperationsMigration());
    const sql = readFileSync(migration, "utf8");

    expect(sql).toMatch(/create function public\.lookup_barcode\(/i);
    expect(sql).toMatch(/from public\.assets/i);
    expect(sql).toMatch(/from public\.product_identifiers/i);
  });
});

describe("legacy test-data cleanup schema", () => {
  it("explicitly removes orders that depend on the legacy products table", () => {
    const migration = resolve(migrationsDirectory, legacyCleanupMigration());
    const sql = readFileSync(migration, "utf8");

    expect(sql).toMatch(/drop table if exists public\.orders cascade/i);
  });
});

describe("rental lifecycle schema", () => {
  it("provides atomic reservation, checkout, and return functions", () => {
    const sql = readFileSync(resolve(migrationsDirectory, rentalLifecycleMigration()), "utf8");
    expect(sql).toMatch(/create function public\.create_rental\(/i);
    expect(sql).toMatch(/create function public\.checkout_rental\(/i);
    expect(sql).toMatch(/create function public\.return_rental\(/i);
    expect(sql).toMatch(/insert into public\.inventory_events/i);
  });
});

describe("rental scan reliability schema", () => {
  it("stores checkout snapshots, idempotency keys, and partial quantity returns", () => {
    const migration = resolve(migrationsDirectory, reliabilityMigration());
    const sql = readFileSync(migration, "utf8");

    expect(sql).toMatch(/create table if not exists public\.rental_parent_snapshots/i);
    expect(sql).toMatch(/create table if not exists public\.inventory_operations/i);
    expect(sql).toMatch(/returned_quantity integer not null default 0/i);
    expect(sql).toMatch(/create or replace function public\.confirm_checkout/i);
    expect(sql).toMatch(/create or replace function public\.confirm_return/i);
  });
});

describe("serialized asset creation schema", () => {
  it("creates a scanned physical asset atomically with its product", () => {
    const sql = readFileSync(resolve(migrationsDirectory, serializedAssetMigration()), "utf8");
    expect(sql).toMatch(/create function public\.create_product_with_asset\(/i);
    expect(sql).toMatch(/insert into public\.assets/i);
    expect(sql).toMatch(/p_asset_barcode/i);
  });
});

function productOperationsMigration(): string {
  return readdirSync(migrationsDirectory).find((name) =>
    /_product_operations\.sql$/.test(name),
  ) ?? "";
}

function legacyCleanupMigration(): string {
  return readdirSync(migrationsDirectory).find((name) =>
    /_remove_legacy_test_orders\.sql$/.test(name),
  ) ?? "";
}

function rentalLifecycleMigration(): string {
  return readdirSync(migrationsDirectory).find((name) => /_rental_lifecycle\.sql$/.test(name)) ?? "";
}

function reliabilityMigration(): string {
  return readdirSync(migrationsDirectory).find((name) =>
    /_rental_scan_reliability\.sql$/.test(name),
  ) ?? "";
}

function serializedAssetMigration(): string {
  return readdirSync(migrationsDirectory).find((name) =>
    /_create_serialized_product_with_asset\.sql$/.test(name),
  ) ?? "";
}
