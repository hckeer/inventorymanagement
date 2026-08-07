import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/client.dart';

class ClientRepository {
  Future<List<Client>> getAll({String? searchQuery}) async {
    try {
      final data = await mcpClient.get('/clients');
      var clients = (data['clients'] as List<dynamic>? ?? [])
          .map((e) => Client.fromJson(e as Map<String, dynamic>))
          .toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        clients = clients
            .where((c) => c.fullName.toLowerCase().contains(q))
            .toList();
      }

      clients.sort((a, b) => a.fullName.compareTo(b.fullName));
      return clients;
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Client> getById({required String id}) async {
    try {
      final clients = await getAll();
      final matches = clients.where((client) => client.id == id);
      if (matches.isEmpty) {
        throw Exception('Client with id "$id" not found.');
      }
      return matches.first;
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Client> create({required Client client}) async {
    try {
      final data = await mcpClient.post(
        '/clients',
        body: _toMcpBody(client),
      );
      final customer = data['client'] as Map<String, dynamic>?;
      if (customer == null) {
        throw Exception('Customer create did not return customer data.');
      }
      return Client.fromJson(customer);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Client> update({required Client client}) async {
    try {
      final data = await mcpClient.patch(
        '/clients/${Uri.encodeComponent(client.id)}',
        body: _toMcpBody(client),
      );
      final customer = data['client'] as Map<String, dynamic>?;
      if (customer == null) {
        throw Exception('Customer update did not return customer data.');
      }
      return Client.fromJson(customer);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Map<String, dynamic> _toMcpBody(Client client) {
    return {
      'full_name': client.fullName,
      if (client.phone != null) 'phone': client.phone,
      if (client.email != null) 'email': client.email,
      if (client.idDocument != null) 'id_document': client.idDocument,
    };
  }
}
