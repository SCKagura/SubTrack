import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';

class DashboardLogic {
  static List<Subscription> getActiveSubscriptions(List<Subscription> subscriptions) {
    return subscriptions
        .where((s) => s.status.toLowerCase() != 'cancelled')
        .toList();
  }

  static double calculateTotalMonthlySpending(List<Subscription> activeSubscriptions) {
    double total = 0;
    for (final sub in activeSubscriptions) {
      double monthlyPrice = sub.price;
      if (sub.cycle == BillingCycle.weekly) monthlyPrice *= 4;
      if (sub.cycle == BillingCycle.yearly) monthlyPrice /= 12;
      total += monthlyPrice;
    }
    return total;
  }

  static Map<String, double> calculateCategorySpending(List<Subscription> activeSubscriptions) {
    final spending = <String, double>{};
    for (final sub in activeSubscriptions) {
      double monthlyPrice = sub.price;
      if (sub.cycle == BillingCycle.weekly) monthlyPrice *= 4;
      if (sub.cycle == BillingCycle.yearly) monthlyPrice /= 12;
      spending[sub.categoryId] = (spending[sub.categoryId] ?? 0) + monthlyPrice;
    }
    return spending;
  }

  static double calculateTotalBudget(double userBudget, List<Category> categories) {
    double totalBudget = userBudget;
    if (totalBudget == 0) {
      for (var cat in categories) {
        totalBudget += cat.monthlyBudget;
      }
    }
    return totalBudget;
  }

  static List<Subscription> getUpcomingSubscriptions(
    List<Subscription> activeSubscriptions,
    DateTime today,
  ) {
    final upcoming = activeSubscriptions
        .where((s) => !s.nextPaymentDate.isBefore(today))
        .toList()
      ..sort((a, b) => a.nextPaymentDate.compareTo(b.nextPaymentDate));
    return upcoming;
  }
}
