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
      var path = '/items';
      final query = <String>[];
      if (categoryId != null && categoryId.isNotEmpty) {
        query.add('group=${Uri.encodeComponent(categoryId)}');
      }
      if (query.isNotEmpty) {
        path = '$path?${query.join('&')}';
      }

      final data = await mcpClient.get(path);
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => Equipment.fromErpNextItem(e as Map<String, dynamic>))
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
      final data = await mcpClient.get('/items/${Uri.encodeComponent(id)}');
      final item = data['item'] as Map<String, dynamic>?;
      if (item == null) {
        throw Exception('Equipment with id "$id" not found.');
      }

      final serialMaps = (data['serials'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final serials = serialMaps
          .map(EquipmentSerial.fromJson)
          .toList();

      final equipment = Equipment(
        id: item['name'] as String,
        name: item['item_name'] as String? ?? item['name'] as String,
        categoryId: item['item_group'] as String? ?? '',
        status: Equipment.deriveItemStatus(item: item, serials: serialMaps),
        dailyRate: (item['standard_rate'] as num?)?.toDouble() ?? 0,
        hasSerialNo: (item['has_serial_no'] as num? ?? 1) == 1,
        serialNo: serials.length == 1 ? serials.first.name : null,
        notes: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return EquipmentDetail(
        equipment: equipment,
        serials: serials,
        qtyOnHand: (data['qty_on_hand'] as num?)?.toDouble() ?? 0,
        rentalWarehouse: data['rental_warehouse'] as String? ?? '',
      );
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Equipment> create({required Equipment equipment, String? serialNo}) async {
    try {
      final body = <String, dynamic>{
        'item_name': equipment.name,
        'item_group': equipment.categoryId,
        'standard_rate': equipment.dailyRate,
        'has_serial_no': serialNo != null && serialNo.isNotEmpty,
      };
      if (serialNo != null && serialNo.isNotEmpty) {
        body['serial_no'] = serialNo;
      }

      final data = await mcpClient.post('/items', body: body);
      final item = data['item'] as Map<String, dynamic>?;
      if (item == null) {
        throw Exception('Item create did not return item data.');
      }
      return Equipment.fromErpNextItem(item);
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
        '/items/${Uri.encodeComponent(equipment.id)}',
        body: {
          'item_name': equipment.name,
          'item_group': equipment.categoryId,
          'standard_rate': equipment.dailyRate,
        },
      );
      final item = data['item'] as Map<String, dynamic>?;
      if (item == null) {
        throw Exception('Item update did not return item data.');
      }

      if (newSerialNo != null && newSerialNo.isNotEmpty) {
        await mcpClient.post(
          '/serials',
          body: {
            'serial_no': newSerialNo,
            'item_code': equipment.id,
          },
        );
      }

      return Equipment.fromErpNextItem(item);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<void> delete({required String id}) async {
    try {
      await mcpClient.patch(
        '/items/${Uri.encodeComponent(id)}',
        body: {'disabled': 1},
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
