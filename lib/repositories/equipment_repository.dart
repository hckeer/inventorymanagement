import '../core/supabase_client.dart';
import '../core/constants.dart';
import '../models/equipment.dart';
import '../models/rental_history_entry.dart';

class EquipmentRepository {
  /// Returns all equipment, optionally filtered by categoryId and/or status,
  /// ordered by name ascending.
  Future<List<Equipment>> getAll({
    String? categoryId,
    String? status,
  }) async {
    var query = supabase.from(kTableEquipment).select();

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final data = await query.order('name', ascending: true);
    return List<Equipment>.from(
      (data as List).map((e) => Equipment.fromJson(e as Map<String, dynamic>)),
    );
  }

  /// Returns a single equipment record by id. Throws if not found.
  Future<Equipment> getById({required String id}) async {
    final data = await supabase
        .from(kTableEquipment)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) {
      throw Exception('Equipment with id "$id" not found.');
    }
    return Equipment.fromJson(data as Map<String, dynamic>);
  }

  /// Inserts a new equipment record (omits id, created_at, updated_at) and
  /// returns the created row.
  Future<Equipment> create({required Equipment equipment}) async {
    final payload = equipment.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at');

    final data = await supabase
        .from(kTableEquipment)
        .insert(payload)
        .select()
        .single();
    return Equipment.fromJson(data as Map<String, dynamic>);
  }

  /// Updates an existing equipment record by id and returns the updated row.
  Future<Equipment> update({required Equipment equipment}) async {
    final payload = equipment.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at');

    final data = await supabase
        .from(kTableEquipment)
        .update(payload)
        .eq('id', equipment.id)
        .select()
        .single();
    return Equipment.fromJson(data as Map<String, dynamic>);
  }

  /// Deletes the equipment record with the given id.
  Future<void> delete({required String id}) async {
    await supabase.from(kTableEquipment).delete().eq('id', id);
  }

  /// Returns the rental history for a specific equipment item, ordered by
  /// created_at descending.
  Future<List<RentalHistoryEntry>> getRentalHistory({
    required String equipmentId,
  }) async {
    final data = await supabase
        .from(kTableRentalItems)
        .select(
          'id, daily_rate_snapshot, damage_notes, '
          'rental:rentals(id, start_date, end_date, status, client:clients(full_name))',
        )
        .eq('equipment_id', equipmentId)
        .order('created_at', ascending: false);

    return List<RentalHistoryEntry>.from(
      (data as List)
          .map((e) => RentalHistoryEntry.fromJson(e as Map<String, dynamic>)),
    );
  }
}
