import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtrack/src/features/subscriptions/application/dashboard_logic.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';

void main() {
  group('DashboardLogic', () {
    final today = DateTime(2026, 3, 9);

    final sub1 = Subscription.create(
      name: 'Netflix',
      categoryId: 'cat1',
      price: 400,
      cycle: BillingCycle.monthly,
      firstPaymentDate: DateTime(2026, 3, 5),
    ).copyWith(status: 'Active', nextPaymentDate: DateTime(2026, 4, 5));

    final sub2 = Subscription.create(
      name: 'Spotify Family',
      categoryId: 'cat2',
      price: 1500,
      cycle: BillingCycle.yearly, // yearly: 1500/12 = 125/month
      firstPaymentDate: DateTime(2025, 12, 1),
    ).copyWith(status: 'Active', nextPaymentDate: DateTime(2026, 12, 1));

    final sub3 = Subscription.create(
      name: 'Weekly Magazine',
      categoryId: 'cat3',
      price: 50,
      cycle: BillingCycle.weekly, // weekly: 50*4 = 200/month
      firstPaymentDate: DateTime(2026, 3, 1),
    ).copyWith(status: 'Active', nextPaymentDate: DateTime(2026, 3, 10));

    final cancelledSub = Subscription.create(
      name: 'Old Service',
      categoryId: 'cat1',
      price: 1000,
      cycle: BillingCycle.monthly,
      firstPaymentDate: DateTime(2025, 1, 1),
    ).copyWith(status: 'Cancelled', nextPaymentDate: DateTime(2025, 2, 1));

    final allSubs = [sub1, sub2, sub3, cancelledSub];

    test('getActiveSubscriptions should filter out cancelled subscriptions', () {
      final active = DashboardLogic.getActiveSubscriptions(allSubs);
      expect(active.length, 3);
      expect(active.any((s) => s.status == 'Cancelled'), isFalse);
    });

    test('calculateTotalMonthlySpending should correctly calculate monthly cost based on cycle', () {
      final active = DashboardLogic.getActiveSubscriptions(allSubs);
      final total = DashboardLogic.calculateTotalMonthlySpending(active);
      // 400 (monthly) + 125 (yearly) + 200 (weekly) = 725
      expect(total, 725);
    });

    test('calculateCategorySpending should group spending by category id', () {
      final subExtra = Subscription.create(
        name: 'Extra',
        categoryId: 'cat1',
        price: 100,
        cycle: BillingCycle.monthly,
        firstPaymentDate: today,
      ).copyWith(status: 'Active', nextPaymentDate: today);

      final active = [...DashboardLogic.getActiveSubscriptions(allSubs), subExtra];
      final spending = DashboardLogic.calculateCategorySpending(active);

      expect(spending['cat1'], 500); // 400 + 100
      expect(spending['cat2'], 125); // 1500 / 12
      expect(spending['cat3'], 200); // 50 * 4
    });

    test('calculateTotalBudget returns user budget if > 0', () {
      final total = DashboardLogic.calculateTotalBudget(1000, []);
      expect(total, 1000);
    });

    test('calculateTotalBudget calculates from categories if user budget is 0', () {
      final categories = [
        Category.create(name: 'Cat1', icon: Icons.home, color: Colors.red, monthlyBudget: 300),
        Category.create(name: 'Cat2', icon: Icons.movie, color: Colors.blue, monthlyBudget: 200),
      ];
      final total = DashboardLogic.calculateTotalBudget(0, categories);
      expect(total, 500);
    });

    test('getUpcomingSubscriptions filters past dates and sorts correctly', () {
      final active = DashboardLogic.getActiveSubscriptions(allSubs);
      
      // sub3: 2026-03-10
      // sub1: 2026-04-05
      // sub2: 2026-12-01
      final upcoming = DashboardLogic.getUpcomingSubscriptions(active, today);
      
      expect(upcoming.length, 3);
      expect(upcoming[0].name, 'Weekly Magazine');
      expect(upcoming[1].name, 'Netflix');
      expect(upcoming[2].name, 'Spotify Family');
    });

    test('getUpcomingSubscriptions excludes dates before today', () {
      final subPast = Subscription.create(
        name: 'Past',
        categoryId: 'cat1',
        price: 100,
        cycle: BillingCycle.monthly,
        firstPaymentDate: DateTime(2026, 1, 1),
      ).copyWith(status: 'Active', nextPaymentDate: DateTime(2026, 3, 1)); // Before 2026-03-09

      final active = [...DashboardLogic.getActiveSubscriptions(allSubs), subPast];
      final upcoming = DashboardLogic.getUpcomingSubscriptions(active, today);
      
      expect(upcoming.length, 3);
      expect(upcoming.any((s) => s.name == 'Past'), isFalse);
    });
  });
}
