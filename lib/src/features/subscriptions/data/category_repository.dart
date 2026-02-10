import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';

part 'category_repository.g.dart';

class CategoryRepository {
  final Box<Category> _box;

  CategoryRepository(this._box);

  List<Category> getAllCategories() {
    if (_box.isEmpty) {
      // Seed defaults if empty (Offline-first approach)
      final defaults = Category.defaults('THB');
      for (var c in defaults) {
        _box.put(c.id, c);
      }
    }
    return _box.values.toList();
  }

  Stream<List<Category>> watchCategories() async* {
    yield getAllCategories();
    await for (final _ in _box.watch()) {
      yield getAllCategories();
    }
  }

  Future<void> addCategory(Category category) async {
    await _box.put(category.id, category);
  }

  Future<void> deleteCategory(String id) async {
    await _box.delete(id);
  }
}

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(CategoryRepositoryRef ref) {
  throw UnimplementedError('Initialize in main.dart');
}
