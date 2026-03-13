import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:subtrack/src/features/subscriptions/domain/payment_record.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';
import 'package:subtrack/src/features/subscriptions/domain/family_member.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/notifications/application/notification_service.dart';

part 'subscription_repository.g.dart';

class SubscriptionRepository {
  final SupabaseClient _supabase;

  SubscriptionRepository(this._supabase);

  String? get _uid => _supabase.auth.currentUser?.id;

  // ─── Subscriptions ───────────────────────────────────────────────

  Stream<List<Subscription>> watchSubscriptions() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _supabase
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at')
        .handleError((error) {
          debugPrint('Realtime Stream Error: $error');
          // If JWT expired, try to refresh session manually
          if (error.toString().contains('InvalidJWTToken') ||
              error.toString().contains('expired')) {
            _supabase.auth.refreshSession();
          }
        })
        .map((rows) {
          debugPrint('Realtime Subscriptions Count: ${rows.length}');
          return rows.map(_rowToSubscription).toList();
        });
  }

  Stream<List<Subscription>> watchSubscriptionsByFamilyMember(String memberId) {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _supabase
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at')
        .handleError((error) {
          debugPrint('Realtime Filtered Stream Error: $error');
          if (error.toString().contains('InvalidJWTToken') ||
              error.toString().contains('expired')) {
            _supabase.auth.refreshSession();
          }
        })
        .map((rows) => rows
            .where((r) => r['family_member_id'] == memberId)
            .map(_rowToSubscription)
            .toList());
  }

  Future<List<Subscription>> getAllSubscriptions() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _supabase
        .from('subscriptions')
        .select()
        .eq('user_id', uid)
        .order('created_at');
    return (rows as List).map((r) => _rowToSubscription(r)).toList();
  }

  Future<void> addSubscription(Subscription sub) async {
    final uid = _uid;
    if (uid == null) return;

    await _supabase.from('subscriptions').upsert({
      'id': sub.id,
      'user_id': uid,
      'category_id': sub.categoryId.isEmpty ? null : sub.categoryId,
      'name': sub.name,
      'price': sub.price,
      'currency': sub.currency,
      'cycle': sub.cycle.name,
      'first_payment_date': sub.firstPaymentDate.toIso8601String(),
      'next_payment_date': sub.nextPaymentDate.toIso8601String(),
      'status': sub.status,
      'family_member_id': sub.familyMemberId,
      'url': sub.url,
      'logo_url': sub.logoUrl,
      'is_free_trial': sub.isFreeTrial,
      'is_auto_renew': sub.isAutoRenew,
      'has_reminder': sub.hasReminder,
      'reminder_days_prior': sub.reminderDaysPrior,
      'termination_date': sub.terminationDate?.toIso8601String(),
    });

    // Schedule notification
    await NotificationService().scheduleSubscriptionReminder(sub);
  }

  Future<void> updateSubscription(Subscription sub) async {
    final uid = _uid;
    if (uid == null) return;

    await _supabase.from('subscriptions').upsert({
      'id': sub.id,
      'user_id': uid,
      'category_id': sub.categoryId.isEmpty ? null : sub.categoryId,
      'name': sub.name,
      'price': sub.price,
      'currency': sub.currency,
      'cycle': sub.cycle.name,
      'first_payment_date': sub.firstPaymentDate.toIso8601String(),
      'next_payment_date': sub.nextPaymentDate.toIso8601String(),
      'status': sub.status,
      'family_member_id': sub.familyMemberId,
      'url': sub.url,
      'logo_url': sub.logoUrl,
      'is_free_trial': sub.isFreeTrial,
      'is_auto_renew': sub.isAutoRenew,
      'has_reminder': sub.hasReminder,
      'reminder_days_prior': sub.reminderDaysPrior,
      'termination_date': sub.terminationDate?.toIso8601String(),
    });

    // Reschedule notification
    await NotificationService().scheduleSubscriptionReminder(sub);
  }

  Future<void> cancelSubscription(String id) async {
    await _supabase
        .from('subscriptions')
        .update({'status': 'Cancelled'})
        .eq('id', id);

    // Cancel notification if cancelled
    await NotificationService().cancelReminder(id);
  }

  Future<void> deleteSubscription(String id) async {
    // payment_history is cascade-deleted by DB constraint
    await _supabase.from('subscriptions').delete().eq('id', id);

    // Cancel notification
    await NotificationService().cancelReminder(id);
  }

  // ─── Family Members ───────────────────────────────────────────────

  Stream<List<FamilyMember>> watchFamilyMembers() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _supabase
        .from('family_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at')
        .handleError((error) {
          debugPrint('Realtime Family Members Error: $error');
          if (error.toString().contains('InvalidJWTToken') ||
              error.toString().contains('expired')) {
            _supabase.auth.refreshSession();
          }
        })
        .map(
          (rows) => rows
              .map(
                (r) => FamilyMember(
                  id: r['id'],
                  name: r['name'],
                  photoUrl: r['photo_url'] ?? '',
                  isCurrentUser: r['is_current_user'] ?? false,
                  email: r['email'],
                  status: r['status'] ?? 'pending',
                  linkedUserId: r['linked_user_id'],
                ),
              )
              .toList(),
        );
  }

  Future<void> addFamilyMember(FamilyMember member) async {
    final uid = _uid;
    if (uid == null) return;

    await _supabase.from('family_members').upsert({
      'id': member.id,
      'user_id': uid,
      'name': member.name,
      'photo_url': member.photoUrl,
      'is_current_user': member.isCurrentUser,
      'email': member.email,
      'status': member.status,
      'linked_user_id': member.linkedUserId,
    });
  }

  // Gets pending invites sent to the current user's email
  Stream<List<FamilyMember>> watchPendingRequests() {
    final email = _supabase.auth.currentUser?.email;
    if (email == null) return Stream.value([]);

    return _supabase
        .from('family_members')
        .stream(primaryKey: ['id'])
        .eq('email', email)
        .map(
          (rows) => rows
              .where((r) => r['status'] == 'pending')
              .map(
                (r) => FamilyMember(
                  id: r['id'],
                  name: r['name'],
                  photoUrl: r['photo_url'] ?? '',
                  isCurrentUser: r['is_current_user'] ?? false,
                  email: r['email'],
                  status: r['status'] ?? 'pending',
                  linkedUserId: r['linked_user_id'],
                ),
              )
              .toList(),
        );
  }

  // Accept a family request
  Future<void> acceptFamilyRequest(String memberId) async {
    final uid = _uid;
    if (uid == null) return;

    await _supabase.from('family_members').update({
      'status': 'accepted',
      'linked_user_id': uid,
    }).eq('id', memberId);
  }

  Future<void> deleteFamilyMember(String id) async {
    await _supabase.from('family_members').delete().eq('id', id);
  }

  Future<List<FamilyMember>> getAllFamilyMembers() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _supabase
        .from('family_members')
        .select()
        .eq('user_id', uid);
    return (rows as List)
        .map(
          (r) => FamilyMember(
            id: r['id'],
            name: r['name'],
            photoUrl: r['photo_url'] ?? '',
            isCurrentUser: r['is_current_user'] ?? false,
            email: r['email'],
            status: r['status'] ?? 'pending',
            linkedUserId: r['linked_user_id'],
          ),
        )
        .toList();
  }

  // ─── Shared Subscriptions ──────────────────────────────────────────

  // Gets subscriptions assigned to the current user by a family owner
  Stream<List<Subscription>> watchSharedSubscriptions() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    // The RLS policy "View shared subscriptions" automatically filters these
    // This query asks for subscriptions WHERE the family_member_id matches
    // a family_member row that is linked to our UID.
    return _supabase
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
            .where((r) => r['user_id'] != uid)
            .map(_rowToSubscription)
            .toList());
  }

  // ─── Payment History ──────────────────────────────────────────────

  Future<void> markAsPaid(
    String subscriptionId,
    double amount,
    DateTime paymentDate,
    DateTime nextPaymentDate,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    final record = PaymentRecord.create(
      subscriptionId: subscriptionId,
      amount: amount,
      date: paymentDate,
      status: 'Paid',
      userId: uid,
    );

    await _supabase.from('payment_history').insert({
      'id': record.id,
      'subscription_id': subscriptionId,
      'user_id': uid,
      'amount': amount,
      'date': paymentDate.toIso8601String(),
      'status': 'Paid',
    });

    await _supabase
        .from('subscriptions')
        .update({'next_payment_date': nextPaymentDate.toIso8601String()})
        .eq('id', subscriptionId);

    // Reschedule notification for next cycle
    try {
      final rows = await _supabase
          .from('subscriptions')
          .select()
          .eq('id', subscriptionId);
      if (rows.isNotEmpty) {
        final sub = _rowToSubscription(rows.first);
        await NotificationService().scheduleSubscriptionReminder(sub);
      }
    } catch (_) {}
  }

  Future<void> skipPayment(
    String subscriptionId,
    DateTime skippedDate,
    DateTime nextPaymentDate,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    final record = PaymentRecord.create(
      subscriptionId: subscriptionId,
      amount: 0,
      date: skippedDate,
      status: 'Skipped',
      userId: uid,
    );

    await _supabase.from('payment_history').insert({
      'id': record.id,
      'subscription_id': subscriptionId,
      'user_id': uid,
      'amount': 0,
      'date': skippedDate.toIso8601String(),
      'status': 'Skipped',
    });

    await _supabase
        .from('subscriptions')
        .update({'next_payment_date': nextPaymentDate.toIso8601String()})
        .eq('id', subscriptionId);

    // Reschedule notification for next cycle
    try {
      final rows = await _supabase
          .from('subscriptions')
          .select()
          .eq('id', subscriptionId);
      if (rows.isNotEmpty) {
        final sub = _rowToSubscription(rows.first);
        await NotificationService().scheduleSubscriptionReminder(sub);
      }
    } catch (_) {}
  }

  Stream<List<PaymentRecord>> watchHistory(String subscriptionId) {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _supabase
        .from('payment_history')
        .stream(primaryKey: ['id'])
        .eq('subscription_id', subscriptionId)
        .order('date', ascending: false)
        .map((rows) => rows.map((r) => _rowToPaymentRecord(r)).toList());
  }

  Future<List<PaymentRecord>> getHistory(String subscriptionId) async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _supabase
        .from('payment_history')
        .select()
        .eq('subscription_id', subscriptionId)
        .eq('user_id', uid)
        .order('date', ascending: false);
    return (rows as List).map((r) => _rowToPaymentRecord(r)).toList();
  }

  Stream<Map<String, dynamic>> watchTotalLifetimeSpending() {
    final uid = _uid;
    if (uid == null) return Stream.value({'total': 0.0, 'count': 0});

    return _supabase
        .from('payment_history')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((rows) {
      double total = 0;
      int count = 0;
      for (final row in rows) {
        if (row['status'] == 'Paid') {
          total += (row['amount'] ?? 0).toDouble();
          count++;
        }
      }
      return {'total': total, 'count': count};
    });
  }

  Future<void> purgeMockData() async {
    final uid = _uid;
    if (uid == null) return;
    final mockNames = [
      'Netflix',
      'Spotify Family',
      'iCloud+ 50GB',
      'Adobe Creative Cloud',
      'Amazon Prime',
      'Disney+ Hotstar',
      'YouTube Premium',
      'ChatGPT Plus',
      'GitHub Copilot',
      'Google One 2TB',
      'PlayStation Plus',
    ];

    try {
      final rows = await _supabase
          .from('subscriptions')
          .select('id, name')
          .eq('user_id', uid);
      final idsToDelete = (rows as List)
          .where((r) => mockNames.contains(r['name']))
          .map((r) => r['id'].toString())
          .toList();

      if (idsToDelete.isEmpty) return;

      // Chunk deletions to prevent socket stream overload / App Freezing
      const chunkSize = 50;
      for (var i = 0; i < idsToDelete.length; i += chunkSize) {
        final chunk = idsToDelete.skip(i).take(chunkSize).toList();
        
        await _supabase.from('subscriptions').delete().inFilter('id', chunk);
        
        for (final id in chunk) {
          await NotificationService().cancelReminder(id);
        }
      }
    } catch (e) {
      debugPrint('Error purging mocks: $e');
    }
  }

  // ─── Seeding With Logos ───────────────────────────────────────────

  Future<void> seedSampleSubscriptionsWithLogos(List<Category> categories) async {
    final uid = _uid;
    if (uid == null || categories.isEmpty) return;

    final now = DateTime.now();
    final subscriptions = [
      Subscription.create(
        name: 'Netflix',
        categoryId: categories
            .firstWhere(
              (c) =>
                  c.name.contains('Entertainment') ||
                  c.name.contains('บันเทิง'),
              orElse: () => categories.first,
            )
            .id,
        price: 419,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 45)),
        url: 'https://netflix.com',
        logoUrl: 'https://icon.horse/icon/netflix.com',
      ).copyWith(nextPaymentDate: now.add(const Duration(days: 15))),
      Subscription.create(
        name: 'Spotify Family',
        categoryId: categories
            .firstWhere(
              (c) => c.name.contains('Music') || c.name.contains('เพลง'),
              orElse: () => categories.first,
            )
            .id,
        price: 209,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 60)),
        url: 'https://spotify.com',
        logoUrl: 'https://icon.horse/icon/spotify.com',
      ).copyWith(nextPaymentDate: now.add(const Duration(days: 30))),
      Subscription.create(
        name: 'iCloud+ 50GB',
        categoryId: categories
            .firstWhere(
              (c) => c.name.contains('App') || c.name.contains('แอป'),
              orElse: () => categories.first,
            )
            .id,
        price: 35,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 10)),
        url: 'https://icloud.com',
        logoUrl: 'https://icon.horse/icon/icloud.com',
      ).copyWith(nextPaymentDate: now.add(const Duration(days: 20))),
      Subscription.create(
        name: 'Adobe Creative Cloud',
        categoryId: categories
            .firstWhere(
              (c) => c.name.contains('Design') || c.name.contains('ทำงาน'),
              orElse: () => categories.first,
            )
            .id,
        price: 1888,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 5)),
        url: 'https://adobe.com',
        logoUrl: 'https://icon.horse/icon/adobe.com',
      ).copyWith(nextPaymentDate: now.add(const Duration(days: 25))),
      Subscription.create(
        name: 'Amazon Prime',
        categoryId: categories
            .firstWhere(
              (c) => c.name.contains('Shopping') || c.name.contains('ช้อปปิ้ง'),
              orElse: () => categories.first,
            )
            .id,
        price: 149,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 90)),
        url: 'https://amazon.com',
        logoUrl: 'https://icon.horse/icon/amazon.com',
      ).copyWith(
        nextPaymentDate: now.subtract(const Duration(days: 60)),
        status: 'Active',
      ),
      Subscription.create(
        name: 'Disney+ Hotstar',
        categoryId: categories
            .firstWhere(
              (c) =>
                  c.name.contains('Entertainment') ||
                  c.name.contains('บันเทิง'),
              orElse: () => categories.first,
            )
            .id,
        price: 99,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 365)),
        url: 'https://disneyplus.com',
        logoUrl: 'https://icon.horse/icon/disneyplus.com',
      ),
      Subscription.create(
        name: 'YouTube Premium',
        categoryId: categories
            .firstWhere(
              (c) =>
                  c.name.contains('Entertainment') ||
                  c.name.contains('บันเทิง'),
              orElse: () => categories.first,
            )
            .id,
        price: 159,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 400)),
        url: 'https://youtube.com',
        logoUrl: 'https://icon.horse/icon/youtube.com',
      ),
      Subscription.create(
        name: 'ChatGPT Plus',
        categoryId: categories
            .firstWhere(
              (c) => c.name.contains('ทำงาน') || c.name.contains('ซอฟต์แวร์'),
              orElse: () => categories.first,
            )
            .id,
        price: 700,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 180)),
        url: 'https://chatgpt.com',
        logoUrl: 'https://icon.horse/icon/chatgpt.com',
      ),
      Subscription.create(
        name: 'GitHub Copilot',
        categoryId: categories
            .firstWhere(
              (c) => c.name.contains('ทำงาน') || c.name.contains('ซอฟต์แวร์'),
              orElse: () => categories.first,
            )
            .id,
        price: 350,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 500)),
        url: 'https://github.com',
        logoUrl: 'https://icon.horse/icon/github.com',
      ),
      Subscription.create(
        name: 'Google One 2TB',
        categoryId: categories
            .firstWhere(
              (c) => c.name.contains('ทำงาน') || c.name.contains('ซอฟต์แวร์'),
              orElse: () => categories.first,
            )
            .id,
        price: 350,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 600)),
        url: 'https://google.com',
        logoUrl: 'https://icon.horse/icon/google.com',
      ),
      Subscription.create(
        name: 'PlayStation Plus',
        categoryId: categories
            .firstWhere(
              (c) =>
                  c.name.contains('Entertainment') ||
                  c.name.contains('บันเทิง'),
              orElse: () => categories.first,
            )
            .id,
        price: 210,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 700)),
        url: 'https://playstation.com',
        logoUrl: 'https://icon.horse/icon/playstation.com',
      ),
      // --- New Diverse Mock Data ---
      Subscription.create(
        name: 'Netflix (Paused)',
        categoryId: categories
            .firstWhere(
              (c) =>
                  c.name.contains('บันเทิง') ||
                  c.name.contains('สตรีมมิ่ง'),
              orElse: () => categories.first,
            )
            .id,
        price: 419,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 45)),
        url: 'https://netflix.com',
        logoUrl: 'https://icon.horse/icon/netflix.com',
      ).copyWith(status: 'Paused'),
      Subscription.create(
        name: 'HBO Go (Cancelled)',
        categoryId: categories
            .firstWhere(
              (c) =>
                  c.name.contains('บันเทิง') ||
                  c.name.contains('สตรีมมิ่ง'),
              orElse: () => categories.first,
            )
            .id,
        price: 199,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 60)),
        url: 'https://hbogo.co.th',
        logoUrl: 'https://icon.horse/icon/hbogo.co.th',
      ).copyWith(status: 'Cancelled'),
      Subscription.create(
        name: 'Private Service (No Alert)',
        categoryId: categories.first.id,
        price: 500,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.add(const Duration(days: 2)),
        hasReminder: false,
      ),
      Subscription.create(
        name: 'Youtube Premium (Ended)',
        categoryId: categories
            .firstWhere(
              (c) =>
                  c.name.contains('บันเทิง') ||
                  c.name.contains('สตรีมมิ่ง'),
              orElse: () => categories.first,
            )
            .id,
        price: 159,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 400)),
        url: 'https://youtube.com',
        logoUrl: 'https://icon.horse/icon/youtube.com',
      ).copyWith(terminationDate: now.subtract(const Duration(days: 30))),
      Subscription.create(
        name: 'Disney+ (Ending Soon)',
        categoryId: categories
            .firstWhere(
              (c) =>
                  c.name.contains('บันเทิง') ||
                  c.name.contains('สตรีมมิ่ง'),
              orElse: () => categories.first,
            )
            .id,
        price: 99,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 360)),
        url: 'https://disneyplus.com',
        logoUrl: 'https://icon.horse/icon/disneyplus.com',
      ).copyWith(terminationDate: now.add(const Duration(days: 15))),
      Subscription.create(
        name: 'iCloud (Skipped Demo)',
        categoryId: categories.first.id,
        price: 35,
        currency: 'THB',
        cycle: BillingCycle.monthly,
        firstPaymentDate: now.subtract(const Duration(days: 180)),
      ),
    ];

    for (final sub in subscriptions) {
      await addSubscription(sub);
      await _seedPaymentHistory(sub, uid);
    }
  }

  Future<void> _seedPaymentHistory(Subscription sub, String uid) async {
    // Seed up to 24 months of history
    for (int i = 0; i < 24; i++) {
      final date = sub.firstPaymentDate.add(Duration(days: i * 30));
      if (date.isAfter(DateTime.now())) break;
      if (sub.terminationDate != null && date.isAfter(sub.terminationDate!)) {
        break;
      }

      // Randomly skip some payments for demonstration
      final isSkipped = sub.name.contains('Skipped') || (i % 5 == 0 && i > 0);
      final status = isSkipped ? 'Skipped' : 'Paid';

      final record = PaymentRecord.create(
        subscriptionId: sub.id,
        amount: sub.price,
        date: date,
        status: status,
        userId: uid,
      );

      await _supabase.from('payment_history').insert({
        'id': record.id,
        'subscription_id': sub.id,
        'user_id': uid,
        'amount': sub.price,
        'date': date.toIso8601String(),
        'status': status,
      });
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  Subscription _rowToSubscription(Map<String, dynamic> r) {
    return Subscription(
      id: r['id'],
      name: r['name'],
      categoryId: r['category_id'] ?? '',
      price: (r['price'] ?? 0).toDouble(),
      currency: r['currency'] ?? 'THB',
      cycle: BillingCycle.values.firstWhere(
        (c) => c.name == r['cycle'],
        orElse: () => BillingCycle.monthly,
      ),
      firstPaymentDate: DateTime.parse(r['first_payment_date']),
      nextPaymentDate: DateTime.parse(r['next_payment_date']),
      status: r['status'] ?? 'Active',
      familyMemberId: r['family_member_id'],
      url: r['url'],
      logoUrl: r['logo_url'],
      isFreeTrial: r['is_free_trial'] ?? false,
      isAutoRenew: r['is_auto_renew'] ?? true,
      hasReminder: r['has_reminder'] ?? true,
      reminderDaysPrior: r['reminder_days_prior'] ?? 1,
      terminationDate: r['termination_date'] != null
          ? DateTime.parse(r['termination_date'])
          : null,
    );
  }

  PaymentRecord _rowToPaymentRecord(Map<String, dynamic> r) {
    return PaymentRecord(
      id: r['id'],
      subscriptionId: r['subscription_id'],
      amount: (r['amount'] ?? 0).toDouble(),
      date: DateTime.parse(r['date']),
      status: r['status'] ?? 'Paid',
      userId: r['user_id'] ?? '',
    );
  }
}

@Riverpod(keepAlive: true)
SubscriptionRepository subscriptionRepository(Ref ref) {
  return SubscriptionRepository(Supabase.instance.client);
}

@riverpod
Stream<Map<String, dynamic>> lifetimeSpending(Ref ref) {
  return ref.watch(subscriptionRepositoryProvider).watchTotalLifetimeSpending();
}
