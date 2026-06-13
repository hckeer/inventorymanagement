import '../core/supabase_client.dart';
import '../core/constants.dart';
import '../models/rental_item.dart';

class RentalItemRepository {
  /// Returns all rental items for a given rental, ordered by created_at
  /// ascending.
  Future<List<RentalItem>> getByRental({required String rentalId}) async {
    final data = await supabase
        .from(kTableRentalItems)
        .select()
        .eq('rental_id', rentalId)
        .order('created_at', ascending: true);
    return List<RentalItem>.from(
      (data as List).map((e) => RentalItem.fromJson(e as Map<String, dynamic>)),
    );
  }

  /// Updates the damage_notes field for a specific rental item.
  Future<void> updateDamageNotes({
    required String rentalItemId,
    required String notes,
  }) async {
    await supabase
        .from(kTableRentalItems)
        .update({'damage_notes': notes})
        .eq('id', rentalItemId);
  }
}
