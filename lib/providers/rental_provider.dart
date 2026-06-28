import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/rental_repository.dart';
import '../repositories/rental_item_repository.dart';
import '../models/rental.dart';
import '../models/rental_line_input.dart';
import '../models/rental_item.dart';

final rentalRepositoryProvider = Provider<RentalRepository>(
  (ref) => RentalRepository(),
);

final rentalItemRepositoryProvider = Provider<RentalItemRepository>(
  (ref) => RentalItemRepository(),
);

// ---------------------------------------------------------------------------
// Rental list — AsyncNotifier with full lifecycle mutations
// ---------------------------------------------------------------------------

final rentalListProvider =
    AsyncNotifierProvider<RentalListNotifier, List<Rental>>(
  RentalListNotifier.new,
);

class RentalListNotifier extends AsyncNotifier<List<Rental>> {
  RentalRepository get _repo => ref.read(rentalRepositoryProvider);

  @override
  Future<List<Rental>> build() async {
    return _repo.getAll();
  }

  /// Creates a rental via MCP (draft + submit) and refreshes the list.
  Future<String> createAndSubmit({
    required String clientId,
    required DateTime startDate,
    required DateTime endDate,
    required List<RentalLineInput> lines,
    required double depositAmount,
    required bool depositPaid,
    String? notes,
  }) async {
    try {
      final id = await _repo.createAndSubmit(
        clientId: clientId,
        startDate: startDate,
        endDate: endDate,
        lines: lines,
        depositAmount: depositAmount,
        depositPaid: depositPaid,
        notes: notes,
      );
      ref.invalidateSelf();
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Updates rental details and refreshes.
  Future<void> updateRental(Rental rental) async {
    try {
      await _repo.update(rental: rental);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Marks a rental as returned via RPC and refreshes the list.
  Future<void> markReturned(String rentalId) async {
    try {
      await _repo.markReturned(rentalId: rentalId);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Rental detail — FutureProvider.family keyed by rental id
// ---------------------------------------------------------------------------

final rentalDetailProvider =
    FutureProvider.family<Rental, String>((ref, id) async {
  try {
    return await ref.read(rentalRepositoryProvider).getById(id: id);
  } catch (e, st) {
    Error.throwWithStackTrace(e, st);
  }
});

// ---------------------------------------------------------------------------
// Rental items — FutureProvider.family keyed by rental id
// ---------------------------------------------------------------------------

final rentalItemsProvider =
    FutureProvider.family<List<RentalItem>, String>((ref, rentalId) async {
  try {
    return await ref
        .read(rentalItemRepositoryProvider)
        .getByRental(rentalId: rentalId);
  } catch (e, st) {
    Error.throwWithStackTrace(e, st);
  }
});
