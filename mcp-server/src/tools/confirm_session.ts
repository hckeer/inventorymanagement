import type { ErpnextClient } from "../lib/erpnext_client.js";
import {
  getSession,
  SessionNotFoundError,
  updateSession,
} from "../lib/sessions.js";
import type { ConfirmSessionResult } from "../lib/types.js";

export interface ConfirmSessionInput {
  session_id: string;
  proceed_anyway?: boolean;
  reason?: string;
}

export async function confirmSession(
  client: ErpnextClient,
  input: ConfirmSessionInput,
): Promise<ConfirmSessionResult> {
  const session = getSession(input.session_id);
  if (!session) {
    throw new SessionNotFoundError(input.session_id);
  }
  if (session.confirmed_at) {
    throw new Error("Session already confirmed");
  }
  if (!session.end_result) {
    throw new Error("Call end_session before confirm_session");
  }

  const { complete, missing, unexpected } = session.end_result;
  if (!complete && !input.proceed_anyway) {
    throw new ConfirmBlockedError(missing, unexpected);
  }
  if (session.scanned.length === 0) {
    throw new Error("No serials scanned — nothing to transfer");
  }

  const company = await client.resolveCompany();
  const stockEntryId = await client.createMaterialTransfer({
    company,
    sourceWarehouse: session.source_warehouse,
    destWarehouse: session.dest_warehouse,
    serials: session.scanned,
    remark: buildRemark(input.reason, missing, unexpected),
  });

  const grouped = new Map<string, string[]>();
  for (const entry of session.scanned) {
    const list = grouped.get(entry.item_code) ?? [];
    list.push(entry.serial);
    grouped.set(entry.item_code, list);
  }

  const itemsMoved = [...grouped.entries()].map(([item_code, serials]) => ({
    item_code,
    qty: serials.length,
    serials,
  }));

  updateSession(input.session_id, {
    confirmed_at: new Date().toISOString(),
    stock_entry_id: stockEntryId,
    proceed_anyway: input.proceed_anyway ?? false,
    reason: input.reason,
  });

  return {
    stock_entry_id: stockEntryId,
    items_moved: itemsMoved,
  };
}

function buildRemark(
  reason: string | undefined,
  missing: ConfirmBlockedError["missing"],
  unexpected: ConfirmBlockedError["unexpected"],
): string | undefined {
  const parts: string[] = [];
  if (reason?.trim()) {
    parts.push(reason.trim());
  }
  if (missing.length > 0) {
    parts.push(
      `Under-packed: ${missing.map((gap) => `${gap.delta}× ${gap.item_code}`).join(", ")}`,
    );
  }
  if (unexpected.length > 0) {
    parts.push(
      `Unexpected: ${unexpected.map((entry) => entry.serial).join(", ")}`,
    );
  }
  return parts.length > 0 ? parts.join(" | ") : undefined;
}

export class ConfirmBlockedError extends Error {
  constructor(
    readonly missing: Array<{
      item_code: string;
      expected: number;
      actual: number;
      delta: number;
    }>,
    readonly unexpected: Array<{ serial: string; item_code: string }>,
  ) {
    super("Session incomplete — set proceed_anyway to confirm with gaps");
    this.name = "ConfirmBlockedError";
  }
}
