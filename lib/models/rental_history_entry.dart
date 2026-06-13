/// A read-only typed projection of an equipment's rental history,
/// assembled from a Supabase join query:
///
/// ```dart
/// supabase
///   .from('rental_items')
///   .select('id, daily_rate_snapshot, damage_notes, '
///           'rental:rentals(id, start_date, end_date, status, '
///           '  client:clients(full_name))')
///   .eq('equipment_id', equipmentId);
/// ```
///
/// Supabase returns each row in the shape:
/// ```json
/// {
///   "id": "...",
///   "daily_rate_snapshot": 120.0,
///   "damage_notes": null,
///   "rental": {
///     "id": "...",
///     "start_date": "2026-06-01",
///     "end_date": "2026-06-05",
///     "status": "returned",
///     "client": { "full_name": "Jane Doe" }
///   }
/// }
/// ```
class RentalHistoryEntry {
  final String rentalItemId;
  final String rentalId;
  final String clientName;
  final DateTime startDate;
  final DateTime endDate;
  final String rentalStatus;
  final double dailyRateSnapshot;
  final String? damageNotes;

  const RentalHistoryEntry({
    required this.rentalItemId,
    required this.rentalId,
    required this.clientName,
    required this.startDate,
    required this.endDate,
    required this.rentalStatus,
    required this.dailyRateSnapshot,
    this.damageNotes,
  });

  // ---------------------------------------------------------------------------
  // Serialisation (read-only — no toJson needed)
  // ---------------------------------------------------------------------------

  factory RentalHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rental = json['rental'] as Map<String, dynamic>;
    final client = rental['client'] as Map<String, dynamic>;
    return RentalHistoryEntry(
      rentalItemId: json['id'] as String,
      rentalId: rental['id'] as String,
      clientName: client['full_name'] as String,
      // start_date / end_date are DATE columns — arrive as plain strings
      startDate: DateTime.parse(rental['start_date'] as String),
      endDate: DateTime.parse(rental['end_date'] as String),
      rentalStatus: rental['status'] as String,
      dailyRateSnapshot: (json['daily_rate_snapshot'] as num).toDouble(),
      damageNotes: json['damage_notes'] as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  /// Number of rental days (inclusive of both start and end date).
  int get rentalDays => endDate.difference(startDate).inDays + 1;

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  RentalHistoryEntry copyWith({
    String? rentalItemId,
    String? rentalId,
    String? clientName,
    DateTime? startDate,
    DateTime? endDate,
    String? rentalStatus,
    double? dailyRateSnapshot,
    Object? damageNotes = _unset,
  }) {
    return RentalHistoryEntry(
      rentalItemId: rentalItemId ?? this.rentalItemId,
      rentalId: rentalId ?? this.rentalId,
      clientName: clientName ?? this.clientName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rentalStatus: rentalStatus ?? this.rentalStatus,
      dailyRateSnapshot: dailyRateSnapshot ?? this.dailyRateSnapshot,
      damageNotes:
          damageNotes == _unset ? this.damageNotes : damageNotes as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // Overrides
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentalHistoryEntry &&
          runtimeType == other.runtimeType &&
          rentalItemId == other.rentalItemId;

  @override
  int get hashCode => rentalItemId.hashCode;

  @override
  String toString() =>
      'RentalHistoryEntry(rentalItemId: $rentalItemId, clientName: $clientName, '
      'status: $rentalStatus, startDate: $startDate, endDate: $endDate)';
}

// Sentinel object for nullable copyWith fields.
const Object _unset = Object();
