import type { AuditedLine, ItemQtyGap, ScannedSerial } from "./types.js";

export function diffExpectedVsActual(
  expected: AuditedLine[],
  actual: Record<string, number>,
): { missing: ItemQtyGap[]; surplus: ItemQtyGap[] } {
  const missing: ItemQtyGap[] = [];
  const surplus: ItemQtyGap[] = [];

  const expectedItems = new Set(expected.map((line) => line.item_code));

  for (const line of expected) {
    const actualQty = actual[line.item_code] ?? 0;
    if (actualQty < line.qty) {
      missing.push({
        item_code: line.item_code,
        expected: line.qty,
        actual: actualQty,
        delta: line.qty - actualQty,
      });
    } else if (actualQty > line.qty) {
      surplus.push({
        item_code: line.item_code,
        expected: line.qty,
        actual: actualQty,
        delta: actualQty - line.qty,
      });
    }
  }

  for (const [itemCode, actualQty] of Object.entries(actual)) {
    if (!expectedItems.has(itemCode) && actualQty > 0) {
      surplus.push({
        item_code: itemCode,
        expected: 0,
        actual: actualQty,
        delta: actualQty,
      });
    }
  }

  return { missing, surplus };
}

export function reconcileScannedVsExpected(
  expected: AuditedLine[],
  scanned: ScannedSerial[],
): SessionReconcileResult {
  const scannedByItem = new Map<string, ScannedSerial[]>();
  for (const entry of scanned) {
    const list = scannedByItem.get(entry.item_code) ?? [];
    list.push(entry);
    scannedByItem.set(entry.item_code, list);
  }

  const missing: ItemQtyGap[] = [];
  const unexpected: ScannedSerial[] = [];

  for (const line of expected) {
    const scannedForItem = scannedByItem.get(line.item_code) ?? [];
    if (scannedForItem.length < line.qty) {
      missing.push({
        item_code: line.item_code,
        expected: line.qty,
        actual: scannedForItem.length,
        delta: line.qty - scannedForItem.length,
      });
    }
    if (scannedForItem.length > line.qty) {
      unexpected.push(...scannedForItem.slice(line.qty));
    }
  }

  for (const [itemCode, scannedForItem] of scannedByItem.entries()) {
    const expectedLine = expected.find((line) => line.item_code === itemCode);
    if (!expectedLine) {
      unexpected.push(...scannedForItem);
    }
  }

  const complete = missing.length === 0 && unexpected.length === 0;

  return {
    scanned,
    missing,
    unexpected,
    complete,
  };
}

export interface SessionReconcileResult {
  scanned: ScannedSerial[];
  missing: ItemQtyGap[];
  unexpected: ScannedSerial[];
  complete: boolean;
}
