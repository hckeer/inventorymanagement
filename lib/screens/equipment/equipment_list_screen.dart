import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../providers/equipment_provider.dart';
import '../../widgets/app_empty.dart';
import '../../widgets/app_error.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/equipment_card.dart';

class EquipmentListScreen extends ConsumerStatefulWidget {
  const EquipmentListScreen({super.key});

  @override
  ConsumerState<EquipmentListScreen> createState() =>
      _EquipmentListScreenState();
}

class _EquipmentListScreenState extends ConsumerState<EquipmentListScreen> {
  String _selectedStatus = ''; // empty = All

  static const _statusFilters = [
    ('All', ''),
    ('Available', kStatusAvailable),
    ('Rented', kStatusRented),
    ('Maintenance', kStatusMaintenance),
    ('Retired', kStatusRetired),
  ];

  @override
  Widget build(BuildContext context) {
    final asyncEquipment = ref.watch(equipmentListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text(
          'Equipment',
          style: TextStyle(
            color: Color(0xFFEEEEF5),
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFFEEEEF5)),
            onPressed: () async {
              final barcode = await context.push<String>('/scanner');
              if (barcode != null && context.mounted) {
                final equipmentList = ref.read(equipmentListProvider).valueOrNull;
                if (equipmentList != null) {
                  final found = equipmentList.where((e) => e.serialNo == barcode || e.id == barcode).firstOrNull;
                  if (found != null) {
                    context.push('/equipment/${found.id}');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Equipment not found: $barcode'),
                        backgroundColor: const Color(0xFFFF5252),
                      ),
                    );
                  }
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFFEEEEF5)),
            onPressed: () {}, // Future: open search
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Status filter chips ──────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (label, value) = _statusFilters[index];
                final selected = _selectedStatus == value;
                return FilterChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF0F0F13)
                          : const Color(0xFF9999AA),
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedStatus = value);
                  },
                  selectedColor: const Color(0xFFE8A838),
                  backgroundColor: const Color(0xFF1A1A24),
                  checkmarkColor: const Color(0xFF0F0F13),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFFE8A838)
                        : const Color(0xFF252533),
                  ),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                );
              },
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: asyncEquipment.when(
              loading: () => const AppLoading(),
              error: (e, _) => AppError(
                message: e.toString(),
                onRetry: () => ref.invalidate(equipmentListProvider),
              ),
              data: (items) {
                final filtered = _selectedStatus.isEmpty
                    ? items
                    : items
                        .where((e) => e.status == _selectedStatus)
                        .toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    color: const Color(0xFFE8A838),
                    backgroundColor: const Color(0xFF1A1A24),
                    onRefresh: () async =>
                        ref.invalidate(equipmentListProvider),
                    child: ListView(
                      children: const [
                        SizedBox(height: 120),
                        AppEmpty(
                          icon: Icons.videocam_off_rounded,
                          title: 'No equipment found',
                          subtitle: 'Try a different filter or add new equipment',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFFE8A838),
                  backgroundColor: const Color(0xFF1A1A24),
                  onRefresh: () async => ref.invalidate(equipmentListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final equipment = filtered[index];
                      return EquipmentCard(
                        equipment: equipment,
                        onTap: () =>
                            context.push('/equipment/${equipment.id}'),
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
        onPressed: () => context.push('/equipment/new'),
        backgroundColor: const Color(0xFFE8A838),
        foregroundColor: const Color(0xFF0F0F13),
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
