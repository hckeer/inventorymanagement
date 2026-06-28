class WarehouseAuditedLine {
  const WarehouseAuditedLine({required this.itemCode, required this.qty});

  final String itemCode;
  final num qty;

  factory WarehouseAuditedLine.fromJson(Map<String, dynamic> json) {
    return WarehouseAuditedLine(
      itemCode: json['item_code'] as String,
      qty: json['qty'] as num,
    );
  }
}

class WarehouseItemQtyGap {
  const WarehouseItemQtyGap({
    required this.itemCode,
    required this.expected,
    required this.actual,
    required this.delta,
  });

  final String itemCode;
  final num expected;
  final num actual;
  final num delta;

  factory WarehouseItemQtyGap.fromJson(Map<String, dynamic> json) {
    return WarehouseItemQtyGap(
      itemCode: json['item_code'] as String,
      expected: json['expected'] as num,
      actual: json['actual'] as num,
      delta: json['delta'] as num,
    );
  }
}

class WarehouseInformationalLine extends WarehouseAuditedLine {
  const WarehouseInformationalLine({
    required super.itemCode,
    required super.qty,
  });

  factory WarehouseInformationalLine.fromJson(Map<String, dynamic> json) {
    return WarehouseInformationalLine(
      itemCode: json['item_code'] as String,
      qty: json['qty'] as num,
    );
  }
}

class WarehouseAuditResult {
  const WarehouseAuditResult({
    required this.label,
    required this.containerBarcode,
    required this.warehouse,
    required this.expected,
    required this.actual,
    required this.missing,
    required this.surplus,
    required this.notTrackedV1,
  });

  final String label;
  final String containerBarcode;
  final String warehouse;
  final List<WarehouseAuditedLine> expected;
  final Map<String, num> actual;
  final List<WarehouseItemQtyGap> missing;
  final List<WarehouseItemQtyGap> surplus;
  final List<WarehouseInformationalLine> notTrackedV1;

  bool get isComplete => missing.isEmpty && surplus.isEmpty;

