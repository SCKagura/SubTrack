import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/authentication/data/auth_repository.dart';
import 'package:subtrack/src/features/authentication/domain/user_profile.dart';
import 'package:subtrack/src/features/subscriptions/domain/family_member.dart';

part 'user_profile_repository.g.dart';

class UserProfileRepository {
  final FirebaseFirestore _firestore;

  UserProfileRepository(this._firestore);

  Future<void> ensureUserInitialized(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await _initializeNewUser(user, userDoc);
    }
  }

  Future<void> _initializeNewUser(User user, DocumentReference userDoc) async {
    // 1. Create Default Family Member (The User)
    final me = FamilyMember.create(
      name: user.displayName ?? 'Me',
      photoUrl: user.photoURL ?? '',
      isCurrentUser: true,
    );

    // 2. Create Default Categories
    final defaults = Category.defaults(
      'THB',
    ); // Default currency, configurable later

    // Batch write for atomicity
    final batch = _firestore.batch();

    // Set User Profile (Root Doc)
    batch.set(userDoc, {
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'defaultMemberId': me.id,
    });

    // Add Family Member
    final membersCollection = userDoc.collection('family_members');
    batch.set(membersCollection.doc(me.id), {
      'id': me.id,
      'name': me.name,
      'photoUrl': me.photoUrl,
      'isCurrentUser': true,
    });

    // Add Categories
    final categoriesCollection = userDoc.collection('categories');
    for (final category in defaults) {
      batch.set(categoriesCollection.doc(category.id), {
        'id': category.id,
        'name': category.name,
        'iconCode': category.iconCode,
        'colorValue': category.colorValue,
        'monthlyBudget': category.monthlyBudget,
        'currency': category.currency,
      });
    }
    await batch.commit();
  }

  Stream<UserProfile> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        // Return dummy or throw? Let's return a basic one.
        return UserProfile(
          uid: uid,
          email: '',
          displayName: 'User',
          currency: 'THB',
        );
      }
      return UserProfile.fromMap(uid, snapshot.data()!);
    });
  }

  Future<void> updateDisplayName(String uid, String name) async {
    await _firestore.collection('users').doc(uid).update({'displayName': name});
  }

  Future<void> updateCurrency(String uid, String currency) async {
    await _firestore.collection('users').doc(uid).update({
      'currency': currency,
    });
  }
}

@Riverpod(keepAlive: true)
UserProfileRepository userProfileRepository(UserProfileRepositoryRef ref) {
  return UserProfileRepository(FirebaseFirestore.instance);
}

@riverpod
Stream<UserProfile> userProfile(UserProfileRef ref) {
  final authState = ref.watch(authStateProvider); // Need to import this
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref
          .watch(userProfileRepositoryProvider)
          .watchUserProfile(user.uid);
    },
    error: (_, __) => const Stream.empty(),
    loading: () => const Stream.empty(),
  );
}
