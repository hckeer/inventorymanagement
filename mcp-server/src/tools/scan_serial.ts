import { ErpnextError } from "../lib/erpnext_client.js";
import type { ErpnextClient } from "../lib/erpnext_client.js";
import {
  getSession,
  SessionNotFoundError,
  updateSession,
} from "../lib/sessions.js";
import type { ScannedSerial } from "../lib/types.js";

export interface ScanSerialInput {
  session_id: string;
  serial: string;
}

export interface ScanSerialResult {
  serial: string;
  item_code: string;
  warehouse: string | null;
  duplicate: boolean;
  scanned_count: number;
}

export async function scanSerial(
  client: ErpnextClient,
  input: ScanSerialInput,
): Promise<ScanSerialResult> {
  const session = getSession(input.session_id);
  if (!session) {
    throw new SessionNotFoundError(input.session_id);
  }
  if (session.confirmed_at) {
    throw new Error("Session already confirmed");
  }

  const serial = input.serial.trim();
  if (!serial) {
    throw new Error("Serial barcode is required");
  }

  const duplicate = session.scanned.some((entry) => entry.serial === serial);
  if (duplicate) {
    return {
      serial,
      item_code: session.scanned.find((entry) => entry.serial === serial)!.item_code,
      warehouse: null,
      duplicate: true,
      scanned_count: session.scanned.length,
    };
  }

  let serialDoc;
  try {
    serialDoc = await client.getSerialNo(serial);
  } catch (error) {
    if (error instanceof ErpnextError && error.status === 404) {
      throw new Error(`Unknown serial: ${serial}`);
    }
    throw error;
  }

  const scannedEntry: ScannedSerial = {
    serial,
    item_code: serialDoc.item_code,
  };

  updateSession(input.session_id, {
    scanned: [...session.scanned, scannedEntry],
  });

  return {
    serial,
    item_code: serialDoc.item_code,
    warehouse: serialDoc.warehouse ?? null,
    duplicate: false,
    scanned_count: session.scanned.length + 1,
  };
}
