import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/category_repository.dart';
import '../models/category.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(),
);

final categoryListProvider =
    AsyncNotifierProvider<CategoryListNotifier, List<Category>>(
  CategoryListNotifier.new,
);

class CategoryListNotifier extends AsyncNotifier<List<Category>> {
  CategoryRepository get _repo => ref.read(categoryRepositoryProvider);

  @override
  Future<List<Category>> build() async {
    return _repo.getAll();
  }

  /// Creates a category and refreshes the list.
  Future<void> create(String name) async {
    try {
      await _repo.create(name: name);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Updates an existing category and refreshes the list.
  Future<void> updateCategory(String id, String name) async {
    try {
      await _repo.update(id: id, name: name);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Deletes a category and refreshes the list.
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
