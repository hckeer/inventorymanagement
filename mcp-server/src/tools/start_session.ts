import { v4 as uuidv4 } from "uuid";

import type { ErpnextClient } from "../lib/erpnext_client.js";
import { resolveExpectedForContainer } from "../lib/resolve_expected.js";
import { createSession } from "../lib/sessions.js";
import type { ScanSession, SessionMode } from "../lib/types.js";

export interface StartSessionInput {
  mode: SessionMode;
  source_barcode: string;
  destination_barcode: string;
}

export interface StartSessionResult {
  session_id: string;
  mode: SessionMode;
  expected_audited: ScanSession["expected_audited"];
  not_tracked_v1: ScanSession["expected_informational"];
  source_warehouse: string;
  dest_warehouse: string;
  source_label: string;
  destination_label: string;
}

export async function startSession(
  client: ErpnextClient,
  input: StartSessionInput,
): Promise<StartSessionResult> {
  const source = await client.resolveLocation(input.source_barcode);
  const destination = await client.resolveLocation(input.destination_barcode);

  const expectedContainerBarcode =
    input.mode === "dispatch"
      ? input.source_barcode
      : input.destination_barcode;

  const resolvedExpected = await resolveExpectedForContainer(
    client,
    expectedContainerBarcode,
  );

  const session: ScanSession = {
    id: uuidv4(),
    mode: input.mode,
    source_barcode: input.source_barcode,
    destination_barcode: input.destination_barcode,
    source_warehouse: source.warehouse,
    dest_warehouse: destination.warehouse,
    expected_audited: resolvedExpected.expanded.audited,
    expected_informational: resolvedExpected.expanded.informational,
    scanned: [],
    created_at: new Date().toISOString(),
  };

  createSession(session);

  return {
    session_id: session.id,
    mode: session.mode,
    expected_audited: session.expected_audited,
    not_tracked_v1: session.expected_informational,
    source_warehouse: session.source_warehouse,
    dest_warehouse: session.dest_warehouse,
    source_label: source.label,
    destination_label: destination.label,
  };
}
