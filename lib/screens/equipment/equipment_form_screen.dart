import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/equipment_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/equipment.dart';
import '../../core/error_handler.dart';
import '../../core/constants.dart';
import '../../core/extensions.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_error.dart';
import '../../widgets/app_empty.dart';
import '../../widgets/equipment_card.dart';

class EquipmentFormScreen extends ConsumerStatefulWidget {
  const EquipmentFormScreen({super.key, required this.equipmentId});
  final String? equipmentId;

  @override
  ConsumerState<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends ConsumerState<EquipmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dailyRateCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedCategoryId;
  String _status = kStatusAvailable;
  bool _loading = false;
  bool _initialised = false;

  bool get _isEditing => widget.equipmentId != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dailyRateCtrl.dispose();
    _serialCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final equipment = Equipment(
        id: widget.equipmentId ?? '',
        name: _nameCtrl.text.trim(),
        categoryId: _selectedCategoryId!,
        status: _status,
        dailyRate: double.parse(_dailyRateCtrl.text.trim()),
        serialNo: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await ref.read(equipmentListProvider.notifier).updateEquipment(equipment);
      } else {
        await ref.read(equipmentListProvider.notifier).create(equipment);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(handleSupabaseError(e)),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final scheme = Theme.of(context).colorScheme;

    // Pre-fill form when editing and data is available
    if (_isEditing && !_initialised) {
      final detailAsync = ref.watch(equipmentDetailProvider(widget.equipmentId!));
      detailAsync.whenData((equipment) {
        if (!_initialised) {
          _nameCtrl.text = equipment.name;
          _dailyRateCtrl.text = equipment.dailyRate.toString();
          _serialCtrl.text = equipment.serialNo ?? '';
          _notesCtrl.text = equipment.notes ?? '';
          _selectedCategoryId = equipment.categoryId;
          _status = equipment.status;
          _initialised = true;
        }
      });
    } else if (!_isEditing) {
      _initialised = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Equipment' : 'Add Equipment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: categoriesAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppError(message: handleSupabaseError(e)),
        data: (categories) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _field(
                controller: _nameCtrl,
                label: 'Equipment name *',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Category *'),
                dropdownColor: const Color(0xFF1A1A24),
                style: const TextStyle(color: Color(0xFFEEEEF5)),
                items: categories
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
                validator: (v) => v == null ? 'Select a category' : null,
              ),
              const SizedBox(height: 16),

              // Status (only shown when editing)
              if (_isEditing) ...[
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status *'),
                  dropdownColor: const Color(0xFF1A1A24),
                  style: const TextStyle(color: Color(0xFFEEEEF5)),
                  items: [
                    kStatusAvailable,
                    kStatusRented,
                    kStatusMaintenance,
                    kStatusRetired,
                  ]
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.capitalize()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 16),
              ],

              _field(
                controller: _dailyRateCtrl,
                label: 'Daily rate (USD) *',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Daily rate is required';
                  final d = double.tryParse(v.trim());
                  if (d == null || d <= 0) return 'Enter a valid rate greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _field(
                controller: _serialCtrl,
                label: 'Serial number (optional)',
              ),
              const SizedBox(height: 16),

              _field(
                controller: _notesCtrl,
                label: 'Notes (optional)',
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F0F13),
                          ),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Add equipment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Color(0xFFEEEEF5)),
      decoration: InputDecoration(labelText: label),
    );
  }
}
