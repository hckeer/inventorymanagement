import '../core/supabase_client.dart';
import '../core/constants.dart';
import '../models/category.dart';

class CategoryRepository {
  /// Returns all categories ordered by name.
  Future<List<Category>> getAll() async {
    final data = await supabase
        .from(kTableCategories)
        .select()
        .order('name', ascending: true);
    return List<Category>.from(
      (data as List).map((e) => Category.fromJson(e as Map<String, dynamic>)),
    );
  }

  /// Inserts a new category and returns the created row.
  Future<Category> create({required String name}) async {
    final data = await supabase
        .from(kTableCategories)
        .insert({'name': name})
        .select()
        .single();
    return Category.fromJson(data as Map<String, dynamic>);
  }

  /// Updates an existing category and returns the updated row.
  Future<Category> update({required String id, required String name}) async {
    final data = await supabase
        .from(kTableCategories)
        .update({'name': name})
        .eq('id', id)
        .select()
        .single();
    return Category.fromJson(data as Map<String, dynamic>);
  }

  /// Deletes the category with the given id.
  Future<void> delete({required String id}) async {
    await supabase.from(kTableCategories).delete().eq('id', id);
  }
}
