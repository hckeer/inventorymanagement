class RentalItem {
  final String id;
  final String rentalId;
  final String equipmentId;
  final double dailyRateSnapshot;
  final String? damageNotes;
  final DateTime createdAt;

  const RentalItem({
    required this.id,
    required this.rentalId,
    required this.equipmentId,
    required this.dailyRateSnapshot,
    this.damageNotes,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory RentalItem.fromJson(Map<String, dynamic> json) {
    return RentalItem(
      id: json['id'] as String,
      rentalId: json['rental_id'] as String,
      equipmentId: json['equipment_id'] as String,
      dailyRateSnapshot: (json['daily_rate_snapshot'] as num).toDouble(),
      damageNotes: json['damage_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rental_id': rentalId,
      'equipment_id': equipmentId,
      'daily_rate_snapshot': dailyRateSnapshot,
      'damage_notes': damageNotes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  RentalItem copyWith({
    String? id,
    String? rentalId,
    String? equipmentId,
    double? dailyRateSnapshot,
    Object? damageNotes = _unset,
    DateTime? createdAt,
  }) {
    return RentalItem(
      id: id ?? this.id,
      rentalId: rentalId ?? this.rentalId,
      equipmentId: equipmentId ?? this.equipmentId,
      dailyRateSnapshot: dailyRateSnapshot ?? this.dailyRateSnapshot,
      damageNotes:
          damageNotes == _unset ? this.damageNotes : damageNotes as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Overrides
  // ---------------------------------------------------------------------------

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

// Sentinel object for nullable copyWith fields.
const Object _unset = Object();
