import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions.dart';
import '../../models/rental_history_entry.dart';
import '../../providers/category_provider.dart';
import '../../providers/equipment_provider.dart';
import '../../widgets/app_error.dart';
import '../../widgets/app_loading.dart';

class EquipmentDetailScreen extends ConsumerWidget {
  final String id;

  const EquipmentDetailScreen({super.key, required this.id});

  Color _statusColor(String status) => switch (status) {
        'available' => Colors.green,
        'rented' => Colors.blue,
        'maintenance' => const Color(0xFFE8A838),
        'retired' => const Color(0xFF9999AA),
        _ => const Color(0xFF9999AA),
      };

  Color _rentalStatusColor(String status) => switch (status) {
        'active' => Colors.blue,
        'overdue' => const Color(0xFFFF5252),
        'returned' => Colors.green,
        'cancelled' => const Color(0xFF9999AA),
        _ => const Color(0xFF9999AA),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEquipment = ref.watch(equipmentDetailProvider(id));
    final asyncCategories = ref.watch(categoryListProvider);
    final asyncHistory = ref.watch(rentalHistoryProvider(id));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: asyncEquipment.when(
        loading: () => const Scaffold(
          backgroundColor: Color(0xFF0F0F13),
          body: AppLoading(),
        ),
        error: (e, _) => Scaffold(
          backgroundColor: const Color(0xFF0F0F13),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F0F13),
            iconTheme:
                const IconThemeData(color: Color(0xFFEEEEF5)),
          ),
          body: AppError(
            message: e.toString(),
            onRetry: () => ref.invalidate(equipmentDetailProvider(id)),
          ),
        ),
        data: (equipment) {
          final categoryName = asyncCategories.whenOrNull(
                data: (cats) {
                  final match = cats.where(
                    (c) => c.id == equipment.categoryId,
                  );
                  return match.isNotEmpty ? match.first.name : 'Unknown';
                },
              ) ??
              '—';

          return Scaffold(
            backgroundColor: const Color(0xFF0F0F13),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F0F13),
              iconTheme: const IconThemeData(color: Color(0xFFEEEEF5)),
              title: Text(
                equipment.name,
                style: const TextStyle(
                  color: Color(0xFFEEEEF5),
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFFE8A838)),
                  tooltip: 'Edit',
                  onPressed: () => context.push('/equipment/$id/edit'),
                ),
              ],
              elevation: 0,
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Header card ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(equipment.status)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _statusColor(equipment.status)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          equipment.status.toUpperCase(),
                          style: TextStyle(
                            color: _statusColor(equipment.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        equipment.name,
                        style: const TextStyle(
                          color: Color(0xFFEEEEF5),
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        categoryName,
                        style: const TextStyle(
                          color: Color(0xFF9999AA),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.attach_money,
                              color: Color(0xFFE8A838), size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${equipment.dailyRate.toCurrency()} / day',
                            style: const TextStyle(
                              color: Color(0xFFE8A838),
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Details card ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Details',
                        style: TextStyle(
                          color: Color(0xFFEEEEF5),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.qr_code,
                        label: 'Serial Number',
                        value: equipment.serialNo?.isNotEmpty == true
                            ? equipment.serialNo!
                            : '—',
                      ),
                      if (equipment.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.notes,
                          label: 'Notes',
                          value: equipment.notes!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Rental History ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rental History',
                        style: TextStyle(
                          color: Color(0xFFEEEEF5),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      asyncHistory.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: AppLoading(),
                        ),
                        error: (e, _) => AppError(
                          message: e.toString(),
                          onRetry: () =>
                              ref.invalidate(rentalHistoryProvider(id)),
                        ),
                        data: (history) {
                          if (history.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No rental history yet.',
                                style: TextStyle(color: Color(0xFF9999AA)),
                              ),
                            );
                          }
                          return Column(
                            children: history
                                .map(
                                  (entry) => _HistoryEntryTile(
                                    entry: entry,
                                    rentalStatusColor: _rentalStatusColor,
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF9999AA), size: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9999AA),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFEEEEF5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── History entry tile ────────────────────────────────────────────────────────

class _HistoryEntryTile extends StatelessWidget {
  final RentalHistoryEntry entry;
  final Color Function(String) rentalStatusColor;

  const _HistoryEntryTile({
    required this.entry,
    required this.rentalStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF252533),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.clientName,
                  style: const TextStyle(
                    color: Color(0xFFEEEEF5),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.startDate.toDisplayDate()} – ${entry.endDate.toDisplayDate()}',
                  style: const TextStyle(
                    color: Color(0xFF9999AA),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.dailyRateSnapshot.toCurrency(),
                  style: const TextStyle(
                    color: Color(0xFFE8A838),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: rentalStatusColor(entry.rentalStatus)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: rentalStatusColor(entry.rentalStatus)
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              entry.rentalStatus.toUpperCase(),
              style: TextStyle(
                color: rentalStatusColor(entry.rentalStatus),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
