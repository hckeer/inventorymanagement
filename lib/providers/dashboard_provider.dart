import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mcp_client.dart';
import '../core/error_handler.dart';

class DashboardStats {
  final int activeRentals;
  final int overdueRentals;
  final int availableEquipment;
  final double todayRevenue;

  const DashboardStats({
    required this.activeRentals,
    required this.overdueRentals,
    required this.availableEquipment,
    required this.todayRevenue,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  try {
    final data = await mcpClient.get('/dashboard/stats');
    return DashboardStats(
      activeRentals: (data['active_rentals'] as num?)?.toInt() ?? 0,
      overdueRentals: (data['overdue_rentals'] as num?)?.toInt() ?? 0,
      availableEquipment: (data['available_serialized'] as num?)?.toInt() ?? 0,
      todayRevenue: 0,
    );
  } on McpApiException catch (e) {
    throw Exception(humanizeError(e.message));
  }
});
