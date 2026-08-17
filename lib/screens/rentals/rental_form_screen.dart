import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/rental_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/equipment_provider.dart';
import '../../models/client.dart';
import '../../models/equipment.dart';
import '../../models/rental_line_input.dart';
import '../../core/mcp_client.dart';
import '../../core/extensions.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_error.dart';
import 'direct_checkout_scanner_screen.dart';

class RentalFormScreen extends ConsumerStatefulWidget {
  const RentalFormScreen({
    super.key,
    required this.rentalId,
  });
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

  int get _rentalDays => _endDate.difference(_startDate).inDays.clamp(1, 9999);

  double get _estimatedTotal => _lines.fold(
      0,
      (sum, line) =>
          sum +
          (line.dailyRate *
              (line.assetId == null ? line.qty : 1) *
              _rentalDays));

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

  Future<void> _addSerializedLine(List<Equipment> allEquipment) async {
    final serializedItems =
        allEquipment.where((item) => item.hasSerialNo).toList();
    if (serializedItems.isEmpty) {
      _showError('No serialized items available');
      return;
    }

    final selectedIds = <String>{};
    final quantities = <String, double>{};

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            title: const Text(
              'Add serialized equipment',
              style: TextStyle(color: Color(0xFFEEEEF5)),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select one or more equipment models.',
                    style: TextStyle(color: Color(0xFF9999AA)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 320,
                    child: ListView(
                      shrinkWrap: true,
                      children: serializedItems.map((item) {
                        final selected = selectedIds.contains(item.id);
                        final quantity = quantities[item.id] ?? 1;
                        return Column(
                          children: [
                            CheckboxListTile(
                              value: selected,
                              onChanged: (value) => setDialogState(() {
                                if (value ?? false) {
                                  selectedIds.add(item.id);
                                  quantities.putIfAbsent(item.id, () => 1);
                                } else {
                                  selectedIds.remove(item.id);
                                }
                              }),
                              title: Text(item.name),
                              subtitle:
                                  Text('${item.availableAssetCount} available'),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            if (selected)
                              Row(
                                children: [
                                  const SizedBox(width: 56),
                                  const Text('Qty'),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.remove_circle_outline),
                                    onPressed: quantity > 1
                                        ? () => setDialogState(() =>
                                            quantities[item.id] = quantity - 1)
                                        : null,
                                  ),
                                  Text(quantity.toStringAsFixed(0)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: quantity <
                                            item.availableAssetCount
                                        ? () => setDialogState(() =>
                                            quantities[item.id] = quantity + 1)
                                        : null,
                                  ),
                                ],
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedIds.isNotEmpty
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (added == true && selectedIds.isNotEmpty) {
      setState(() {
        for (final item
            in serializedItems.where((item) => selectedIds.contains(item.id))) {
          _lines.add(RentalLineInput(
            lineType: 'serialized',
            itemCode: item.id,
            itemName: item.name,
            qty: quantities[item.id] ?? 1,
            dailyRate: item.dailyRate,
          ));
        }
      });
      for (final item
          in serializedItems.where((item) => selectedIds.contains(item.id))) {
        await _offerCheckoutSuggestions(
          item.id,
          allEquipment,
          multiplier: (quantities[item.id] ?? 1).toInt(),
        );
      }
    }
  }

  Future<void> _offerCheckoutSuggestions(
    String serializedProductId,
    List<Equipment> allEquipment, {
    int multiplier = 1,
  }) async {
    try {
      final data = await mcpClient.get(
        '/products/${Uri.encodeComponent(serializedProductId)}/checkout-suggestions',
      );
      final suggestions = (data['suggestions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted || suggestions.isEmpty) return;

      final selected = <String>{
        for (final suggestion in suggestions)
          if (_isSuggestedProductAvailable(suggestion, allEquipment))
            suggestion['quantity_product_id'] as String,
      };
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            title: const Text('Suggested accessories'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: suggestions.map((suggestion) {
                  final product =
                      suggestion['product'] as Map<String, dynamic>?;
                  final productId = suggestion['quantity_product_id'] as String;
                  final item = allEquipment
                      .where((equipment) => equipment.id == productId)
                      .firstOrNull;
                  final available = _isSuggestedProductAvailable(
                    suggestion,
                    allEquipment,
                  );
                  final quantity = suggestion['default_quantity'] as num? ?? 1;
                  return CheckboxListTile(
                    value: selected.contains(productId),
                    enabled: available,
                    onChanged: (value) => setDialogState(() {
                      if (value ?? false) {
                        selected.add(productId);
                      } else {
                        selected.remove(productId);
                      }
                    }),
                    title: Text(
                      item?.name ?? product?['name'] as String? ?? 'Accessory',
                    ),
                    subtitle: Text(
                      available
                          ? '${quantity.toInt()} suggested — ${suggestion['reason']}'
                          : 'Not currently available',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Add selected'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        for (final suggestion in suggestions) {
          final productId = suggestion['quantity_product_id'] as String;
          if (!selected.contains(productId)) continue;
          final item = allEquipment
              .where((equipment) => equipment.id == productId)
              .firstOrNull;
          if (item == null) continue;
          _addOrIncreaseQuantityLine(
            item,
            (suggestion['default_quantity'] as num? ?? 1).toInt() * multiplier,
          );
        }
      });
    } on McpApiException catch (error) {
      _showError(error.message);
    }
  }

  bool _isSuggestedProductAvailable(
    Map<String, dynamic> suggestion,
    List<Equipment> allEquipment,
  ) {
    final productId = suggestion['quantity_product_id'] as String?;
    return productId != null &&
        allEquipment.any(
          (item) => item.id == productId && item.status == 'available',
        );
  }

  void _addOrIncreaseQuantityLine(Equipment item, int quantity) {
    final index = _lines.indexWhere(
      (line) => line.assetId == null && line.itemCode == item.id,
    );
    if (index < 0) {
      _lines.add(RentalLineInput(
        lineType: 'qty',
        itemCode: item.id,
        itemName: item.name,
        qty: quantity.toDouble(),
        dailyRate: item.dailyRate,
      ));
      return;
    }
    final line = _lines[index];
    _lines[index] = RentalLineInput(
      lineType: line.lineType,
      itemCode: line.itemCode,
      itemName: line.itemName,
      serialNo: line.serialNo,
      assetId: line.assetId,
      qty: line.qty + quantity,
      dailyRate: line.dailyRate,
    );
  }

  Future<void> _addQtyLine(
    List<Equipment> qtyItems, {
    Equipment? initialItem,
  }) async {
    if (qtyItems.isEmpty) {
      _showError('No qty items available');
      return;
    }

    final selectedIds = <String>{if (initialItem != null) initialItem.id};
    final quantities = <String, double>{
      if (initialItem != null) initialItem.id: 1,
    };

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
                const Text(
                  'Select one or more items and set each quantity.',
                  style: TextStyle(color: Color(0xFF9999AA)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: ListView(
                    shrinkWrap: true,
                    children: qtyItems.map((item) {
                      final selected = selectedIds.contains(item.id);
                      final quantity = quantities[item.id] ?? 1;
                      return Column(
                        children: [
                          CheckboxListTile(
                            value: selected,
                            onChanged: (value) => setDialogState(() {
                              if (value ?? false) {
                                selectedIds.add(item.id);
                                quantities.putIfAbsent(item.id, () => 1);
                              } else {
                                selectedIds.remove(item.id);
                              }
                            }),
                            title: Text(item.name),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          if (selected)
                            Row(
                              children: [
                                const SizedBox(width: 56),
                                const Text('Qty'),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: quantity > 1
                                      ? () => setDialogState(() =>
                                          quantities[item.id] = quantity - 1)
                                      : null,
                                ),
                                Text(quantity.toStringAsFixed(0)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => setDialogState(
                                      () => quantities[item.id] = quantity + 1),
                                ),
                              ],
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedIds.isNotEmpty
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (added == true && selectedIds.isNotEmpty) {
      setState(() {
        for (final item
            in qtyItems.where((item) => selectedIds.contains(item.id))) {
          _addOrIncreaseQuantityLine(item, (quantities[item.id] ?? 1).toInt());
        }
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

  Future<void> _scanAndCheckout() async {
    if (_selectedClient == null) {
      _showError('Select a client before scanning');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _showError('End date must be on or after start date');
      return;
    }
    final draft = await context.push<DirectCheckoutDraft>(
      '/direct-checkout-scanner',
    );
    if (draft == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final rentalId =
          await ref.read(rentalListProvider.notifier).createAndSubmit(
                clientId: _selectedClient!.id,
                startDate: _startDate,
                endDate: _endDate,
                lines: _mergeManualAndScannedLines(_lines, draft.lines),
                depositAmount: double.tryParse(_depositCtrl.text) ?? 0,
                depositPaid: _depositPaid,
                notes: _notesCtrl.text.trim().isEmpty
                    ? null
                    : _notesCtrl.text.trim(),
              );
      for (final barcode in draft.serializedBarcodes) {
        await ref.read(rentalRepositoryProvider).scanCheckoutAsset(
              rentalId: rentalId,
              barcode: barcode,
            );
      }
      final items = await ref.read(rentalItemsProvider(rentalId).future);
      await ref.read(rentalRepositoryProvider).completeCheckout(
            rentalId: rentalId,
            quantityLines: items
                .where((item) => item.lineType == 'quantity')
                .map((item) => {
                      'rental_item_id': item.id,
                      'quantity': item.qty.toInt(),
                    })
                .toList(),
            requestId: _newRequestId(),
          );
      ref.invalidate(equipmentListProvider);
      ref.invalidate(rentalItemsProvider(rentalId));
      ref.invalidate(rentalDetailProvider(rentalId));
      if (mounted) context.go('/rentals/$rentalId');
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RentalLineInput> _mergeManualAndScannedLines(
    List<RentalLineInput> manual,
    List<RentalLineInput> scanned,
  ) {
    final merged = <String, RentalLineInput>{
      for (final line in manual) line.itemCode: line,
    };
    for (final line in scanned) {
      final existing = merged[line.itemCode];
      if (existing == null) {
        merged[line.itemCode] = line;
        continue;
      }
      merged[line.itemCode] = RentalLineInput(
        lineType: existing.lineType,
        itemCode: existing.itemCode,
        itemName: existing.itemName,
        qty: existing.qty > line.qty ? existing.qty : line.qty,
        dailyRate: existing.dailyRate,
      );
    }
    return merged.values.toList(growable: false);
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
            final availableEquipment = allEquipment
                .where((e) =>
                    e.status.toLowerCase() == 'available' ||
                    e.availableAssetCount > 0)
                .toList();
            final qtyItems =
                availableEquipment.where((e) => !e.hasSerialNo).toList();

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
                        onPressed: () => _addSerializedLine(allEquipment),
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
                    'Choose an equipment model and quantity. Physical barcodes are scanned only at checkout.',
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
                                    line.assetId != null
                                        ? 'Serial: ${line.serialNo}'
                                        : line.lineType == 'serialized'
                                            ? 'Qty: ${line.qty.toStringAsFixed(0)} — physical units chosen at checkout'
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _scanAndCheckout,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan & create checkout'),
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

String _newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
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
              color:
                  highlight ? const Color(0xFFE8A838) : const Color(0xFFEEEEF5),
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              fontSize: highlight ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
