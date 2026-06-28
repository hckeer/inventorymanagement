class RentalItem {
  final String id;
  final String rentalId;
  final String equipmentId;
  final String lineType;
  final String? serialNo;
  final double qty;
  final int lineIdx;
  final double dailyRateSnapshot;
  final String? damageNotes;
  final DateTime createdAt;

  const RentalItem({
    required this.id,
    required this.rentalId,
    required this.equipmentId,
    required this.lineType,
    this.serialNo,
    required this.qty,
    required this.lineIdx,
    required this.dailyRateSnapshot,
    this.damageNotes,
    required this.createdAt,
  });

  factory RentalItem.fromJson(Map<String, dynamic> json) {
    return RentalItem(
      id: json['id'] as String,
      rentalId: json['rental_id'] as String,
      equipmentId: json['equipment_id'] as String,
      lineType: json['line_type'] as String? ?? 'serialized',
      serialNo: json['serial_no'] as String?,
      qty: (json['qty'] as num?)?.toDouble() ?? 1,
      lineIdx: json['line_idx'] as int? ?? 0,
      dailyRateSnapshot: (json['daily_rate_snapshot'] as num).toDouble(),
      damageNotes: json['damage_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  factory RentalItem.fromErpNextLine({
    required String rentalId,
    required Map<String, dynamic> line,
  }) {
    final lineType = line['line_type'] as String? ?? 'serialized';
    final itemCode = line['item_code'] as String? ?? '';
    final serialNo = line['serial_no'] as String?;
    return RentalItem(
      id: '$rentalId-${line['idx'] ?? itemCode}',
      rentalId: rentalId,
      equipmentId: lineType == 'serialized' ? (serialNo ?? itemCode) : itemCode,
      lineType: lineType,
      serialNo: serialNo,
      qty: (line['qty'] as num?)?.toDouble() ?? 1,
      lineIdx: (line['idx'] as num?)?.toInt() ?? 0,
      dailyRateSnapshot: (line['daily_rate_snapshot'] as num?)?.toDouble() ?? 0,
      damageNotes: line['damage_notes'] as String?,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rental_id': rentalId,
      'equipment_id': equipmentId,
      'line_type': lineType,
      'serial_no': serialNo,
      'qty': qty,
      'line_idx': lineIdx,
      'daily_rate_snapshot': dailyRateSnapshot,
      'damage_notes': damageNotes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  RentalItem copyWith({
    String? id,
    String? rentalId,
    String? equipmentId,
    String? lineType,
    Object? serialNo = _unset,
    double? qty,
    int? lineIdx,
    double? dailyRateSnapshot,
    Object? damageNotes = _unset,
    DateTime? createdAt,
  }) {
    return RentalItem(
      id: id ?? this.id,
      rentalId: rentalId ?? this.rentalId,
      equipmentId: equipmentId ?? this.equipmentId,
      lineType: lineType ?? this.lineType,
      serialNo: serialNo == _unset ? this.serialNo : serialNo as String?,
      qty: qty ?? this.qty,
      lineIdx: lineIdx ?? this.lineIdx,
      dailyRateSnapshot: dailyRateSnapshot ?? this.dailyRateSnapshot,
      damageNotes:
          damageNotes == _unset ? this.damageNotes : damageNotes as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentalItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'RentalItem(id: $id, rentalId: $rentalId, equipmentId: $equipmentId, '
      'dailyRateSnapshot: $dailyRateSnapshot)';
}

const Object _unset = Object();
