import '../core/supabase_client.dart';
import '../core/constants.dart';
import '../models/rental.dart';

class RentalRepository {
  /// Returns all rentals, optionally filtered by status, ordered by
  /// created_at descending.
  Future<List<Rental>> getAll({String? status}) async {
    var query = supabase.from(kTableRentals).select();

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final data = await query.order('created_at', ascending: false);
    return List<Rental>.from(
      (data as List).map((e) => Rental.fromJson(e as Map<String, dynamic>)),
    );
  }

  /// Returns a single rental by id. Throws if not found.
  Future<Rental> getById({required String id}) async {
    final data = await supabase
        .from(kTableRentals)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) {
      throw Exception('Rental with id "$id" not found.');
    }
    return Rental.fromJson(data as Map<String, dynamic>);
  }

  /// Creates a rental via the `create_rental` Supabase RPC and returns the
  /// new rental UUID string.
  Future<String> createViaRpc({
    required String clientId,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> equipmentIds,
    required double depositAmount,
    required bool depositPaid,
    String? notes,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final result = await supabase.rpc('create_rental', params: {
      'p_client_id': clientId,
      'p_created_by': userId,
      'p_start_date': startDate.toIso8601String().split('T').first,
      'p_end_date': endDate.toIso8601String().split('T').first,
      'p_deposit_amount': depositAmount,
      'p_deposit_paid': depositPaid,
      'p_notes': notes,
      'p_equipment_ids': equipmentIds,
    });
    return result as String;
  }

  /// Updates an existing rental (notes, deposit, dates, etc.) by id and
  /// returns the updated row.
  Future<Rental> update({required Rental rental}) async {
    final payload = rental.toJson()
      ..remove('id')
      ..remove('created_at');

    final data = await supabase
        .from(kTableRentals)
        .update(payload)
        .eq('id', rental.id)
        .select()
        .single();
    return Rental.fromJson(data as Map<String, dynamic>);
  }

  /// Marks a rental as returned via the `return_rental` Supabase RPC.
  Future<void> markReturnedViaRpc({required String rentalId}) async {
    await supabase.rpc('return_rental', params: {'p_rental_id': rentalId});
  }
}
