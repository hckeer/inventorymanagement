import { diffExpectedVsActual } from "../lib/diff.js";
import type { ErpnextClient } from "../lib/erpnext_client.js";
import { resolveExpectedForContainer } from "../lib/resolve_expected.js";
import type { AuditResult } from "../lib/types.js";

export async function auditContainer(
  client: ErpnextClient,
  containerBarcode: string,
): Promise<AuditResult> {
  const resolved = await resolveExpectedForContainer(client, containerBarcode);
  const actual = await client.getStockBalanceByItem(resolved.warehouse);
  const { missing, surplus } = diffExpectedVsActual(
    resolved.expanded.audited,
    actual,
  );

  return {
    label: resolved.label,
    container_barcode: resolved.container_barcode,
    warehouse: resolved.warehouse,
    expected: resolved.expanded.audited,
    actual,
    missing,
    surplus,
    not_tracked_v1: resolved.expanded.informational,
  };
}
