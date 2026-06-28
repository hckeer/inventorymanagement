import type { ErpnextClient } from "./erpnext_client.js";
import type { ExpandedExpected } from "./types.js";

export interface ResolvedExpected {
  container_barcode: string;
  label: string;
  warehouse: string;
  expanded: ExpandedExpected;
}

export async function resolveExpectedForContainer(
  client: ErpnextClient,
  containerBarcode: string,
): Promise<ResolvedExpected> {
  const container = await client.getWarehouseContainer(containerBarcode);
  const expanded = await expandExpectedContentsAsync(
    client,
    container.expected_contents ?? [],
  );

  return {
    container_barcode: container.container_barcode,
    label: container.label,
    warehouse: container.warehouse,
    expanded,
  };
}

export async function expandExpectedContentsAsync(
  client: ErpnextClient,
  rows: Array<{
    item_code?: string | null;
    equipment_assembly?: string | null;
    qty: number;
    tracking?: string | null;
  }>,
): Promise<ExpandedExpected> {
  const assemblyCache = new Map<
    string,
    Awaited<ReturnType<ErpnextClient["getAssemblyComponents"]>>
  >();

  async function getComponents(assemblyName: string) {
    const cached = assemblyCache.get(assemblyName);
    if (cached) {
      return cached;
    }
    const components = await client.getAssemblyComponents(assemblyName);
    assemblyCache.set(assemblyName, components);
    return components;
  }

  const auditedQty = new Map<string, number>();
  const informational: ExpandedExpected["informational"] = [];

  for (const row of rows) {
    const tracking = (row.tracking ?? "serialized") as "serialized" | "qty_only";
    const qty = Number(row.qty ?? 0);
    if (qty <= 0) {
      continue;
    }

    if (tracking === "qty_only") {
      if (row.item_code) {
        informational.push({
          item_code: row.item_code,
          qty,
          tracking: "qty_only",
        });
      }
      continue;
    }

    if (row.equipment_assembly) {
      const components = await getComponents(row.equipment_assembly);
      for (const component of components) {
        const current = auditedQty.get(component.item_code) ?? 0;
        auditedQty.set(component.item_code, current + component.qty * qty);
      }
    } else if (row.item_code) {
      const current = auditedQty.get(row.item_code) ?? 0;
      auditedQty.set(row.item_code, current + qty);
    }
  }

  const audited = [...auditedQty.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([item_code, itemQty]) => ({ item_code, qty: itemQty }));

  return { audited, informational };
}
