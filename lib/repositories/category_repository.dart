import '../core/mcp_client.dart';
import '../core/error_handler.dart';
import '../models/category.dart';

class CategoryRepository {
  /// Item Groups derived from ERPNext Items (read-only).
  Future<List<Category>> getAll() async {
    try {
      final data = await mcpClient.get('/categories');
      final categories = <Category>[];
      for (final row in data['categories'] as List<dynamic>? ?? []) {
        final map = row as Map<String, dynamic>;
        categories.add(Category(
          id: map['id'] as String,
          name: map['name'] as String,
          createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
        ));
      }
      return categories;
    } on McpApiException catch (e) {
      throw Exception(humanizeError(e.message));
    }
  }
}
