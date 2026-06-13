import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/rental_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/equipment_provider.dart';
import '../../models/client.dart';
import '../../models/equipment.dart';
import '../../core/error_handler.dart';
import '../../core/constants.dart';
import '../../core/extensions.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_error.dart';

class RentalFormScreen extends ConsumerStatefulWidget {
  const RentalFormScreen({super.key, required this.rentalId});
  final String? rentalId; // V1: always null (create only)

  @override
  ConsumerState<RentalFormScreen> createState() => _RentalFormScreenState();
}

class _RentalFormScreenState extends ConsumerState<RentalFormScreen> {
  Client? _selectedClient;
  final List<Equipment> _selectedEquipment = [];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  double _depositAmount = 0;
  bool _depositPaid = false;
  final _notesCtrl = TextEditingController();
  final _depositCtrl = TextEditingController(text: '0');
  bool _loading = false;

  int get _rentalDays => _endDate.difference(_startDate).inDays.clamp(1, 9999);

  double get _estimatedTotal => _selectedEquipment.fold(
      0, (sum, e) => sum + e.dailyRate * _rentalDays);

  @override
  void dispose() {
    _notesCtrl.dispose();
    _depositCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFFE8A838),
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      } else {
        if (picked.isBefore(_startDate)) return;
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedClient == null) {
      _showError('Select a client');
      return;
    }
    if (_selectedEquipment.isEmpty) {
      _showError('Select at least one equipment item');
      return;
    }
    if (!_endDate.isAfter(_startDate) && _endDate != _startDate) {
      _showError('End date must be on or after start date');
      return;
    }

    setState(() => _loading = true);
    try {
      final rentalId = await ref.read(rentalListProvider.notifier).createViaRpc(
            clientId: _selectedClient!.id,
            startDate: _startDate,
            endDate: _endDate,
            equipmentIds: _selectedEquipment.map((e) => e.id).toList(),
            depositAmount: double.tryParse(_depositCtrl.text) ?? 0,
            depositPaid: _depositPaid,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );

      // Invalidate equipment list so status updates are reflected
      ref.invalidate(equipmentListProvider);

      if (mounted) context.go('/rentals/$rentalId');
    } catch (e) {
      if (mounted) _showError(handleSupabaseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFFF5252),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientListProvider);
    final equipmentAsync = ref.watch(equipmentListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Rental'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: clientsAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppError(message: handleSupabaseError(e)),
        data: (clients) => equipmentAsync.when(
          loading: () => const AppLoading(),
          error: (e, _) => AppError(message: handleSupabaseError(e)),
          data: (allEquipment) {
            final availableEquipment = allEquipment
                .where((e) => e.status == kStatusAvailable)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Step 1: Client ───────────────────────────────────────
                _StepHeader(number: '1', title: 'Select client'),
                const SizedBox(height: 12),
                DropdownButtonFormField<Client>(
                  value: _selectedClient,
                  decoration: const InputDecoration(labelText: 'Client *'),
                  dropdownColor: const Color(0xFF1A1A24),
                  style: const TextStyle(color: Color(0xFFEEEEF5)),
                  items: clients
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.fullName),
                          ))
                      .toList(),
                  onChanged: (c) => setState(() => _selectedClient = c),
                ),

                const SizedBox(height: 24),

                // ── Step 2: Equipment ────────────────────────────────────
                _StepHeader(number: '2', title: 'Select equipment'),
                const SizedBox(height: 4),
                Text(
                  '${availableEquipment.length} items available',
                  style: const TextStyle(
                      color: Color(0xFF9999AA), fontSize: 12),
                ),
                const SizedBox(height: 12),

                if (availableEquipment.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No equipment available for rental.',
                      style: TextStyle(color: Color(0xFF9999AA)),
                    ),
                  )
                else
                  ...availableEquipment.map((equip) {
                    final selected = _selectedEquipment.contains(equip);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedEquipment.remove(equip);
                          } else {
                            _selectedEquipment.add(equip);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFE8A838).withValues(alpha: 0.08)
                                : const Color(0xFF1A1A24),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFE8A838)
                                  : const Color(0xFF252533),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                color: selected
                                    ? const Color(0xFFE8A838)
                                    : const Color(0xFF9999AA),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      equip.name,
                                      style: const TextStyle(
                                          color: Color(0xFFEEEEF5),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      equip.dailyRate.toCurrency() + '/day',
                                      style: const TextStyle(
                                          color: Color(0xFF9999AA),
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // ── Step 3: Dates ────────────────────────────────────────
                _StepHeader(number: '3', title: 'Set dates & deposit'),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Start date',
                        date: _startDate.toDisplayDate(),
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateButton(
                        label: 'End date',
                        date: _endDate.toDisplayDate(),
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _depositCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(color: Color(0xFFEEEEF5)),
                        decoration:
                            const InputDecoration(labelText: 'Deposit amount'),
                        onChanged: (v) =>
                            setState(() => _depositAmount = double.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        const Text('Paid',
                            style: TextStyle(
                                color: Color(0xFF9999AA), fontSize: 12)),
                        Switch(
                          value: _depositPaid,
                          activeColor: const Color(0xFFE8A838),
                          onChanged: (v) => setState(() => _depositPaid = v),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Color(0xFFEEEEF5)),
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),

                // ── Summary ──────────────────────────────────────────────
                if (_selectedEquipment.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A838).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE8A838).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(
                            label: 'Duration',
                            value: '$_rentalDays day${_rentalDays == 1 ? '' : 's'}'),
                        _SummaryRow(
                            label: 'Items', value: '${_selectedEquipment.length}'),
                        _SummaryRow(
                            label: 'Est. total',
                            value: _estimatedTotal.toCurrency(),
                            highlight: true),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0F0F13),
                            ),
                          )
                        : const Text('Create rental'),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFE8A838),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    color: Color(0xFF0F0F13),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              color: Color(0xFFEEEEF5),
              fontWeight: FontWeight.w600,
              fontSize: 15),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton(
      {required this.label, required this.date, required this.onTap});
  final String label;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF252533)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9999AA), fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: Color(0xFFE8A838), size: 14),
                const SizedBox(width: 6),
                Text(date,
                    style: const TextStyle(
                        color: Color(0xFFEEEEF5),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9999AA), fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: highlight
                      ? const Color(0xFFE8A838)
                      : const Color(0xFFEEEEF5),
                  fontWeight:
                      highlight ? FontWeight.w700 : FontWeight.w500,
                  fontSize: highlight ? 15 : 13)),
        ],
      ),
    );
  }
}
