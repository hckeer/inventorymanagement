import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_client.dart';
import '../core/constants.dart';

/// Aggregated dashboard statistics fetched in a single parallel request batch.
class DashboardStats {
  final int activeRentals;
  final int overdueRentals;
  final int availableEquipment;

  /// Sum of daily_rate_snapshot * rental_days for rentals starting today.
  /// V1 placeholder — revenue dashboard is V2.
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
    // Run all 3 count queries in parallel.
    final results = await Future.wait([
      supabase
          .from(kTableRentals)
          .select('id')
          .eq('status', kRentalStatusActive),
      supabase
          .from(kTableRentals)
          .select('id')
          .eq('status', kRentalStatusOverdue),
      supabase
          .from(kTableEquipment)
          .select('id')
          .eq('status', kStatusAvailable),
    ]);

    return DashboardStats(
      activeRentals: (results[0] as List).length,
      overdueRentals: (results[1] as List).length,
      availableEquipment: (results[2] as List).length,
      todayRevenue: 0, // V1: placeholder — revenue dashboard is V2
    );
  } catch (e, st) {
    Error.throwWithStackTrace(e, st);
  }
});
