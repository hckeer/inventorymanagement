class Equipment {
  final String id;
  final String name;
  final String categoryId;
  final String status;
  final double dailyRate;
  final bool hasSerialNo;
  final String? serialNo;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Equipment({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.status,
    required this.dailyRate,
    this.hasSerialNo = true,
    this.serialNo,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String,
      status: json['status'] as String,
      dailyRate: (json['daily_rate'] as num).toDouble(),
      hasSerialNo: json['has_serial_no'] as bool? ?? true,
      serialNo: json['serial_no'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory Equipment.fromErpNextItem(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Equipment(
      id: json['name'] as String,
      name: json['item_name'] as String? ?? json['name'] as String,
      categoryId: json['item_group'] as String? ?? '',
      status: deriveItemStatus(
        item: json,
        serials: const [],
      ),
      dailyRate: (json['standard_rate'] as num?)?.toDouble() ?? 0,
      hasSerialNo: (json['has_serial_no'] as num? ?? 1) == 1,
      serialNo: null,
      notes: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Derives aggregate status from ERPNext item + serial rows (flutter_erpnextmcp.md).
  static String deriveItemStatus({
    required Map<String, dynamic> item,
    required List<Map<String, dynamic>> serials,
    Set<String> rentedSerials = const {},
  }) {
    if ((item['disabled'] as num? ?? 0) == 1) {
      return 'retired';
    }

    final hasSerial = (item['has_serial_no'] as num? ?? 0) == 1;
    if (!hasSerial) {
      return 'available';
    }

    if (serials.isEmpty) {
      return 'available';
    }

    var anyRented = false;
    var anyMaintenance = false;
    var anyActive = false;

    for (final serial in serials) {
      final name = serial['name'] as String? ?? '';
      final warehouse = (serial['warehouse'] as String? ?? '').toLowerCase();
      final serialStatus = (serial['status'] as String? ?? '').toLowerCase();

      if (rentedSerials.contains(name)) {
        anyRented = true;
      }
      if (warehouse.contains('maintenance') || serialStatus == 'maintenance') {
        anyMaintenance = true;
      }
      if (serialStatus == 'active' || serialStatus == 'delivered') {
        anyActive = true;
      }
    }

    if (anyRented) {
      return 'rented';
    }
    if (anyMaintenance) {
      return 'maintenance';
    }
    if (anyActive || serials.isNotEmpty) {
      return 'available';
    }
    return 'retired';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'status': status,
      'daily_rate': dailyRate,
      'has_serial_no': hasSerialNo,
      'serial_no': serialNo,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  Equipment copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? status,
    double? dailyRate,
    // Use a sentinel to distinguish "set to null" from "leave unchanged"
    Object? serialNo = _unset,
    Object? notes = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipment(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      dailyRate: dailyRate ?? this.dailyRate,
      serialNo: serialNo == _unset ? this.serialNo : serialNo as String?,
      notes: notes == _unset ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Overrides
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Equipment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Equipment(id: $id, name: $name, status: $status, dailyRate: $dailyRate)';
}

// Sentinel object for nullable copyWith fields.
const Object _unset = Object();
