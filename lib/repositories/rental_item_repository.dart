import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/rental_item.dart';

class RentalItemRepository {
  Future<List<RentalItem>> getByRental({required String rentalId}) async {
    try {
      final data = await mcpClient.get('/rentals/${Uri.encodeComponent(rentalId)}/items');
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((item) => RentalItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<void> updateDamageNotes({
    required String itemId,
    required String notes,
  }) async {
    try {
      await mcpClient.patch(
        '/rental-items/${Uri.encodeComponent(itemId)}/damage',
        body: {'damage_notes': notes},
      );
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }
}
