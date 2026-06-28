import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/rental_item.dart';

class RentalItemRepository {
  Future<List<RentalItem>> getByRental({required String rentalId}) async {
    try {
      final data = await mcpClient.get('/rentals/${Uri.encodeComponent(rentalId)}');
      final rental = data['rental'] as Map<String, dynamic>?;
      if (rental == null) {
        return [];
      }

      final lines = rental['items'] as List<dynamic>? ?? [];
      return lines
          .map(
            (line) => RentalItem.fromErpNextLine(
              rentalId: rentalId,
              line: line as Map<String, dynamic>,
            ),
          )
          .toList();
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<void> updateDamageNotes({
    required String rentalId,
    required int lineIdx,
    required String notes,
  }) async {
    try {
      await mcpClient.patch(
        '/rentals/${Uri.encodeComponent(rentalId)}/lines/$lineIdx/damage',
        body: {'damage_notes': notes},
      );
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }
}
