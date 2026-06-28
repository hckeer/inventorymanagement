import '../core/constants.dart';

class Rental {
  final String id;
  final String clientId;
  final String createdBy;

  /// DATE column — stored as a date-only value (no time component).
  final DateTime startDate;

  /// DATE column — stored as a date-only value (no time component).
  final DateTime endDate;

  final String status;
  final double depositAmount;
  final bool depositPaid;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Rental({
    required this.id,
    required this.clientId,
    required this.createdBy,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.depositAmount,
    required this.depositPaid,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory Rental.fromJson(Map<String, dynamic> json) {
    return Rental(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      createdBy: json['created_by'] as String,
      // DATE columns arrive as plain date strings, e.g. "2026-06-13"
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: json['status'] as String,
      depositAmount: (json['deposit_amount'] as num).toDouble(),
      depositPaid: json['deposit_paid'] as bool,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory Rental.fromErpNext(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Rental(
      id: json['name'] as String,
      clientId: json['customer'] as String,
      createdBy: json['created_by'] as String? ?? '',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: _mapErpStatus(json['status'] as String?),
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0,
      depositPaid: (json['deposit_paid'] as num?) == 1,
      notes: json['notes'] as String?,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String _mapErpStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return kRentalStatusActive;
      case 'returned':
        return kRentalStatusReturned;
      case 'overdue':
        return kRentalStatusOverdue;
      case 'cancelled':
        return kRentalStatusCancelled;
      default:
        return status?.toLowerCase() ?? kRentalStatusActive;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'created_by': createdBy,
      // Serialize DATE fields back as ISO date strings (no time component)
      'start_date':
          '${startDate.year.toString().padLeft(4, '0')}-'
          '${startDate.month.toString().padLeft(2, '0')}-'
          '${startDate.day.toString().padLeft(2, '0')}',
      'end_date':
          '${endDate.year.toString().padLeft(4, '0')}-'
          '${endDate.month.toString().padLeft(2, '0')}-'
          '${endDate.day.toString().padLeft(2, '0')}',
      'status': status,
      'deposit_amount': depositAmount,
      'deposit_paid': depositPaid,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  /// Number of rental days (inclusive of both start and end date).
  int get rentalDays => endDate.difference(startDate).inDays + 1;

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  Rental copyWith({
    String? id,
    String? clientId,
    String? createdBy,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    double? depositAmount,
    bool? depositPaid,
    Object? notes = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Rental(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      createdBy: createdBy ?? this.createdBy,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      depositAmount: depositAmount ?? this.depositAmount,
      depositPaid: depositPaid ?? this.depositPaid,
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
      other is Rental &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Rental(id: $id, clientId: $clientId, status: $status, '
      'startDate: $startDate, endDate: $endDate)';
}

// Sentinel object for nullable copyWith fields.
const Object _unset = Object();
