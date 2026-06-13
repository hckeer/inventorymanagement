import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/rental_provider.dart';
import '../../core/error_handler.dart';
import '../../core/constants.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_error.dart';
import '../../widgets/app_empty.dart';
import '../../widgets/rental_card.dart';

class RentalListScreen extends ConsumerStatefulWidget {
  const RentalListScreen({super.key});

  @override
  ConsumerState<RentalListScreen> createState() => _RentalListScreenState();
}

class _RentalListScreenState extends ConsumerState<RentalListScreen> {
  String? _statusFilter; // null = all

  static const _filters = [
    (label: 'All', value: null),
    (label: 'Active', value: kRentalStatusActive),
    (label: 'Overdue', value: kRentalStatusOverdue),
    (label: 'Returned', value: kRentalStatusReturned),
    (label: 'Cancelled', value: kRentalStatusCancelled),
  ];

  @override
  Widget build(BuildContext context) {
    final rentalsAsync = ref.watch(rentalListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rentals')),
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _filters.map((f) {
                final selected = _statusFilter == f.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _statusFilter = f.value),
                    selectedColor: const Color(0xFFE8A838).withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      color: selected
                          ? const Color(0xFFE8A838)
                          : const Color(0xFF9999AA),
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    backgroundColor: const Color(0xFF1A1A24),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFFE8A838)
                          : const Color(0xFF252533),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),

          // Rental list
          Expanded(
            child: rentalsAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => AppError(
                message: handleSupabaseError(e),
                onRetry: () => ref.invalidate(rentalListProvider),
              ),
              data: (rentals) {
                final filtered = _statusFilter == null
                    ? rentals
                    : rentals
                        .where((r) => r.status == _statusFilter)
                        .toList();

                if (filtered.isEmpty) {
                  return AppEmpty(
                    icon: Icons.receipt_long_outlined,
                    title: 'No rentals',
                    subtitle: _statusFilter == null
                        ? 'Create your first rental'
                        : 'No ${_statusFilter!} rentals',
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFFE8A838),
                  onRefresh: () async => ref.invalidate(rentalListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final rental = filtered[i];
                      return RentalCard(
                        rental: rental,
                        onTap: () => context.push('/rentals/${rental.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/rentals/new'),
        backgroundColor: const Color(0xFFE8A838),
        foregroundColor: const Color(0xFF0F0F13),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
