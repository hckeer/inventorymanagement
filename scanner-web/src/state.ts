export type ScanMode = "audit" | "dispatch" | "return";

export type SessionStep =
  | "pick_mode"
  | "scan_source"
  | "scan_destination"
  | "scan_items"
  | "review"
  | "done";

export interface ChatMessage {
  id: string;
  tone: "system" | "ok" | "warn" | "error" | "muted";
  text: string;
  detail?: string;
}

export interface AppState {
  mode: ScanMode;
  step: SessionStep;
  sessionId: string | null;
  sourceBarcode: string | null;
  destinationBarcode: string | null;
  scannedCount: number;
  endResult: import("./mcp_client.js").SessionEndResult | null;
  busy: boolean;
}

export function initialState(): AppState {
  return {
    mode: "audit",
    step: "pick_mode",
    sessionId: null,
    sourceBarcode: null,
    destinationBarcode: null,
    scannedCount: 0,
    endResult: null,
    busy: false,
  };
}

export function stepPrompt(state: AppState): string {
  if (state.mode === "audit") {
    return "Scan a container barcode (e.g. TRAY-004, CART-012)";
  }

  switch (state.step) {
    case "scan_source":
      return state.mode === "return"
        ? "Scan the truck barcode first (e.g. TRUCK-1)"
        : "Scan the source cart or tray barcode";
    case "scan_destination":
      return state.mode === "return"
        ? "Scan the destination cart or tray"
        : "Scan the destination truck (e.g. TRUCK-1)";
    case "scan_items":
      return "Scan every item serial — gun sends Enter after each beep";
    case "review":
      return "Review the list, then confirm or go back to scan more";
    default:
      return "Choose a mode above, then scan";
  }
}

export function resetSession(state: AppState): AppState {
  return {
    ...state,
    step: state.mode === "audit" ? "pick_mode" : "scan_source",
    sessionId: null,
    sourceBarcode: null,
    destinationBarcode: null,
    scannedCount: 0,
    endResult: null,
    busy: false,
  };
}
