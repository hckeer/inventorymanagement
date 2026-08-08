import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/equipment.dart';
import '../models/equipment_detail.dart';
import '../models/rental_history_entry.dart';

class EquipmentRepository {
  Future<List<Equipment>> getAll({
    String? categoryId,
    String? status,
  }) async {
    try {
      var path = '/products';
      final query = <String>[];
      if (categoryId != null && categoryId.isNotEmpty) {
        query.add('group=${Uri.encodeComponent(categoryId)}');
      }
      if (query.isNotEmpty) {
        path = '$path?${query.join('&')}';
      }

      final data = await mcpClient.get(path);
      final items = (data['products'] as List<dynamic>? ?? [])
          .map((e) => Equipment.fromProduct(e as Map<String, dynamic>))
          .toList();

      if (status != null && status.isNotEmpty) {
        return items.where((item) => item.status == status).toList();
      }
      return items;
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Equipment> getById({required String id}) async {
    final detail = await getDetail(id: id);
    return detail.equipment;
  }

  Future<EquipmentDetail> getDetail({required String id}) async {
    try {
      final items = await getAll();
      final equipment = items.firstWhere((item) => item.id == id);
      final data = await mcpClient.get('/products/${Uri.encodeComponent(id)}/assets');
      final serialMaps = (data['assets'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final serials = serialMaps
          .map(EquipmentSerial.fromJson)
          .toList();

      return EquipmentDetail(
        equipment: equipment,
        serials: serials,
        qtyOnHand: 0,
        rentalWarehouse: '',
      );
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Equipment> create({required Equipment equipment, String? serialNo}) async {
    try {
      final body = <String, dynamic>{
        'name': equipment.name,
        'category_id': equipment.categoryId,
        'notes': equipment.notes,
        'tracking_mode': equipment.hasSerialNo ? 'serialized' : 'quantity',
        'daily_rate': equipment.dailyRate,
      };
      
      if (serialNo != null && serialNo.isNotEmpty) {
        body['identifiers'] = [
          {'identifier': serialNo, 'identifier_type': 'internal'}
        ];
      }

      // The backend will create the asset for initial_quantity if quantity tracking.
      // But for serialized, we might need a separate call to create the asset if serialNo is provided.
      // For now, let's just create the product.
      
      final data = await mcpClient.post('/products', body: body);
      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) {
        throw Exception('Product create did not return product data.');
      }
      return Equipment.fromProduct(product);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Equipment> update({
    required Equipment equipment,
    String? newSerialNo,
  }) async {
    try {
      final data = await mcpClient.patch(
        '/products/${Uri.encodeComponent(equipment.id)}',
        body: {
          'name': equipment.name,
          'category_id': equipment.categoryId,
          'notes': equipment.notes,
          'daily_rate': equipment.dailyRate,
        },
      );
      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) {
        throw Exception('Product update did not return product data.');
      }
      return Equipment.fromProduct(product);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<void> delete({required String id}) async {
    try {
      await mcpClient.patch(
        '/products/${Uri.encodeComponent(id)}',
        body: {'is_active': false},
      );
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  /// Rental history via MCP rentals — U3 will enrich per serial line.
  Future<List<RentalHistoryEntry>> getRentalHistory({
    required String equipmentId,
  }) async {
    try {
      final data = await mcpClient.get('/rentals');
      final rentals = data['rentals'] as List<dynamic>? ?? [];
      final entries = <RentalHistoryEntry>[];

      for (final rentalSummary in rentals) {
        final summary = rentalSummary as Map<String, dynamic>;
        final rentalName = summary['name'] as String;
        final detailData =
            await mcpClient.get('/rentals/${Uri.encodeComponent(rentalName)}');
        final rental = detailData['rental'] as Map<String, dynamic>?;
        if (rental == null) {
          continue;
        }

        final lines = rental['items'] as List<dynamic>? ?? [];
        for (final line in lines) {
          final row = line as Map<String, dynamic>;
          final itemCode = row['item_code'] as String?;
          final serialNo = row['serial_no'] as String?;
          if (itemCode != equipmentId && serialNo != equipmentId) {
            continue;
          }

          entries.add(
            RentalHistoryEntry(
              rentalItemId: '${rentalName}-${row['idx'] ?? entries.length}',
              rentalId: rentalName,
              clientName: rental['customer'] as String? ?? 'Unknown',
              startDate: DateTime.parse(rental['start_date'] as String),
              endDate: DateTime.parse(rental['end_date'] as String),
              rentalStatus: _mapRentalStatus(rental['status'] as String?),
              dailyRateSnapshot:
                  (row['daily_rate_snapshot'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }

      entries.sort((a, b) => b.startDate.compareTo(a.startDate));
      return entries;
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  String _mapRentalStatus(String? status) {
    return switch (status) {
      'Active' => 'active',
      'Overdue' => 'overdue',
      'Returned' => 'returned',
      'Cancelled' => 'cancelled',
      _ => 'active',
    };
  }
}
