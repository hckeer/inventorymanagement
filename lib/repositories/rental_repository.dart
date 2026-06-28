import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/rental.dart';
import '../models/rental_line_input.dart';

class RentalRepository {
  Future<List<Rental>> getAll({String? status}) async {
    try {
      var path = '/rentals';
      if (status != null && status.isNotEmpty) {
        final erpStatus = status[0].toUpperCase() + status.substring(1);
        path = '$path?status=${Uri.encodeComponent(erpStatus)}';
      }
      final data = await mcpClient.get(path);
      return (data['rentals'] as List<dynamic>? ?? [])
          .map((e) => Rental.fromErpNext(e as Map<String, dynamic>))
          .toList();
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Rental> getById({required String id}) async {
    try {
      final data = await mcpClient.get('/rentals/${Uri.encodeComponent(id)}');
      final rental = data['rental'] as Map<String, dynamic>?;
      if (rental == null) {
        throw Exception('Rental with id "$id" not found.');
      }
      return Rental.fromErpNext(rental);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<String> createAndSubmit({
    required String clientId,
    required DateTime startDate,
    required DateTime endDate,
    required List<RentalLineInput> lines,
    required double depositAmount,
    required bool depositPaid,
    String? notes,
  }) async {
    try {
      final createData = await mcpClient.post(
        '/rentals',
        body: {
          'customer': clientId,
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
          'deposit_amount': depositAmount,
          'deposit_paid': depositPaid,
          if (notes != null) 'notes': notes,
          'items': lines.map((line) => line.toMcpJson()).toList(),
        },
      );
      final rental = createData['rental'] as Map<String, dynamic>?;
      final name = rental?['name'] as String?;
      if (name == null || name.isEmpty) {
        throw Exception('Rental create did not return a name.');
      }

      final submitData = await mcpClient.post(
        '/rentals/${Uri.encodeComponent(name)}/submit',
      );
      final submitted = submitData['rental'] as Map<String, dynamic>?;
      return submitted?['name'] as String? ?? name;
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Rental> update({required Rental rental, List<RentalLineInput>? lines}) async {
    try {
      final body = <String, dynamic>{
        'customer': rental.clientId,
        'start_date': _formatDate(rental.startDate),
        'end_date': _formatDate(rental.endDate),
        'deposit_amount': rental.depositAmount,
        'deposit_paid': rental.depositPaid,
        if (rental.notes != null) 'notes': rental.notes,
        if (lines != null) 'items': lines.map((line) => line.toMcpJson()).toList(),
      };
      final data = await mcpClient.patch(
        '/rentals/${Uri.encodeComponent(rental.id)}',
        body: body,
      );
      final updated = data['rental'] as Map<String, dynamic>?;
      if (updated == null) {
        throw Exception('Rental update did not return rental data.');
      }
      return Rental.fromErpNext(updated);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<void> markReturned({required String rentalId}) async {
    try {
      await mcpClient.post('/rentals/${Uri.encodeComponent(rentalId)}/return');
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