  factory WarehouseAuditResult.fromJson(Map<String, dynamic> json) {
    final actualRaw = json['actual'] as Map<String, dynamic>? ?? {};
    return WarehouseAuditResult(
      label: json['label'] as String,
      containerBarcode: json['container_barcode'] as String,
      warehouse: json['warehouse'] as String,
      expected: (json['expected'] as List<dynamic>? ?? [])
          .map((row) => WarehouseAuditedLine.fromJson(row as Map<String, dynamic>))
          .toList(),
      actual: actualRaw.map((key, value) => MapEntry(key, value as num)),
      missing: (json['missing'] as List<dynamic>? ?? [])
          .map((row) => WarehouseItemQtyGap.fromJson(row as Map<String, dynamic>))
          .toList(),
      surplus: (json['surplus'] as List<dynamic>? ?? [])
          .map((row) => WarehouseItemQtyGap.fromJson(row as Map<String, dynamic>))
          .toList(),
      notTrackedV1: (json['not_tracked_v1'] as List<dynamic>? ?? [])
          .map((row) =>
              WarehouseInformationalLine.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WarehouseSessionStartResult {
  const WarehouseSessionStartResult({
    required this.sessionId,
    required this.mode,
    required this.expectedAudited,
    required this.notTrackedV1,
    required this.sourceWarehouse,
    required this.destWarehouse,
    required this.sourceLabel,
    required this.destinationLabel,
  });

  final String sessionId;
  final String mode;
  final List<WarehouseAuditedLine> expectedAudited;
  final List<WarehouseInformationalLine> notTrackedV1;
  final String sourceWarehouse;
  final String destWarehouse;
  final String sourceLabel;
  final String destinationLabel;

  factory WarehouseSessionStartResult.fromJson(Map<String, dynamic> json) {
    return WarehouseSessionStartResult(
      sessionId: json['session_id'] as String,
      mode: json['mode'] as String,
      expectedAudited: (json['expected_audited'] as List<dynamic>? ?? [])
          .map((row) => WarehouseAuditedLine.fromJson(row as Map<String, dynamic>))
          .toList(),
      notTrackedV1: (json['not_tracked_v1'] as List<dynamic>? ?? [])
          .map((row) =>
              WarehouseInformationalLine.fromJson(row as Map<String, dynamic>))
          .toList(),
      sourceWarehouse: json['source_warehouse'] as String,
      destWarehouse: json['dest_warehouse'] as String,
      sourceLabel: json['source_label'] as String,
      destinationLabel: json['destination_label'] as String,
    );
  }
}

class WarehouseScanResult {
  const WarehouseScanResult({
    required this.serial,
    required this.itemCode,
    required this.duplicate,
    required this.scannedCount,
    this.warehouse,
  });

  final String serial;
  final String itemCode;
  final String? warehouse;
  final bool duplicate;
  final int scannedCount;

  factory WarehouseScanResult.fromJson(Map<String, dynamic> json) {
    return WarehouseScanResult(
      serial: json['serial'] as String,
      itemCode: json['item_code'] as String,
      warehouse: json['warehouse'] as String?,
      duplicate: json['duplicate'] == true,
      scannedCount: (json['scanned_count'] as num).toInt(),
    );
  }
}

class WarehouseScannedSerial {
  const WarehouseScannedSerial({required this.serial, required this.itemCode});

  final String serial;
  final String itemCode;

  factory WarehouseScannedSerial.fromJson(Map<String, dynamic> json) {
    return WarehouseScannedSerial(
      serial: json['serial'] as String,
      itemCode: json['item_code'] as String,
    );
  }
}

class WarehouseSessionEndResult {
  const WarehouseSessionEndResult({
    required this.scanned,
    required this.missing,
    required this.unexpected,
    required this.complete,
  });

  final List<WarehouseScannedSerial> scanned;
  final List<WarehouseItemQtyGap> missing;
  final List<WarehouseScannedSerial> unexpected;
  final bool complete;

  factory WarehouseSessionEndResult.fromJson(Map<String, dynamic> json) {
    return WarehouseSessionEndResult(
      scanned: (json['scanned'] as List<dynamic>? ?? [])
          .map((row) => WarehouseScannedSerial.fromJson(row as Map<String, dynamic>))
          .toList(),
      missing: (json['missing'] as List<dynamic>? ?? [])
          .map((row) => WarehouseItemQtyGap.fromJson(row as Map<String, dynamic>))
          .toList(),
      unexpected: (json['unexpected'] as List<dynamic>? ?? [])
          .map((row) => WarehouseScannedSerial.fromJson(row as Map<String, dynamic>))
          .toList(),
      complete: json['complete'] == true,
    );
  }
}

class WarehouseConfirmResult {
  const WarehouseConfirmResult({
    required this.stockEntryId,
    required this.itemsMoved,
  });

  final String stockEntryId;
  final List<WarehouseMovedItem> itemsMoved;

  factory WarehouseConfirmResult.fromJson(Map<String, dynamic> json) {
    return WarehouseConfirmResult(
      stockEntryId: json['stock_entry_id'] as String,
      itemsMoved: (json['items_moved'] as List<dynamic>? ?? [])
          .map((row) => WarehouseMovedItem.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WarehouseMovedItem {
  const WarehouseMovedItem({
    required this.itemCode,
    required this.qty,
    required this.serials,
  });

  final String itemCode;
  final num qty;
  final List<String> serials;

  factory WarehouseMovedItem.fromJson(Map<String, dynamic> json) {
    return WarehouseMovedItem(
      itemCode: json['item_code'] as String,
      qty: json['qty'] as num,
      serials: (json['serials'] as List<dynamic>? ?? [])
          .map((s) => s as String)
          .toList(),
    );
  }
}
