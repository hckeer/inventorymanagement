import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/rental_provider.dart';
import '../../providers/client_provider.dart';
import '../../core/error_handler.dart';
import '../../core/constants.dart';
import '../../core/extensions.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_error.dart';
import '../../widgets/status_badge.dart';

class RentalDetailScreen extends ConsumerWidget {
  const RentalDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentalAsync = ref.watch(rentalDetailProvider(id));
    final itemsAsync = ref.watch(rentalItemsProvider(id));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: rentalAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppError(
          message: handleSupabaseError(e),
          onRetry: () => ref.invalidate(rentalDetailProvider(id)),
        ),
        data: (rental) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Status + Dates ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF252533)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge(status: rental.status),
                      const Spacer(),
                      Text(
                        'ID: ${rental.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                            color: Color(0xFF9999AA), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _DateChip(
                          label: 'Start', date: rental.startDate.toDisplayDate()),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: Color(0xFF9999AA), size: 16),
                      ),
                      _DateChip(
                          label: 'End', date: rental.endDate.toDisplayDate()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.savings_rounded,
                          color: Color(0xFFE8A838), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Deposit: ${rental.depositAmount.toCurrency()}',
                        style: const TextStyle(
                            color: Color(0xFFEEEEF5), fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: rental.depositPaid
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                              : const Color(0xFFFF5252).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rental.depositPaid ? 'Paid' : 'Unpaid',
                          style: TextStyle(
                            color: rental.depositPaid
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF5252),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (rental.notes != null && rental.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      rental.notes!,
                      style: const TextStyle(
                          color: Color(0xFF9999AA),
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ],
                ],
              ),
            ),

            // ── Client info ───────────────────────────────────────────────
            const SizedBox(height: 16),
            _SectionLabel(label: 'Client'),
            const SizedBox(height: 8),
            _ClientSection(clientId: rental.clientId),

            // ── Equipment Items ───────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel(label: 'Equipment'),
            const SizedBox(height: 8),
            itemsAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => AppError(message: handleSupabaseError(e)),
              data: (items) => Column(
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EquipmentItemTile(
                      item: item,
                      rentalId: id,
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Mark Returned ─────────────────────────────────────────────
            if (rental.status == kRentalStatusActive ||
                rental.status == kRentalStatusOverdue) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: _ReturnButton(rentalId: id),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Client mini section ────────────────────────────────────────────────────

class _ClientSection extends ConsumerWidget {
  const _ClientSection({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientDetailProvider(clientId));
    return clientAsync.when(
      loading: () => const SizedBox(height: 44, child: AppLoading()),
      error: (e, _) => Text(handleSupabaseError(e),
          style: const TextStyle(color: Color(0xFF9999AA))),
      data: (client) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF252533)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  const Color(0xFFE8A838).withValues(alpha: 0.12),
              child: Text(
                client.fullName.isNotEmpty
                    ? client.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Color(0xFFE8A838), fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.fullName,
                      style: const TextStyle(
                          color: Color(0xFFEEEEF5),
                          fontWeight: FontWeight.w600)),
                  if (client.phone != null)
                    Text(client.phone!,
                        style: const TextStyle(
                            color: Color(0xFF9999AA), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Equipment item tile ────────────────────────────────────────────────────

class _EquipmentItemTile extends ConsumerStatefulWidget {
  const _EquipmentItemTile({required this.item, required this.rentalId});
  final dynamic item; // RentalItem
  final String rentalId;

  @override
  ConsumerState<_EquipmentItemTile> createState() =>
      _EquipmentItemTileState();
}

class _EquipmentItemTileState extends ConsumerState<_EquipmentItemTile> {
  bool _editingDamage = false;
  late TextEditingController _damageCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _damageCtrl = TextEditingController(text: widget.item.damageNotes ?? '');
  }

  @override
  void dispose() {
    _damageCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDamageNotes() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(rentalItemRepositoryProvider)
          .updateDamageNotes(
            rentalItemId: widget.item.id,
            notes: _damageCtrl.text.trim(),
          );
      ref.invalidate(rentalItemsProvider(widget.rentalId));
      if (mounted) setState(() => _editingDamage = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(handleSupabaseError(e)),
          backgroundColor: const Color(0xFFFF5252),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF252533)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam_rounded,
                  color: Color(0xFFE8A838), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.equipmentId,
                  style: const TextStyle(
                      color: Color(0xFFEEEEF5),
                      fontWeight: FontWeight.w500,
                      fontSize: 13),
                ),
              ),
              Text(
                (item.dailyRateSnapshot as double).toCurrency() + '/day',
                style:
                    const TextStyle(color: Color(0xFFE8A838), fontSize: 12),
              ),
            ],
          ),
          // Damage notes
          const SizedBox(height: 10),
          if (_editingDamage)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _damageCtrl,
                    style:
                        const TextStyle(color: Color(0xFFEEEEF5), fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Damage notes...',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.check_rounded,
                            color: Color(0xFF4CAF50)),
                        onPressed: _saveDamageNotes,
                      ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF9999AA)),
                  onPressed: () => setState(() => _editingDamage = false),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: () => setState(() => _editingDamage = true),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded,
                      color: Color(0xFF9999AA), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.damageNotes ?? 'Add damage notes...',
                      style: TextStyle(
                        color: item.damageNotes != null
                            ? const Color(0xFFEEEEF5)
                            : const Color(0xFF9999AA),
                        fontSize: 12,
                        fontStyle: item.damageNotes == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Return button ──────────────────────────────────────────────────────────

class _ReturnButton extends ConsumerStatefulWidget {
  const _ReturnButton({required this.rentalId});
  final String rentalId;

  @override
  ConsumerState<_ReturnButton> createState() => _ReturnButtonState();
}

class _ReturnButtonState extends ConsumerState<_ReturnButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.check_circle_outline_rounded),
      label: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF0F0F13)))
          : const Text('Mark as returned'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _loading
          ? null
          : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A24),
                  title: const Text('Mark as returned?',
                      style: TextStyle(color: Color(0xFFEEEEF5))),
                  content: const Text(
                    'This will free all equipment on this rental.',
                    style: TextStyle(color: Color(0xFF9999AA)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF9999AA))),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50)),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              setState(() => _loading = true);
              try {
                await ref
                    .read(rentalListProvider.notifier)
                    .markReturned(widget.rentalId);
                if (mounted) context.pop();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(handleSupabaseError(e)),
                    backgroundColor: const Color(0xFFFF5252),
                  ));
                }
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.date});
  final String label;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: Color(0xFF9999AA), fontSize: 10)),
        Text(date,
            style: const TextStyle(
                color: Color(0xFFEEEEF5),
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF9999AA),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      );
}
