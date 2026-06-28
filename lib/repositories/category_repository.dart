import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/category.dart';

class CategoryRepository {
  /// Item Groups derived from ERPNext Items (read-only).
  Future<List<Category>> getAll() async {
    try {
      final data = await mcpClient.get('/items');
      final groups = <String>{};
      for (final row in data['items'] as List<dynamic>? ?? []) {
        final group = (row as Map<String, dynamic>)['item_group'] as String?;
        if (group != null && group.isNotEmpty) {
          groups.add(group);
        }
      }
      final now = DateTime.now();
      final categories = groups
          .map((name) => Category(id: name, name: name, createdAt: now))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return categories;
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }
}
