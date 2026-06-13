import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/client_repository.dart';
import '../models/client.dart';

final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepository(),
);

// ---------------------------------------------------------------------------
// Client list — AsyncNotifier with create / update mutations
// ---------------------------------------------------------------------------

final clientListProvider =
    AsyncNotifierProvider<ClientListNotifier, List<Client>>(
  ClientListNotifier.new,
);

class ClientListNotifier extends AsyncNotifier<List<Client>> {
  ClientRepository get _repo => ref.read(clientRepositoryProvider);

  @override
  Future<List<Client>> build() async {
    return _repo.getAll();
  }

  /// Creates a client and refreshes the list.
  Future<void> create(Client client) async {
    try {
      await _repo.create(client: client);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Updates a client and refreshes the list.
  Future<void> updateClient(Client client) async {
    try {
      await _repo.update(client: client);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Client detail — FutureProvider.family keyed by id
// ---------------------------------------------------------------------------

final clientDetailProvider =
    FutureProvider.family<Client, String>((ref, id) async {
  try {
    return await ref.read(clientRepositoryProvider).getById(id: id);
  } catch (e, st) {
    Error.throwWithStackTrace(e, st);
  }
});
