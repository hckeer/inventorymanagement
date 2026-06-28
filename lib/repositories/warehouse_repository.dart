import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/warehouse.dart';

class WarehouseRepository {
  Future<WarehouseAuditResult> auditContainer(String containerBarcode) async {
    try {
      final data = await mcpClient.postWarehouse(
        '/warehouse/audit',
        body: {'container_barcode': containerBarcode},
      );
      return WarehouseAuditResult.fromJson(data);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<WarehouseSessionStartResult> startSession({
    required String mode,
    required String sourceBarcode,
    required String destinationBarcode,
  }) async {
    try {
      final data = await mcpClient.postWarehouse(
        '/warehouse/session/start',
        body: {
          'mode': mode,
          'source_barcode': sourceBarcode,
          'destination_barcode': destinationBarcode,
        },
      );
      return WarehouseSessionStartResult.fromJson(data);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<WarehouseScanResult> scanSerial({
    required String sessionId,
    required String serial,
  }) async {
    try {
      final data = await mcpClient.postWarehouse(
        '/warehouse/session/scan',
        body: {'session_id': sessionId, 'serial': serial},
      );
      return WarehouseScanResult.fromJson(data);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<WarehouseSessionEndResult> endSession(String sessionId) async {
    try {
      final data = await mcpClient.postWarehouse(
        '/warehouse/session/end',
        body: {'session_id': sessionId},
      );
      return WarehouseSessionEndResult.fromJson(data);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<WarehouseConfirmResult> confirmSession({
    required String sessionId,
    bool proceedAnyway = false,
    String? reason,
  }) async {
    try {
      final body = <String, dynamic>{
        'session_id': sessionId,
        'proceed_anyway': proceedAnyway,
      };
      if (reason != null && reason.isNotEmpty) {
        body['reason'] = reason;
      }
      final data = await mcpClient.postWarehouse(
        '/warehouse/session/confirm',
        body: body,
      );
      return WarehouseConfirmResult.fromJson(data);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<bool> checkHealth() => mcpClient.checkHealth();
}
