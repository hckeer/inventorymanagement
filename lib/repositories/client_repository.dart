import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/client.dart';

class ClientRepository {
  Future<List<Client>> getAll({String? searchQuery}) async {
    try {
      final data = await mcpClient.get('/customers');
      var clients = (data['customers'] as List<dynamic>? ?? [])
          .map((e) => Client.fromErpNextCustomer(e as Map<String, dynamic>))
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
      final data = await mcpClient.get('/customers/${Uri.encodeComponent(id)}');
      final customer = data['customer'] as Map<String, dynamic>?;
      if (customer == null) {
        throw Exception('Client with id "$id" not found.');
      }
      return Client.fromErpNextCustomer(customer);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Client> create({required Client client}) async {
    try {
      final data = await mcpClient.post(
        '/customers',
        body: _toMcpBody(client),
      );
      final customer = data['customer'] as Map<String, dynamic>?;
      if (customer == null) {
        throw Exception('Customer create did not return customer data.');
      }
      return Client.fromErpNextCustomer(customer);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Future<Client> update({required Client client}) async {
    try {
      final data = await mcpClient.patch(
        '/customers/${Uri.encodeComponent(client.id)}',
        body: _toMcpBody(client),
      );
      final customer = data['customer'] as Map<String, dynamic>?;
      if (customer == null) {
        throw Exception('Customer update did not return customer data.');
      }
      return Client.fromErpNextCustomer(customer);
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }

  Map<String, dynamic> _toMcpBody(Client client) {
    return {
      'customer_name': client.fullName,
      if (client.phone != null) 'mobile_no': client.phone,
      if (client.email != null) 'email_id': client.email,
      if (client.idDocument != null) 'id_document': client.idDocument,
    };
  }
}
