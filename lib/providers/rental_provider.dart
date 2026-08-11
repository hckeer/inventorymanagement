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
    List<String> overrideAssetIds = const [],
    String? overrideReason,
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
        overrideAssetIds: overrideAssetIds,
        overrideReason: overrideReason,
      );
      ref.invalidateSelf();
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<String> createAndCheckout({
    required String clientId,
    required DateTime startDate,
    required DateTime endDate,
    required List<RentalLineInput> lines,
    required double depositAmount,
    required bool depositPaid,
    required List<String> parentAssetIds,
    required String requestId,
    String? notes,
    List<String> overrideAssetIds = const [],
    String? overrideReason,
  }) async {
    try {
      final id = await _repo.createAndCheckout(
        clientId: clientId,
        startDate: startDate,
        endDate: endDate,
        lines: lines,
        depositAmount: depositAmount,
        depositPaid: depositPaid,
        parentAssetIds: parentAssetIds,
        requestId: requestId,
        notes: notes,
        overrideAssetIds: overrideAssetIds,
        overrideReason: overrideReason,
      );
      ref.invalidateSelf();
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<String> createManifestCheckout({
    required String clientId,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> barcodes,
    required double depositAmount,
    required bool depositPaid,
    required String requestId,
    String? notes,
  }) async {
    try {
      final id = await _repo.createManifestCheckout(
          clientId: clientId,
          startDate: startDate,
          endDate: endDate,
          barcodes: barcodes,
          depositAmount: depositAmount,
          depositPaid: depositPaid,
          requestId: requestId,
          notes: notes);
      ref.invalidateSelf();
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<List<String>> returnManifest(
      {required String rentalId,
      required List<String> barcodes,
      required String requestId}) async {
    final result = await _repo.returnManifest(
        rentalId: rentalId, barcodes: barcodes, requestId: requestId);
    ref.invalidateSelf();
    return result;
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

  /// Checks out a reserved rental via RPC and refreshes the list.
  Future<void> checkout({
    required String rentalId,
    required List<String> verifiedRentalItemIds,
    required List<String> parentAssetIds,
    required String requestId,
  }) async {
    try {
      await _repo.checkout(
        rentalId: rentalId,
        verifiedRentalItemIds: verifiedRentalItemIds,
        parentAssetIds: parentAssetIds,
        requestId: requestId,
      );
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Marks a rental as returned via RPC and refreshes the list.
  Future<void> markReturned({
    required String rentalId,
    required List<String> verifiedRentalItemIds,
    required List<Map<String, dynamic>> returnedQuantities,
    required String requestId,
  }) async {
    try {
      await _repo.markReturned(
        rentalId: rentalId,
        verifiedRentalItemIds: verifiedRentalItemIds,
        returnedQuantities: returnedQuantities,
        requestId: requestId,
      );
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
final rentalManifestProvider = FutureProvider.family<List<String>, String>(
    (ref, id) => ref.read(rentalRepositoryProvider).getManifest(id));
