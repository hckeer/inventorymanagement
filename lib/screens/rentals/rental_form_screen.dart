import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/rental_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/equipment_provider.dart';
import '../../models/client.dart';
import '../../models/equipment.dart';
import '../../models/rental_line_input.dart';
import '../../core/extensions.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_error.dart';

class RentalFormScreen extends ConsumerStatefulWidget {
  const RentalFormScreen({super.key, required this.rentalId});
  final String? rentalId;

  @override
  ConsumerState<RentalFormScreen> createState() => _RentalFormScreenState();
}

class _RentalFormScreenState extends ConsumerState<RentalFormScreen> {
  Client? _selectedClient;
  final List<RentalLineInput> _lines = [];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  bool _depositPaid = false;
  final _notesCtrl = TextEditingController();
  final _depositCtrl = TextEditingController(text: '0');
  bool _loading = false;

  int get _rentalDays =>
      _endDate.difference(_startDate).inDays.clamp(1, 9999);

  double get _estimatedTotal =>
      _lines.fold(0, (sum, line) => sum + line.dailyRate * _rentalDays);

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

  Future<void> _addSerializedLine(List<Equipment> serializedItems) async {
    if (serializedItems.isEmpty) {
      _showError('No serialized items available');
      return;
    }

    Equipment? selectedItem;
    String? selectedSerial;

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            title: const Text(
              'Add serialized line',
              style: TextStyle(color: Color(0xFFEEEEF5)),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Equipment>(
                    value: selectedItem,
                    decoration: const InputDecoration(labelText: 'Item'),
                    dropdownColor: const Color(0xFF1A1A24),
                    style: const TextStyle(color: Color(0xFFEEEEF5)),
                    items: serializedItems
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (item) {
                      setDialogState(() {
                        selectedItem = item;
                        selectedSerial = null;
                      });
                    },
                  ),
                  if (selectedItem != null) ...[
                    const SizedBox(height: 12),
                    FutureBuilder(
                      future: ref
                          .read(equipmentRepositoryProvider)
                          .getDetail(id: selectedItem!.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState !=
                            ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text(
                            snapshot.error.toString(),
                            style: const TextStyle(color: Color(0xFFFF5252)),
                          );
                        }
                        final serials = snapshot.data?.serials ?? [];
                        if (serials.isEmpty) {
                          return const Text(
                            'No serials for this item.',
                            style: TextStyle(color: Color(0xFF9999AA)),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          value: selectedSerial,
                          decoration:
                              const InputDecoration(labelText: 'Serial No'),
                          dropdownColor: const Color(0xFF1A1A24),
                          style: const TextStyle(color: Color(0xFFEEEEF5)),
                          items: serials
                              .map(
                                (serial) => DropdownMenuItem(
                                  value: serial.name,
                                  child: Text(serial.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedSerial = value),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedItem != null &&
                        selectedSerial != null &&
                        selectedSerial!.isNotEmpty
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (added == true && selectedItem != null && selectedSerial != null) {
      setState(() {
        _lines.add(
          RentalLineInput(
            lineType: 'serialized',
            itemCode: selectedItem!.id,
            itemName: selectedItem!.name,
            serialNo: selectedSerial,
            qty: 1,
            dailyRate: selectedItem!.dailyRate,
          ),
        );
      });
    }
  }

  Future<void> _addQtyLine(List<Equipment> qtyItems) async {
    if (qtyItems.isEmpty) {
      _showError('No qty items available');
      return;
    }

    Equipment? selectedItem;
    double qty = 1;

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            title: const Text(
              'Add qty line',
              style: TextStyle(color: Color(0xFFEEEEF5)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Equipment>(
                  value: selectedItem,
                  decoration: const InputDecoration(labelText: 'Item'),
                  dropdownColor: const Color(0xFF1A1A24),
                  style: const TextStyle(color: Color(0xFFEEEEF5)),
                  items: qtyItems
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (item) => setDialogState(() => selectedItem = item),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Qty',
                        style: TextStyle(color: Color(0xFF9999AA))),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: const Color(0xFF9999AA),
                      onPressed: qty > 1
                          ? () => setDialogState(() => qty -= 1)
                          : null,
                    ),
                    Text(
                      qty.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Color(0xFFEEEEF5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: const Color(0xFFE8A838),
                      onPressed: () => setDialogState(() => qty += 1),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedItem != null
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (added == true && selectedItem != null) {
      setState(() {
        _lines.add(
          RentalLineInput(
            lineType: 'qty',
            itemCode: selectedItem!.id,
            itemName: selectedItem!.name,
            qty: qty,
            dailyRate: selectedItem!.dailyRate,
          ),
        );
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedClient == null) {
      _showError('Select a client');
      return;
    }
    if (_lines.isEmpty) {
      _showError('Add at least one rental line');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _showError('End date must be on or after start date');
      return;
    }

    setState(() => _loading = true);
    try {
      final rentalId =
          await ref.read(rentalListProvider.notifier).createAndSubmit(
                clientId: _selectedClient!.id,
                startDate: _startDate,
                endDate: _endDate,
                lines: _lines,
                depositAmount: double.tryParse(_depositCtrl.text) ?? 0,
                depositPaid: _depositPaid,
                notes: _notesCtrl.text.trim().isEmpty
                    ? null
                    : _notesCtrl.text.trim(),
              );

      ref.invalidate(equipmentListProvider);

      if (mounted) context.go('/rentals/$rentalId');
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
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
        error: (e, _) => AppError(
          message: e.toString().replaceFirst('Exception: ', ''),
        ),
        data: (clients) => equipmentAsync.when(
          loading: () => const AppLoading(),
          error: (e, _) => AppError(
            message: e.toString().replaceFirst('Exception: ', ''),
          ),
          data: (allEquipment) {
            final serializedItems =
                allEquipment.where((e) => e.hasSerialNo).toList();
            final qtyItems =
                allEquipment.where((e) => !e.hasSerialNo).toList();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _StepHeader(number: '1', title: 'Select client'),
                const SizedBox(height: 12),
                DropdownButtonFormField<Client>(
                  value: _selectedClient,
                  decoration: const InputDecoration(labelText: 'Client *'),
                  dropdownColor: const Color(0xFF1A1A24),
                  style: const TextStyle(color: Color(0xFFEEEEF5)),
                  items: clients
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: (c) => setState(() => _selectedClient = c),
                ),
                const SizedBox(height: 24),
                _StepHeader(number: '2', title: 'Rental lines'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addSerializedLine(serializedItems),
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: const Text('Serial line'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addQtyLine(qtyItems),
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: const Text('Qty line'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_lines.isEmpty)
                  const Text(
                    'Add serialized equipment (barcode) or qty items (sandbags, etc.).',
                    style: TextStyle(color: Color(0xFF9999AA), fontSize: 13),
                  )
                else
                  ..._lines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A24),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF252533)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.itemName,
                                    style: const TextStyle(
                                      color: Color(0xFFEEEEF5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    line.lineType == 'serialized'
                                        ? 'Serial: ${line.serialNo}'
                                        : 'Qty: ${line.qty.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color(0xFF9999AA),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${line.dailyRate.toCurrency()}/day',
                                    style: const TextStyle(
                                      color: Color(0xFFE8A838),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF9999AA)),
                              onPressed: () =>
                                  setState(() => _lines.removeAt(index)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                _StepHeader(number: '3', title: 'Dates & deposit'),
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
                          decimal: true,
                        ),
                        style: const TextStyle(color: Color(0xFFEEEEF5)),
                        decoration: const InputDecoration(
                          labelText: 'Deposit amount',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        const Text(
                          'Paid',
                          style: TextStyle(
                            color: Color(0xFF9999AA),
                            fontSize: 12,
                          ),
                        ),
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
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                if (_lines.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A838).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE8A838).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Duration',
                          value:
                              '$_rentalDays day${_rentalDays == 1 ? '' : 's'}',
                        ),
                        _SummaryRow(
                          label: 'Lines',
                          value: '${_lines.length}',
                        ),
                        _SummaryRow(
                          label: 'Est. total',
                          value: _estimatedTotal.toCurrency(),
                          highlight: true,
                        ),
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
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF0F0F13),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFEEEEF5),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });
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
            Text(
              label,
              style: const TextStyle(color: Color(0xFF9999AA), fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFFE8A838),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFFEEEEF5),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });
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
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9999AA), fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFFE8A838)
                  : const Color(0xFFEEEEF5),
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              fontSize: highlight ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
