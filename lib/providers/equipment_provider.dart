import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/equipment_repository.dart';
import '../models/equipment.dart';
import '../models/equipment_detail.dart';
import '../models/rental_history_entry.dart';

final equipmentRepositoryProvider = Provider<EquipmentRepository>(
  (ref) => EquipmentRepository(),
);

// ---------------------------------------------------------------------------
// Equipment list — AsyncNotifier with CRUD mutations
// ---------------------------------------------------------------------------

final equipmentListProvider =
    AsyncNotifierProvider<EquipmentListNotifier, List<Equipment>>(
  EquipmentListNotifier.new,
);

class EquipmentListNotifier extends AsyncNotifier<List<Equipment>> {
  EquipmentRepository get _repo => ref.read(equipmentRepositoryProvider);

  @override
  Future<List<Equipment>> build() async {
    return _repo.getAll();
  }

  /// Creates equipment and refreshes the list.
  Future<void> create(Equipment equipment, {String? serialNo}) async {
    try {
      await _repo.create(equipment: equipment, serialNo: serialNo);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Updates equipment and refreshes the list.
  Future<void> updateEquipment(
    Equipment equipment, {
    String? newSerialNo,
  }) async {
    try {
      await _repo.update(equipment: equipment, newSerialNo: newSerialNo);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Deletes equipment and refreshes the list.
  Future<void> delete(String id) async {
    try {
      await _repo.delete(id: id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Equipment detail — FutureProvider.family keyed by id
// ---------------------------------------------------------------------------

final equipmentDetailProvider =
    FutureProvider.family<Equipment, String>((ref, id) async {
  try {
    return await ref.read(equipmentRepositoryProvider).getById(id: id);
  } catch (e, st) {
    Error.throwWithStackTrace(e, st);
  }
});

final equipmentDetailFullProvider =
    FutureProvider.family<EquipmentDetail, String>((ref, id) async {
  try {
    return await ref.read(equipmentRepositoryProvider).getDetail(id: id);
  } catch (e, st) {
    Error.throwWithStackTrace(e, st);
  }
});

// ---------------------------------------------------------------------------
// Rental history — FutureProvider.family keyed by equipmentId
// ---------------------------------------------------------------------------

final rentalHistoryProvider =
    FutureProvider.family<List<RentalHistoryEntry>, String>(
        (ref, equipmentId) async {
  try {
    return await ref
        .read(equipmentRepositoryProvider)
        .getRentalHistory(equipmentId: equipmentId);
  } catch (e, st) {
    Error.throwWithStackTrace(e, st);
  }
});
