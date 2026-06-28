import type {
  AssemblyComponent,
  AuditedLine,
  ExpectedContentRow,
  ExpandedExpected,
  InformationalLine,
} from "./types.js";

/**
 * Expand expected_contents into audited vs informational lines.
 * Mirrors lightbenders_warehouse/services/expand_assembly.py
 */
export function expandAssembly(
  rows: ExpectedContentRow[],
  getAssemblyComponents: (assemblyName: string) => AssemblyComponent[],
): ExpandedExpected {
  const auditedQty = new Map<string, number>();
  const informational: InformationalLine[] = [];

  for (const row of rows) {
    const tracking = row.tracking ?? "serialized";
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
      for (const component of getAssemblyComponents(row.equipment_assembly)) {
        const current = auditedQty.get(component.item_code) ?? 0;
        auditedQty.set(component.item_code, current + component.qty * qty);
      }
    } else if (row.item_code) {
      const current = auditedQty.get(row.item_code) ?? 0;
      auditedQty.set(row.item_code, current + qty);
    }
  }

  const audited: AuditedLine[] = [...auditedQty.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([item_code, itemQty]) => ({ item_code, qty: itemQty }));

  return { audited, informational };
}
