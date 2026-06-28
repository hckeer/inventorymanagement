export type TrackingMode = "serialized" | "qty_only";

export interface ExpectedContentRow {
  item_code?: string | null;
  equipment_assembly?: string | null;
  qty: number;
  tracking?: TrackingMode | null;
}

export interface AuditedLine {
  item_code: string;
  qty: number;
}

export interface InformationalLine extends AuditedLine {
  tracking: "qty_only";
}

export interface ExpandedExpected {
  audited: AuditedLine[];
  informational: InformationalLine[];
}

export interface AssemblyComponent {
  item_code: string;
  qty: number;
}

export interface WarehouseContainerDoc {
  name: string;
  container_barcode: string;
  label: string;
  container_type: string;
  warehouse: string;
  expected_contents: ExpectedContentRow[];
}

export interface SerialNoDoc {
  name: string;
  item_code: string;
  warehouse?: string | null;
  status?: string | null;
}

export type SessionMode = "dispatch" | "return";

export interface ScannedSerial {
  serial: string;
  item_code: string;
}

export interface ScanSession {
  id: string;
  mode: SessionMode;
  source_barcode: string;
  destination_barcode: string;
  source_warehouse: string;
  dest_warehouse: string;
  expected_audited: AuditedLine[];
  expected_informational: InformationalLine[];
  scanned: ScannedSerial[];
  created_at: string;
  ended_at?: string;
  end_result?: SessionEndResult;
  confirmed_at?: string;
  stock_entry_id?: string;
  proceed_anyway?: boolean;
  reason?: string;
}

export interface ItemQtyGap {
  item_code: string;
  expected: number;
  actual: number;
  delta: number;
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

export interface SessionEndResult {
  scanned: ScannedSerial[];
  missing: ItemQtyGap[];
  unexpected: ScannedSerial[];
  complete: boolean;
}

export interface ConfirmSessionResult {
  stock_entry_id: string;
  items_moved: Array<{ item_code: string; qty: number; serials: string[] }>;
}
