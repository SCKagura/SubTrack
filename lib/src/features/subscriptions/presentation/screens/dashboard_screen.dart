import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/src/features/authentication/data/user_profile_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subRepo = ref.watch(subscriptionRepositoryProvider);
    final catRepo = ref.watch(categoryRepositoryProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    final currency = userProfileAsync.value?.currency ?? 'THB';
    final currencySymbol = _getCurrencySymbol(currency);

    return StreamBuilder<List<Category>>(
      stream: catRepo.watchCategories(),
      builder: (context, catSnapshot) {
        if (!catSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = catSnapshot.data!;

        return StreamBuilder<List<Subscription>>(
          stream: subRepo.watchSubscriptions(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final subs = snapshot.data!;

            // กรองเอาเฉพาะรายการที่ "ยังไม่ยกเลิก" มาคำนวณ
            // รายการที่ Cancelled จะไม่ถูกนับรวมในยอดเงิน (Ghost)
            final activeSubs = subs
                .where((s) => s.status.toLowerCase() != 'cancelled')
                .toList();

            // --- Calculations (คำนวณยอดเงิน) ---
            double totalMonthlySpending = 0;
            final categorySpending = <String, double>{};

            for (final sub in activeSubs) {
              double monthlyPrice = sub.price;

              // ปรับราคาให้เป็นฐาน "รายเดือน" (Normalization)
              if (sub.cycle == BillingCycle.weekly)
                monthlyPrice *= 4; // รายสัปดาห์ * 4
              if (sub.cycle == BillingCycle.yearly)
                monthlyPrice /= 12; // รายปี / 12

              totalMonthlySpending += monthlyPrice;

              // บวกยอดแยกตามหมวดหมู่
              categorySpending[sub.categoryId] =
                  (categorySpending[sub.categoryId] ?? 0) + monthlyPrice;
            }

            double totalBudget = 0;
            for (var cat in categories) {
              totalBudget += cat.monthlyBudget;
            }

            // Top Category
            String topCategoryName = 'None';
            double topCategoryAmount = 0;
            if (categorySpending.isNotEmpty) {
              final sortedEntries = categorySpending.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)); // Max to Min
              final topEntry = sortedEntries.first;
              final cat = categories.firstWhere(
                (c) => c.id == topEntry.key,
                orElse: () => Category(
                  id: 'unknown',
                  name: 'Unknown',
                  iconCode: Icons.help.codePoint,
                  colorValue: Colors.grey.toARGB32(),
                  monthlyBudget: 0,
                  currency: currency,
                ),
              );
              topCategoryName = cat.name;
              topCategoryAmount = topEntry.value;
            }

            // Next Renewal
            Subscription? nextRenewalSub;
            int daysUntilRenewal = 999;

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            // Find closest due date
            if (activeSubs.isNotEmpty) {
              final sortedSubs = List<Subscription>.from(activeSubs);
              sortedSubs.sort(
                (a, b) => a.nextPaymentDate.compareTo(b.nextPaymentDate),
              );
              nextRenewalSub = sortedSubs.firstWhere(
                (s) => !s.nextPaymentDate.isBefore(today),
                orElse: () => sortedSubs.first,
              );
              daysUntilRenewal = nextRenewalSub.nextPaymentDate
                  .difference(today)
                  .inDays;
            }

            // Upcoming list (Next 3)
            final upcomingSubs =
                activeSubs
                    .where((s) => !s.nextPaymentDate.isBefore(today))
                    .toList()
                  ..sort(
                    (a, b) => a.nextPaymentDate.compareTo(b.nextPaymentDate),
                  );
            final topUpcoming = upcomingSubs.take(3).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  userProfileAsync.when(
                    data: (profile) => Text(
                      'Welcome back, ${profile.displayName ?? 'User'}!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const Text('Welcome back!'),
                  ),
                  const Text(
                    "Here's your subscription overview",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Summary Grid (Wrapped)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final itemWidth = (width - 16) / 2; // 16 gap
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildSummaryCard(
                            context,
                            width: itemWidth,
                            title: 'Monthly Spending',
                            value:
                                '$currencySymbol${totalMonthlySpending.toStringAsFixed(0)}',
                            icon: Icons.attach_money,
                            color: Colors.greenAccent,
                          ),
                          _buildSummaryCard(
                            context,
                            width: itemWidth,
                            title: 'Active Subs',
                            value: '${activeSubs.length}',
                            icon: Icons.subscriptions,
                            color: Colors.blueAccent,
                          ),
                          _buildSummaryCard(
                            context,
                            width: itemWidth,
                            title: 'Top Category',
                            value: topCategoryName,
                            subtitle:
                                '$currencySymbol${topCategoryAmount.toStringAsFixed(0)}',
                            icon: Icons.bar_chart,
                            color: Colors.purpleAccent,
                          ),
                          _buildSummaryCard(
                            context,
                            width: itemWidth,
                            title: 'Next Renewal',
                            value: nextRenewalSub != null
                                ? 'in $daysUntilRenewal days'
                                : 'N/A',
                            subtitle: nextRenewalSub?.name ?? '-',
                            icon: Icons.calendar_today,
                            color: Colors.orangeAccent,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Monthly Budget
                  _buildSectionTitle('Monthly Budget'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E), // Dark card bg
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Budget',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              '$currencySymbol${totalBudget.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$currencySymbol${totalMonthlySpending.toStringAsFixed(0)} of $currencySymbol${totalBudget.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${totalBudget > 0 ? ((totalMonthlySpending / totalBudget) * 100).toStringAsFixed(0) : 0}%',
                              style: TextStyle(
                                color: totalMonthlySpending > totalBudget
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: totalBudget > 0
                              ? (totalMonthlySpending / totalBudget).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0,
                          backgroundColor: Colors.grey[800],
                          color: totalMonthlySpending > totalBudget
                              ? Colors.red
                              : const Color(0xFFCEFF00), // Vexly-ish lime green
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Upcoming Renewals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Upcoming Renewals'),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'View All',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: topUpcoming.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No upcoming renewals in next 7 days 🎉',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ]
                          : topUpcoming
                                .map(
                                  (sub) => ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[900],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.subscriptions,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      sub.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      DateFormat(
                                        'MMM d',
                                      ).format(sub.nextPaymentDate),
                                    ),
                                    trailing: Text(
                                      '$currencySymbol${sub.price}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Spending by Category
                  _buildSectionTitle('Spending by Category'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: categories
                          .where((c) => (categorySpending[c.id] ?? 0) > 0)
                          .map((cat) {
                            final spending = categorySpending[cat.id] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        cat.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '$currencySymbol${spending.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: cat.monthlyBudget > 0
                                        ? (spending / cat.monthlyBudget).clamp(
                                            0.0,
                                            1.0,
                                          )
                                        : 0.0,
                                    backgroundColor: Colors.grey[800],
                                    color:
                                        (spending > cat.monthlyBudget &&
                                            cat.monthlyBudget > 0)
                                        ? Colors.red
                                        : Color(cat.colorValue),
                                    minHeight: 4,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required double width,
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1E1E1E), color.withOpacity( 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity( 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity( 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
    );
  }

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'JPY':
        return '¥';
      case 'GBP':
        return '£';
      case 'THB':
      default:
        return '฿';
    }
  }
}




