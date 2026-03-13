import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:subtrack/src/features/authentication/data/user_profile_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Stream<AuthState> authStateChanges() => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  /// Sign in with email + password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email + password
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  /// Sign in with Google OAuth (opens browser)
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.example.subtrack2://login-callback/',
      queryParams: {'prompt': 'select_account'},
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(Supabase.instance.client);
}

@riverpod
Stream<User?> authState(Ref ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges().asyncMap((authState) async {
    final event = authState.event;
    final session = authState.session;
    final user = session?.user;

    if (user != null && event == AuthChangeEvent.signedIn) {
      await ref.read(userProfileRepositoryProvider).ensureUserInitialized(user);
    }

    // When session tokens change, the existing Realtime stream channels (Postgres Changes)
    // still hold the old expired token and will eventually throw RealtimeSubscribeException.
    // Invalidating the repository providers forces Riverpod to recreate them,
    // ensuring the next .stream() call uses the Supabase client with the fresh token.
    if (event == AuthChangeEvent.tokenRefreshed ||
        event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.userUpdated) {
      ref.invalidate(subscriptionRepositoryProvider);
      ref.invalidate(categoryRepositoryProvider);
    }

    return user;
  });
}
