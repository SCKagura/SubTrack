import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:subtrack/src/features/authentication/data/auth_repository.dart';
import 'package:subtrack/src/features/authentication/domain/user_profile.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/subscriptions/domain/family_member.dart';

part 'user_profile_repository.g.dart';

class UserProfileRepository {
  final SupabaseClient _supabase;

  UserProfileRepository(this._supabase);

  /// Called after sign-in to seed categories/family member if first login
  Future<void> ensureUserInitialized(User user) async {
    // Check if categories exist (proxy for "initialized")
    final existing = await _supabase
        .from('categories')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);

    if ((existing as List).isEmpty) {
      await _initializeNewUser(user);
    }
  }

  Future<void> _initializeNewUser(User user) async {
    // 1. Upsert profile (trigger may have already created it)
    await _supabase.from('profiles').upsert({
      'id': user.id,
      'email': user.email ?? '',
      'display_name': user.userMetadata?['full_name'],
      'photo_url': user.userMetadata?['avatar_url'],
      'currency': 'THB',
      'monthly_budget': 0.0,
    });

    // 2. Seed default categories
    final defaults = Category.defaults('THB');
    for (final cat in defaults) {
      await _supabase.from('categories').upsert({
        'id': cat.id,
        'user_id': user.id,
        'name': cat.name,
        'icon_code': cat.iconCode,
        'color_value': cat.colorValue,
        'monthly_budget': cat.monthlyBudget,
        'currency': cat.currency,
      });
    }

    // 3. Create default family member (Me)
    final me = FamilyMember.create(
      name:
          user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? 'Me',
      photoUrl: user.userMetadata?['avatar_url'] ?? '',
      isCurrentUser: true,
    );
    await _supabase.from('family_members').upsert({
      'id': me.id,
      'user_id': user.id,
      'name': me.name,
      'photo_url': me.photoUrl,
      'is_current_user': true,
    });
  }

  Stream<UserProfile> watchUserProfile(String uid) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .handleError((error) {
          debugPrint('Realtime User Profile Error: $error');
          if (error.toString().contains('InvalidJWTToken') ||
              error.toString().contains('expired')) {
            _supabase.auth.refreshSession();
          }
        })
        .map((rows) {
          if (rows.isEmpty) {
            return UserProfile(uid: uid, email: '', currency: 'THB');
          }
          final row = rows.first;
          return UserProfile(
            uid: uid,
            email: row['email'] ?? '',
            displayName: row['display_name'],
            photoUrl: row['photo_url'],
            currency: row['currency'] ?? 'THB',
            monthlyBudget: (row['monthly_budget'] ?? 0).toDouble(),
          );
        });
  }

  Future<void> updateDisplayName(String uid, String name) async {
    await _supabase
        .from('profiles')
        .update({'display_name': name})
        .eq('id', uid);
  }

  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    await _supabase
        .from('profiles')
        .update({'photo_url': photoUrl})
        .eq('id', uid);
  }

  Future<void> updateCurrency(String uid, String currency) async {
    await _supabase
        .from('profiles')
        .update({'currency': currency})
        .eq('id', uid);
  }

  Future<void> updateMonthlyBudget(String uid, double budget) async {
    await _supabase
        .from('profiles')
        .update({'monthly_budget': budget})
        .eq('id', uid);
  }
}

@Riverpod(keepAlive: true)
UserProfileRepository userProfileRepository(Ref ref) {
  return UserProfileRepository(Supabase.instance.client);
}

@riverpod
Stream<UserProfile> userProfile(Ref ref) {
  final authStateAsync = ref.watch(authStateProvider);
  return authStateAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(userProfileRepositoryProvider).watchUserProfile(user.id);
    },
    error: (_, __) => const Stream.empty(),
    loading: () => const Stream.empty(),
  );
}
