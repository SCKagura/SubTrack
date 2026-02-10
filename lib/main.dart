import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:subtrack/src/app.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/subscriptions/domain/family_member.dart';
import 'package:subtrack/src/features/subscriptions/domain/payment_record.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(FamilyMemberAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(PaymentRecordAdapter());
  Hive.registerAdapter(SubscriptionAdapter());
  Hive.registerAdapter(BillingCycleAdapter());

  // Open Boxes
  final subscriptionBox = await Hive.openBox<Subscription>('subscriptions');
  final paymentBox = await Hive.openBox<PaymentRecord>('payments');
  final categoryBox = await Hive.openBox<Category>('categories');

  // Create Repository
  final repository = SubscriptionRepository(
    subscriptionBox,
    paymentBox,
    () => FirebaseAuth.instance.currentUser?.uid,
  );
  final catRepo = CategoryRepository(categoryBox);

  runApp(
    ProviderScope(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(catRepo),
      ],
      child: const SubTrackApp(),
    ),
  );
}
