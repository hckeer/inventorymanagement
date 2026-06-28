const MCP_URL = import.meta.env.VITE_MCP_URL ?? "http://localhost:3001";
const MCP_API_KEY = import.meta.env.VITE_MCP_API_KEY ?? "";

export interface AuditedLine {
  item_code: string;
  qty: number;
}

export interface ItemQtyGap {
  item_code: string;
  expected: number;
  actual: number;
  delta: number;
}

export interface InformationalLine extends AuditedLine {
  tracking: "qty_only";
}

export interface AuditResult {
  label: string;
  container_barcode: string;
  warehouse: string;
  expected: AuditedLine[];
  actual: Record<string, number>;
  missing: ItemQtyGap[];
  surplus: ItemQtyGap[];
  not_tracked_v1: InformationalLine[];
}

export interface StartSessionResult {
  session_id: string;
  mode: "dispatch" | "return";
  expected_audited: AuditedLine[];
  not_tracked_v1: InformationalLine[];
  source_warehouse: string;
  dest_warehouse: string;
  source_label: string;
  destination_label: string;
}

export interface ScanSerialResult {
  serial: string;
  item_code: string;
  warehouse: string | null;
  duplicate: boolean;
  scanned_count: number;
}

export interface SessionEndResult {
  scanned: Array<{ serial: string; item_code: string }>;
  missing: ItemQtyGap[];
  unexpected: Array<{ serial: string; item_code: string }>;
  complete: boolean;
}

export interface ConfirmSessionResult {
  stock_entry_id: string;
  items_moved: Array<{ item_code: string; qty: number; serials: string[] }>;
}

async function mcpPost<T>(path: string, body: Record<string, unknown>): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (MCP_API_KEY) {
    headers["X-Api-Key"] = MCP_API_KEY;
  }

  const response = await fetch(`${MCP_URL}${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });

  const payload = await response.json();
  if (!response.ok) {
    const error = payload as {
      error?: string;
      missing?: ItemQtyGap[];
      unexpected?: Array<{ serial: string; item_code: string }>;
    };
    const err = new Error(error.error ?? "Request failed") as Error & {
      status?: number;
      missing?: ItemQtyGap[];
      unexpected?: Array<{ serial: string; item_code: string }>;
    };
    err.status = response.status;
    err.missing = error.missing;
    err.unexpected = error.unexpected;
    throw err;
  }

  return payload as T;
}

export function auditContainer(containerBarcode: string): Promise<AuditResult> {
  return mcpPost("/api/audit_container", { container_barcode: containerBarcode });
}

export function startSession(input: {
  mode: "dispatch" | "return";
  source_barcode: string;
  destination_barcode: string;
}): Promise<StartSessionResult> {
  return mcpPost("/api/start_session", input);
}

export function scanSerial(sessionId: string, serial: string): Promise<ScanSerialResult> {
  return mcpPost("/api/scan_serial", { session_id: sessionId, serial });
}

export function endSession(sessionId: string): Promise<SessionEndResult> {
  return mcpPost("/api/end_session", { session_id: sessionId });
}

export function confirmSession(
  sessionId: string,
  proceedAnyway: boolean,
  reason?: string,
): Promise<ConfirmSessionResult> {
  return mcpPost("/api/confirm_session", {
    session_id: sessionId,
    proceed_anyway: proceedAnyway,
    reason,
  });
}

export async function checkHealth(): Promise<boolean> {
  try {
    const response = await fetch(`${MCP_URL}/health`);
    return response.ok;
  } catch {
    return false;
  }
}
