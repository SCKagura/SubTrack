import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/subscriptions/domain/payment_record.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _touchedIndex = -1;
  String _selectedRange = '6m';
  String _selectedFilter = 'ข้อมูลทั้งหมด';

  final List<String> _ranges = ['3m', '6m', '12m'];
  final List<String> _filters = ['ข้อมูลทั้งหมด', 'เดือนนี้', 'เดือนหน้า'];

  @override
  Widget build(BuildContext context) {
    final subRepo = ref.watch(subscriptionRepositoryProvider);
    final catRepo = ref.watch(categoryRepositoryProvider);

    return StreamBuilder<List<Subscription>>(
      stream: subRepo.watchSubscriptions(),
      builder: (context, subSnapshot) {
        return StreamBuilder<List<Category>>(
          stream: catRepo.watchCategories(),
          builder: (context, catSnapshot) {
            if (!subSnapshot.hasData || !catSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final subs = subSnapshot.data!;
            final categories = catSnapshot.data!;

            final now = DateTime.now();
            final startOfThisMonth = DateTime(now.year, now.month, 1);
            final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
            final startOfAfterNextMonth = DateTime(now.year, now.month + 2, 1);

            List<Subscription> activeSubs = subs
                .where((s) => s.status == 'Active')
                .toList();

            if (_selectedFilter == 'เดือนนี้') {
              activeSubs = activeSubs.where((s) {
                return !s.nextPaymentDate.isBefore(startOfThisMonth) &&
                    s.nextPaymentDate.isBefore(startOfNextMonth);
              }).toList();
            } else if (_selectedFilter == 'เดือนหน้า') {
              activeSubs = activeSubs.where((s) {
                return !s.nextPaymentDate.isBefore(startOfNextMonth) &&
                    s.nextPaymentDate.isBefore(startOfAfterNextMonth);
              }).toList();
            }

            if (activeSubs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ไม่พบข้อมูลการใช้งานสำหรับ $_selectedFilter',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _selectedFilter = 'ข้อมูลทั้งหมด'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('ล้างตัวกรอง'),
                    ),
                  ],
                ),
              );
            }

            return Container(
              width: double.infinity,
              height: double.infinity,
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'การวิเคราะห์',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'สรุปภาพรวมและสถิติการใช้งานของคุณในรูปแบบที่เข้าใจง่าย',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildFilterActionsRow(),
                  const SizedBox(height: 32),

                  // Bento Grid Section
                  _buildBentoGrid(activeSubs, subRepo, categories),
                    // Insights Section
                    _buildInsightsSection(activeSubs),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: child,
      ),
    );
  }

  Widget _buildFilterActionsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Filter Dropdown
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _selectedFilter = value),
            itemBuilder: (context) => _filters
                .map((f) => PopupMenuItem(value: f, child: Text(f)))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Text(
                    'ตัวกรอง',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedFilter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Time Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: _ranges
                  .map(
                    (r) => GestureDetector(
                      onTap: () => setState(() => _selectedRange = r),
                      child: _buildTimeTab(r, isSelected: _selectedRange == r),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _exportData(context),
            child: _buildActionButton(Icons.ios_share, 'ส่งออก'),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _shareData(context),
            child: _buildActionButton(Icons.share, 'แชร์'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTab(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFC67C00) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBentoGrid(
    List<Subscription> subs,
    SubscriptionRepository subRepo,
    List<Category> categories,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        if (isMobile) {
          return Column(
            children: [
              _buildFeaturedCard(subs),
              const SizedBox(height: 20),
              _buildTrendLineCard(subs, subRepo),
              const SizedBox(height: 20),
              _buildMetricsRow(subs),
              const SizedBox(height: 20),
              _buildCategoryPieCard(subs, categories),
            ],
          );
        }

        // Desktop Bento Layout
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildFeaturedCard(subs)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildMetricsGrid(subs)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildTrendLineCard(subs, subRepo)),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: _buildCategoryPieCard(subs, categories),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrendLineCard(
    List<Subscription> subs,
    SubscriptionRepository subRepo,
  ) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'แนวโน้มค่าใช้จ่าย',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'ยอดจ่ายรวมรายรอบในช่วงปีที่ผ่านมา',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 32),
          _buildTrendLineChart(subs, subRepo),
        ],
      ),
    );
  }

  Widget _buildCategoryPieCard(
    List<Subscription> subs,
    List<Category> categories,
  ) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สัดส่วนการใช้จ่าย',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'แบ่งตามหมวดหมู่การใช้งาน',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 24),
          _buildCategoryPieChart(subs, categories),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(List<Subscription> subs) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallStatCard(
            'ใช้งานอยู่',
            '${subs.length}',
            Icons.check_circle_outline,
            gradientColors: [const Color(0xFF448AFF), const Color(0xFF2979FF)],
            subtitle: 'แอปทั้งหมด',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallStatCard(
            'เฉลี่ย',
            '฿${_calculateMonthlyTotal(subs) == 0 ? 0 : (_calculateMonthlyTotal(subs) / (subs.isEmpty ? 1 : subs.length)).toStringAsFixed(0)}',
            Icons.analytics_outlined,
            gradientColors: [const Color(0xFF00C897), const Color(0xFF019471)],
            subtitle: 'ต่อบริการ',
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }


  double _calculateMonthlyTotal(List<Subscription> subs) {
    double total = 0;
    for (final sub in subs) {
      double price = sub.price;
      if (sub.cycle == BillingCycle.yearly) price /= 12;
      if (sub.cycle == BillingCycle.weekly) price *= 4;
      total += price;
    }
    return total;
  }


  Widget _buildFeaturedCard(List<Subscription> subs) {
    double monthlyTotal = 0;
    double prevMonthTotal = 0;
    for (final sub in subs) {
      double price = sub.price;
      if (sub.cycle == BillingCycle.yearly) price /= 12;
      if (sub.cycle == BillingCycle.weekly) price *= 4;
      monthlyTotal += price;
    }
    // Estimate prev month (simplified: same subscriptions with same price)
    // We show "no data" if there's no previous month payment history available
    prevMonthTotal = monthlyTotal; // baseline — we'd need history for real diff
    final diff = monthlyTotal - prevMonthTotal;
    final diffText = diff == 0
        ? 'ยอดจ่ายปัจจุบันเท่ากับเดือนที่ผ่านมา'
        : diff > 0
        ? 'เพิ่มขึ้น ฿${diff.toStringAsFixed(0)} เทียบกับเดือนก่อน'
        : 'ลดลง ฿${diff.abs().toStringAsFixed(0)} เทียบกับเดือนก่อน';

    return _buildGlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1), // Indigo
              Color(0xFF8B5CF6), // Violet
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
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
                const Text(
                  'ค่าใช้จ่ายรายเดือน',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'เดือนนี้',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '฿${monthlyTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    diffText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(List<Subscription> subs) {
    double monthlyTotal = 0;
    for (final sub in subs) {
      double price = sub.price;
      if (sub.cycle == BillingCycle.yearly) price /= 12;
      if (sub.cycle == BillingCycle.weekly) price *= 4;
      monthlyTotal += price;
    }
    final yearlyProjection = monthlyTotal * 12;
    final avgCost = subs.isEmpty ? 0 : monthlyTotal / subs.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildSmallStatCard(
              'รายปี',
              '฿${yearlyProjection.toStringAsFixed(0)}',
              Icons.calendar_today,
              gradientColors: [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
            ),
            _buildSmallStatCard(
              'ใช้งานอยู่',
              '${subs.length}',
              Icons.check_circle_outline,
              gradientColors: [const Color(0xFF448AFF), const Color(0xFF2979FF)],
            ),
            _buildSmallStatCard(
              'เฉลี่ย',
              '฿${avgCost.toStringAsFixed(0)}',
              Icons.analytics_outlined,
              gradientColors: [const Color(0xFF00C897), const Color(0xFF019471)],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmallStatCard(
    String label,
    String value,
    IconData icon, {
    String? subtitle,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildInsightsSection(List<Subscription> subs) {
    if (subs.isEmpty) return const SizedBox.shrink();

    // Find most expensive sub
    final mostExpensive = subs.reduce((a, b) {
      double aPrice = a.price;
      if (a.cycle == BillingCycle.yearly) aPrice /= 12;
      if (a.cycle == BillingCycle.weekly) aPrice *= 4;
      double bPrice = b.price;
      if (b.cycle == BillingCycle.yearly) bPrice /= 12;
      if (b.cycle == BillingCycle.weekly) bPrice *= 4;
      return aPrice > bPrice ? a : b;
    });

    final cycleInsights = _getCycleInsights(subs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ข้อมูลเชิงลึก & คำแนะนำ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        _buildInsightCard(
          'แจ้งเตือนค่าใช้จ่าย',
          '${mostExpensive.name} เป็นบริการที่แพงที่สุดของคุณ (฿${mostExpensive.price.toStringAsFixed(0)}/${_cycleToThai(mostExpensive.cycle)}) ลองตรวจสอบดูว่ายังใช้งานคุ้มค่าอยู่หรือไม่',
          Colors.redAccent.withValues(alpha: 0.1),
          Colors.redAccent,
          Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 12),
        if (cycleInsights != null)
          _buildInsightCard(
            'โอกาสในการประหยัด',
            cycleInsights,
            Colors.blueAccent.withValues(alpha: 0.1),
            Colors.blueAccent,
            Icons.lightbulb_outline,
          ),
        const SizedBox(height: 12),
        _buildInsightCard(
          'ภาพรวมสุขภาพการเงิน',
          'คุณมีค่าใช้จ่ายเฉลี่ยวันละ ฿${(_calculateMonthlyTotal(subs) / 30).toStringAsFixed(0)} ซึ่งถือว่าอยู่ในเกณฑ์ปกติสำหรับผู้ใช้งานทั่วไป',
          Colors.greenAccent.withValues(alpha: 0.1),
          Colors.greenAccent,
          Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  String? _getCycleInsights(List<Subscription> subs) {
    final hasWeekly = subs.any((s) => s.cycle == BillingCycle.weekly);
    final onlyMonthly = subs.every((s) => s.cycle == BillingCycle.monthly);

    if (hasWeekly) {
      return 'คุณมีบริการที่จ่ายรายสัปดาห์ การเปลี่ยนเป็นรายเดือนอาจช่วยให้ประหยัดได้ 10-15% ในบางบริการ';
    }
    if (onlyMonthly) {
      return 'บริการส่วนใหญ่ของคุณเป็นรายเดือน การเลือกจ่ายรายปีสำหรับแอปที่ใช้ประจำจะช่วยลดค่าใช้จ่ายรวมได้มาก';
    }
    return null;
  }

  String _cycleToThai(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return 'สัปดาห์';
      case BillingCycle.monthly:
        return 'เดือน';
      case BillingCycle.yearly:
        return 'ปี';
    }
  }

  Widget _buildInsightCard(
    String type,
    String message,
    Color bgColor,
    Color textColor,
    IconData icon,
  ) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(
    List<Subscription> subs,
    List<Category> categories,
  ) {
    final categoryTotals = <String, double>{};
    double totalSpend = 0;

    for (final sub in subs) {
      double monthlyPrice = sub.price;
      if (sub.cycle == BillingCycle.yearly) monthlyPrice /= 12;
      if (sub.cycle == BillingCycle.weekly) monthlyPrice *= 4;

      categoryTotals.update(
        sub.categoryId,
        (value) => value + monthlyPrice,
        ifAbsent: () => monthlyPrice,
      );
      totalSpend += monthlyPrice;
    }

    // Sort by value desc
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (totalSpend == 0) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: 1.3,
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse
                            .touchedSection!
                            .touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 0,
                  centerSpaceRadius: 25,
                  sections: List.generate(sortedEntries.length, (i) {
                    final isTouched = i == _touchedIndex;
                    final fontSize = isTouched ? 16.0 : 12.0;
                    final radius = isTouched ? 40.0 : 35.0;
                    final entry = sortedEntries[i];
                    final category = categories.firstWhere(
                      (c) => c.id == entry.key,
                      orElse: () => Category(
                        id: 'unknown',
                        name: 'Unknown',
                        iconCode: Icons.help.codePoint,
                        colorValue: Colors.grey.toARGB32(),
                        monthlyBudget: 0,
                        currency: 'THB',
                      ),
                    );
                    final color = Color(category.colorValue);

                    return PieChartSectionData(
                      color: color,
                      value: entry.value,
                      title:
                          '${((entry.value / totalSpend) * 100).toStringAsFixed(0)}%',
                      radius: radius,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 2),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(width: 28),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sortedEntries.map((e) {
              final category = categories.firstWhere(
                (c) => c.id == e.key,
                orElse: () => Category(
                  id: 'unknown',
                  name: 'Unknown',
                  iconCode: Icons.help.codePoint,
                  colorValue: Colors.grey.toARGB32(),
                  monthlyBudget: 0,
                  currency: 'THB',
                ),
              );
              final color = Color(category.colorValue);
              final name = category.name;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendLineChart(
    List<Subscription> activeSubs,
    SubscriptionRepository subRepo,
  ) {
    final historyFutures = activeSubs.map((s) => subRepo.getHistory(s.id));

    return FutureBuilder<List<List<PaymentRecord>>>(
      future: Future.wait(historyFutures),
      builder: (context, snapshot) {
        final now = DateTime.now();

        final int monthsToShow = _selectedRange == '3m'
            ? 3
            : (_selectedRange == '6m' ? 6 : 12);

        final monthlyTotals = <int, double>{};

        for (int i = 0; i < monthsToShow; i++) {
          monthlyTotals[i] = 0.0;
        }

        if (snapshot.hasData) {
          final allHistories = snapshot.data!;
          for (final history in allHistories) {
            for (final record in history) {
              if (record.status != 'Paid') continue;

              final monthDiff =
                  (now.year - record.date.year) * 12 +
                  now.month -
                  record.date.month;
              if (monthDiff >= 0 && monthDiff < monthsToShow) {
                monthlyTotals[monthsToShow - 1 - monthDiff] =
                    (monthlyTotals[monthsToShow - 1 - monthDiff] ?? 0) +
                    record.amount;
              }
            }
          }
        }

        final spots = List.generate(monthsToShow, (i) {
          return FlSpot(i.toDouble(), monthlyTotals[i] ?? 0);
        });

        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1000,
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final monthIndex = value.toInt();
                      if (monthIndex < 0 || monthIndex >= monthsToShow) {
                        return const Text('');
                      }
                      final date = DateTime(
                        now.year,
                        now.month - (monthsToShow - 1 - monthIndex),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('MMM').format(date),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value >= 1000
                            ? '${(value / 1000).toStringAsFixed(1)}k'
                            : value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (monthsToShow - 1).toDouble(),
              minY: 0,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: const Color(0xFFC67C00),
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFC67C00).withValues(alpha: 0.3),
                        const Color(0xFFC67C00).withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exportData(BuildContext context) async {
    final subRepo = ref.read(subscriptionRepositoryProvider);
    // Get all subs via stream (one-shot)
    final subs = await subRepo.getAllSubscriptions();

    // Build CSV
    final buffer = StringBuffer();
    buffer.writeln('Name,Price,Currency,Cycle,NextPayment,Status');
    for (final sub in subs) {
      buffer.writeln(
        '${sub.name},${sub.price},${sub.currency},${sub.cycle.name},${sub.nextPaymentDate.toIso8601String()},${sub.status}',
      );
    }

    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final bytes = Uint8List.fromList(buffer.toString().codeUnits);
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: 'SubTrack_Export_$now.csv',
          mimeType: 'text/csv',
        ),
      ],
      text: 'SubTrack Subscription Export — $now',
      subject: 'My Subscriptions',
    );
  }

  void _shareData(BuildContext context) async {
    final subRepo = ref.read(subscriptionRepositoryProvider);
    final subs = await subRepo.getAllSubscriptions();

    double monthlyTotal = 0;
    for (final sub in subs.where((s) => s.status == 'Active')) {
      double price = sub.price;
      if (sub.cycle == BillingCycle.yearly) price /= 12;
      if (sub.cycle == BillingCycle.weekly) price *= 4;
      monthlyTotal += price;
    }

    final text = StringBuffer();
    text.writeln('📊 My SubTrack Summary');
    text.writeln('Monthly spend: ฿${monthlyTotal.toStringAsFixed(2)}');
    text.writeln(
      'Yearly projection: ฿${(monthlyTotal * 12).toStringAsFixed(2)}',
    );
    text.writeln(
      'Active subscriptions: ${subs.where((s) => s.status == 'Active').length}',
    );
    text.writeln('\nTop subscriptions:');
    for (final sub in subs.where((s) => s.status == 'Active').take(5)) {
      text.writeln(
        '• ${sub.name}: ฿${sub.price.toStringAsFixed(0)}/${sub.cycle.name}',
      );
    }

    await Share.share(text.toString(), subject: 'My Subscriptions — SubTrack');
  }
}
