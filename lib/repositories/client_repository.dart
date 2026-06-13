import '../core/supabase_client.dart';
import '../core/constants.dart';
import '../models/client.dart';

class ClientRepository {
  /// Returns all clients, optionally filtered by a case-insensitive name
  /// search, ordered by full_name ascending.
  Future<List<Client>> getAll({String? searchQuery}) async {
    var query = supabase.from(kTableClients).select();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('full_name', '%$searchQuery%');
    }

    final data = await query.order('full_name', ascending: true);
    return List<Client>.from(
      (data as List).map((e) => Client.fromJson(e as Map<String, dynamic>)),
    );
  }

  /// Returns a single client by id. Throws if not found.
  Future<Client> getById({required String id}) async {
    final data = await supabase
        .from(kTableClients)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) {
      throw Exception('Client with id "$id" not found.');
    }
    return Client.fromJson(data as Map<String, dynamic>);
  }

  /// Inserts a new client (omits id, created_at, updated_at) and returns
  /// the created row.
  Future<Client> create({required Client client}) async {
    final payload = client.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at');

    final data = await supabase
        .from(kTableClients)
        .insert(payload)
        .select()
        .single();
    return Client.fromJson(data as Map<String, dynamic>);
  }

  /// Updates an existing client by id and returns the updated row.
  Future<Client> update({required Client client}) async {
    final payload = client.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at');

    final data = await supabase
        .from(kTableClients)
        .update(payload)
        .eq('id', client.id)
        .select()
        .single();
    return Client.fromJson(data as Map<String, dynamic>);
  }
}
