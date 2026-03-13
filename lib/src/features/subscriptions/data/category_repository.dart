import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';

part 'category_repository.g.dart';

class CategoryRepository {
  final SupabaseClient _supabase;

  CategoryRepository(this._supabase);

  String? get _uid => _supabase.auth.currentUser?.id;

  Stream<List<Category>> watchCategories() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _supabase
        .from('categories')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at')
        .handleError((error) {
          // If JWT expired, try to refresh session manually
          if (error.toString().contains('InvalidJWTToken') ||
              error.toString().contains('expired')) {
            _supabase.auth.refreshSession();
          }
        })
        .asyncMap((rows) async {
          if (rows.isEmpty) {
            // Seed defaults on first use
            await _seedDefaults(uid);
            return Category.defaults('THB');
          }
          return rows.map(_rowToCategory).toList();
        });
  }

  Future<List<Category>> getAllCategories() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _supabase
        .from('categories')
        .select()
        .eq('user_id', uid)
        .order('created_at');

    if ((rows as List).isEmpty) {
      await _seedDefaults(uid);
      return Category.defaults('THB');
    }
    return rows.map((r) => _rowToCategory(r)).toList();
  }

  Future<void> _seedDefaults(String uid) async {
    final defaults = Category.defaults('THB');
    for (final cat in defaults) {
      await _supabase.from('categories').upsert({
        'id': cat.id,
        'user_id': uid,
        'name': cat.name,
        'icon_code': cat.iconCode,
        'color_value': cat.colorValue,
        'monthly_budget': cat.monthlyBudget,
        'currency': cat.currency,
      });
    }
  }

  Future<void> addCategory(Category category) async {
    final uid = _uid;
    if (uid == null) return;

    await _supabase.from('categories').upsert({
      'id': category.id,
      'user_id': uid,
      'name': category.name,
      'icon_code': category.iconCode,
      'color_value': category.colorValue,
      'monthly_budget': category.monthlyBudget,
      'currency': category.currency,
    });
  }

  Future<Category?> getCategory(String id) async {
    final rows = await _supabase
        .from('categories')
        .select()
        .eq('id', id)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return _rowToCategory(rows.first);
  }

  Future<void> deleteCategory(String id) async {
    await _supabase.from('categories').delete().eq('id', id);
  }

  Category _rowToCategory(Map<String, dynamic> r) {
    return Category(
      id: r['id'],
      name: r['name'],
      iconCode: r['icon_code'] ?? 0,
      colorValue: r['color_value'] ?? 0,
      monthlyBudget: (r['monthly_budget'] ?? 0).toDouble(),
      currency: r['currency'] ?? 'THB',
    );
  }
}

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) {
  return CategoryRepository(Supabase.instance.client);
}
