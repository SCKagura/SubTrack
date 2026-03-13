import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:subtrack/src/features/authentication/data/user_profile_repository.dart';
import 'package:subtrack/src/features/notifications/application/notification_service.dart';
import 'package:subtrack/src/features/subscriptions/application/dashboard_logic.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/subscriptions/domain/family_member.dart';
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

            // --- Calculations via DashboardLogic ---
            final activeSubs = DashboardLogic.getActiveSubscriptions(subs);
            final totalMonthlySpending = DashboardLogic.calculateTotalMonthlySpending(activeSubs);
            final categorySpending = DashboardLogic.calculateCategorySpending(activeSubs);

            final userBudget = userProfileAsync.value?.monthlyBudget ?? 0;
            final totalBudget = DashboardLogic.calculateTotalBudget(userBudget, categories);

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            final upcomingSubs = DashboardLogic.getUpcomingSubscriptions(activeSubs, today);
            final topUpcoming = upcomingSubs.take(3).toList();


            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F0F2D), // Deep midnight blue
                    Color(0xFF050510), // Almost black
                  ],
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'แดชบอร์ด',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // ── Test notification button ──────────────────
                        Tooltip(
                          message: 'ทดสอบการแจ้งเตือน (5 วิ)',
                          child: IconButton(
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                              color: Color(0xFFC67C00),
                            ),
                            onPressed: () async {
                              await NotificationService().testNotification();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '🔔 จะได้รับการแจ้งเตือนใน 5 วินาที',
                                    ),
                                    duration: Duration(seconds: 4),
                                    backgroundColor: Color(0xFFC67C00),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'สรุปข้อมูลทางการเงินและตัวชี้วัดสำคัญ',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 32),

                    // --- Top Stat Grid (Overhaul) ---
                    _buildDashboardStatGrid(
                      totalMonthlySpending,
                      activeSubs.length,
                      categories,
                      categorySpending,
                      topUpcoming.firstOrNull,
                      currencySymbol,
                    ),
                    const SizedBox(height: 32),

                    // Bento Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;

                        final budgetCard = _buildBentoCard(
                          title: 'งบประมาณรายเดือน',
                          infoIcon: true,
                          actionText: totalBudget > 0 ? 'แก้ไข' : 'ตั้งค่า',
                          onAction: () => _showEditBudgetDialog(
                            context,
                            ref,
                            Supabase.instance.client.auth.currentUser?.id ?? '',
                            totalBudget,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    currencySymbol,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    totalMonthlySpending.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    ' / ${totalBudget.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    final ratio = totalBudget > 0 ? (totalMonthlySpending / totalBudget) : 0.0;
                                    return LinearGradient(
                                      colors: ratio > 0.9
                                          ? [Colors.redAccent, Colors.pinkAccent]
                                          : ratio > 0.7
                                              ? [Colors.orangeAccent, Colors.yellowAccent]
                                              : [const Color(0xFF03DAC6), const Color(0xFFBB86FC)],
                                    ).createShader(bounds);
                                  },
                                  child: LinearProgressIndicator(
                                    value: totalBudget > 0
                                        ? (totalMonthlySpending / totalBudget)
                                              .clamp(0.0, 1.0)
                                        : 0.0,
                                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                                    color: Colors.white,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                totalBudget > 0
                                    ? 'ใช้ไปแล้ว ${((totalMonthlySpending / totalBudget) * 100).toStringAsFixed(1)}%'
                                    : 'ยังไม่ได้ตั้งงบประมาณ',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );

                        final renewalsCard = _buildBentoCard(
                          title: 'รายการเร็วๆ นี้',
                          subtitle: 'ใน 7 วันข้างหน้า',
                          actionText: 'ดูเพิ่ม',
                          onAction: () {},
                          child: Column(
                            children: topUpcoming.isEmpty
                                ? [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Text(
                                        'ไม่มี',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ]
                                : topUpcoming
                                      .map(
                                        (sub) => _buildMinimalRenewal(
                                          sub,
                                          currencySymbol,
                                        ),
                                      )
                                      .toList(),
                          ),
                        );

                        final categoryCard = _buildBentoCard(
                          title: 'หมวดหมู่หลัก',
                          child: Column(
                            children: categories
                                .where((c) => (categorySpending[c.id] ?? 0) > 0)
                                .take(3)
                                .map((cat) {
                                  final spending = categorySpending[cat.id] ?? 0;
                                  return _buildCompactCategory(
                                    cat,
                                    spending,
                                    currencySymbol,
                                  );
                                })
                                .toList(),
                          ),
                        );

                        if (isMobile) {
                          return Column(
                            children: [
                              budgetCard,
                              const SizedBox(height: 16),
                              renewalsCard,
                              const SizedBox(height: 16),
                              categoryCard,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: budgetCard),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: renewalsCard),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: categoryCard),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // --- Pending Family Requests ---
                    StreamBuilder<List<FamilyMember>>(
                      stream: subRepo.watchPendingRequests(),
                      builder: (context, reqSnapshot) {
                        if (!reqSnapshot.hasData || reqSnapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final requests = reqSnapshot.data!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'คำขอเข้าครอบครัว',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...requests.map(
                              (req) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange.withValues(alpha: 0.15),
                                        Colors.redAccent.withValues(alpha: 0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.orange.withValues(alpha: 0.4),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Colors.orangeAccent,
                                      child: Icon(
                                        Icons.mail_outline,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'คำเชิญจาก ${req.name}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'ส่งถึง: ${req.email ?? ''}',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await subRepo.acceptFamilyRequest(req.id);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orangeAccent,
                                        foregroundColor: Colors.black,
                                      ),
                                      child: const Text('ตอบรับ'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        );
                      },
                    ),

                    // --- Shared Subscriptions (Read-Only) ---
                    StreamBuilder<List<Subscription>>(
                      stream: subRepo.watchSharedSubscriptions(),
                      builder: (context, sharedSnapshot) {
                        if (!sharedSnapshot.hasData || sharedSnapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final sharedSubs = sharedSnapshot.data!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'แชร์กับฉัน',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...sharedSubs.map(
                              (sub) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.purpleAccent.withValues(alpha: 0.12),
                                          Colors.deepPurple.withValues(alpha: 0.05),
                                          Colors.black.withValues(alpha: 0.1),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.purpleAccent.withValues(alpha: 0.2),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.purpleAccent.withValues(alpha: 0.05),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                child: Row(
                                  children: [
                                    if (sub.logoUrl != null && sub.logoUrl!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          sub.logoUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.star, color: Colors.white70, size: 20),
                                      ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sub.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'แชร์โดยครอบครัว',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '$currencySymbol${sub.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBentoCard({
    required String title,
    String? subtitle,
    bool infoIcon = false,
    String? actionText,
    VoidCallback? onAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
            Colors.black.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actionText != null)
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC67C00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      actionText,
                      style: const TextStyle(
                        color: Color(0xFFC67C00),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ],
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildDashboardStatGrid(
    double monthly,
    int activeCount,
    List<Category> categories,
    Map<String, double> categorySpending,
    Subscription? nextRenewal,
    String symbol,
  ) {
    // Find top category
    String topCatName = 'ไม่มีข้อมูล';
    int topCatColor = Colors.grey.toARGB32();
    if (categorySpending.isNotEmpty) {
      final topEntry = categorySpending.entries.reduce((a, b) => a.value > b.value ? a : b);
      final cat = categories.firstWhere((c) => c.id == topEntry.key);
      topCatName = cat.name;
      topCatColor = cat.colorValue;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildDashboardStatCard(
              'ยอดจ่ายรายเดือน',
              '$symbol${monthly.toStringAsFixed(0)}',
              [const Color(0xFF00C897), const Color(0xFF019471)],
              Icons.trending_up,
            ),
            _buildDashboardStatCard(
              'รายการที่ใช้งาน',
              '$activeCount',
              [const Color(0xFF448AFF), const Color(0xFF2979FF)],
              Icons.loop,
            ),
            _buildDashboardStatCard(
              'หมวดหมู่หลัก',
              topCatName,
              [Color(topCatColor), Color(topCatColor).withValues(alpha: 0.8)],
              Icons.pie_chart_outline,
            ),
            _buildDashboardStatCard(
              'ต่ออายุถัดไป',
              nextRenewal?.name ?? 'ไม่มี',
              [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
              Icons.calendar_today_outlined,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardStatCard(
    String title,
    String value,
    List<Color> gradientColors,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientColors[0],
            gradientColors[1],
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMinimalRenewal(Subscription sub, String symbol) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (sub.logoUrl != null && sub.logoUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                sub.logoUrl!,
                width: 16,
                height: 16,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC67C00),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFC67C00),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sub.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${sub.nextPaymentDate.day}/${sub.nextPaymentDate.month}',
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCategory(Category cat, double amount, String symbol) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cat.name,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              Text(
                '$symbol${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Colors.transparent,
              color: Color(cat.colorValue).withValues(alpha: 0.6),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
    double currentBudget,
  ) {
    final controller = TextEditingController(
      text: currentBudget.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'ตั้งงบประมาณรายเดือน',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'จำนวนงบประมาณ',
            labelStyle: TextStyle(color: Colors.grey),
            prefixText: '฿ ',
            prefixStyle: TextStyle(color: Colors.white),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = double.tryParse(controller.text) ?? 0;
              ref
                  .read(userProfileRepositoryProvider)
                  .updateMonthlyBudget(uid, newValue);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC67C00),
            ),
            child: const Text('บันทึก'),
          ),
        ],
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
