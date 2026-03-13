import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/src/features/authentication/data/user_profile_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/add_subscription_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/subscription_detail_screen.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';


enum ViewMode { list, grid }

class SubscriptionListScreen extends ConsumerStatefulWidget {
  const SubscriptionListScreen({super.key});

  @override
  ConsumerState<SubscriptionListScreen> createState() =>
      _SubscriptionListScreenState();
}

class _SubscriptionListScreenState
    extends ConsumerState<SubscriptionListScreen> {
  ViewMode _viewMode = ViewMode.list;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final subRepo = ref.watch(subscriptionRepositoryProvider);
    final catRepo = ref.watch(categoryRepositoryProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    final currencySymbol = _getCurrencySymbol(
      userProfileAsync.value?.currency ?? 'THB',
    );

    return StreamBuilder<List<Category>>(
      stream: catRepo.watchCategories(),
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? [];
        final categoryMap = {for (var c in categories) c.id: c};

        return StreamBuilder<List<Subscription>>(
          stream: subRepo.watchSubscriptions(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allSubs = snapshot.data!;
            final activeSubs = allSubs
                .where((s) => s.status.toLowerCase() != 'cancelled')
                .toList();

            // Calculations
            double monthlySpend = 0;
            for (final sub in activeSubs) {
              double price = sub.price;
              if (sub.cycle == BillingCycle.weekly) price *= 4;
              if (sub.cycle == BillingCycle.yearly) price /= 12;
              monthlySpend += price;
            }

            final now = DateTime.now();
            final next7Days = now.add(const Duration(days: 7));
            final upcomingCount = activeSubs
                .where(
                  (s) =>
                      s.nextPaymentDate.isAfter(
                        now.subtract(const Duration(days: 1)),
                      ) &&
                      s.nextPaymentDate.isBefore(next7Days),
                )
                .length;

            var filteredSubs = allSubs.where((s) {
              final nameMatch = s.name.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
              return nameMatch;
            }).toList();

            final lifetimeAsync = ref.watch(lifetimeSpendingProvider);
            final lifetimeData = lifetimeAsync.value ?? {'total': 0.0, 'count': 0};
            final double lifetimeTotal = lifetimeData['total'];
            final int lifetimeCount = lifetimeData['count'];

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Bar
                        _buildTopBar(context, isMobile),
                        const SizedBox(height: 32),

                        // Summary Cards
                        _buildSummaryRow(
                          monthlySpend,
                          activeSubs.length,
                          upcomingCount,
                          lifetimeTotal,
                          lifetimeCount,
                          currencySymbol,
                        ),
                        const SizedBox(height: 32),

                        // View Modes & Action Bar
                        _buildActionBar(isMobile, subRepo, categories),
                        const SizedBox(height: 16),

                        // Main Content Container
                        _buildMainContent(
                          filteredSubs,
                          categoryMap,
                          currencySymbol,
                          isMobile,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'การสมัครสมาชิกของฉัน',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'จัดการและติดตามรายการจ่ายรายรอบทั้งหมดในที่เดียว',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddSubscriptionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('เพิ่มการสมัครสมาชิก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC67C00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(
    double monthlySpend,
    int activeCount,
    int upcomingCount,
    double lifetimeTotal,
    int lifetimeCount,
    String currency,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'ยอดจ่ายรายรอบ',
                      '$currency${monthlySpend.toStringAsFixed(2)}',
                      '$activeCount ใช้งานอยู่',
                      Icons.loop,
                      gradientColors: [const Color(0xFF00C897), const Color(0xFF019471)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'รายการที่ใช้งาน',
                      '$activeCount',
                      '$activeCount รายการ',
                      Icons.credit_card,
                      gradientColors: [const Color(0xFF448AFF), const Color(0xFF2979FF)],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'ยอดสะสม',
                      '$currency${lifetimeTotal.toStringAsFixed(2)}',
                      '$lifetimeCount รายการ',
                      Icons.stars,
                      gradientColors: [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'เร็วๆ นี้',
                      '$upcomingCount',
                      'ใน 7 วันข้างหน้า',
                      Icons.info_outline,
                      gradientColors: [const Color(0xFFFF6D00), const Color(0xFFFF3D00)],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        const cardSpacing = 16.0;
        final cardWidth = (constraints.maxWidth - (cardSpacing * 3)) / 4;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSummaryCard(
              'ยอดจ่ายรายรอบ',
              '$currency${monthlySpend.toStringAsFixed(2)}',
              '$activeCount รายการที่ใช้งานอยู่',
              Icons.loop,
              width: cardWidth,
              gradientColors: [const Color(0xFF00C897), const Color(0xFF019471)],
            ),
            _buildSummaryCard(
              'ยอดสะสมทั้งหมด',
              '$currency${lifetimeTotal.toStringAsFixed(2)}',
              '$lifetimeCount รายการสะสม',
              Icons.stars,
              width: cardWidth,
              gradientColors: [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
            ),
            _buildSummaryCard(
              'รายการที่ใช้งาน',
              '$activeCount',
              '$activeCount รายการทั้งหมด',
              Icons.credit_card,
              width: cardWidth,
              gradientColors: [const Color(0xFF448AFF), const Color(0xFF2979FF)],
            ),
            _buildSummaryCard(
              'การต่ออายุเร็วๆ นี้',
              '$upcomingCount',
              'ครบกำหนดใน 7 วันข้างหน้า',
              Icons.info_outline,
              width: cardWidth,
              gradientColors: [const Color(0xFFFF6D00), const Color(0xFFFF3D00)],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    IconData icon, {
    double? width,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientColors[0],
            gradientColors[1],
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(
    bool isMobile,
    SubscriptionRepository subRepo,
    List<Category> categories,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // View Switches
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildViewToggleButton(
                    ViewMode.list,
                    'รายการ',
                    Icons.list_alt,
                  ),
                  _buildViewToggleButton(
                    ViewMode.grid,
                    'ตาราง',
                    Icons.grid_view,
                  ),
                ],
              ),
            ),
            // Add button for mobile
            if (isMobile)
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddSubscriptionScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.add_circle,
                  color: Color(0xFFC67C00),
                  size: 32,
                ),
              ),
            if (!isMobile)
              Row(
                children: [
                  _buildActionButton(
                    Icons.add_to_photos,
                    'สร้าง Mock',
                    onTap: () async {
                      if (categories.isEmpty) return;
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('กำลังสร้าง Mock...')),
                      );
                      try {
                        await subRepo.seedSampleSubscriptionsWithLogos(categories);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('สร้าง Mock ด้วยโลโก้ตัวอย่างสำเร็จ!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('เกิดข้อผิดพลาด Database: โปรดเช็คว่าสร้างคอลัมน์ logo_url(text) แล้ว ($e)'),
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    Icons.delete_sweep,
                    'ลบ Mock',
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('กำลังกวาดล้าง Mock...')),
                      );
                      try {
                        await subRepo.purgeMockData();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('ลบ Mock ข้อมูลตัวอย่างสำเร็จ!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(Icons.ios_share, 'ส่งออก'),
                  const SizedBox(width: 12),
                  _buildActionButton(Icons.share, 'แชร์'),
                ],
              ),
          ],
        ),
        if (isMobile) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionButton(
                  Icons.add_to_photos,
                  'สร้าง Mock',
                  onTap: () async {
                    if (categories.isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('กำลังสร้าง Mock...')),
                    );
                    try {
                      await subRepo.seedSampleSubscriptionsWithLogos(categories);
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('สร้าง Mock ด้วยโลโก้ตัวอย่างสำเร็จ!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('เกิดข้อผิดพลาด Database: โปรดเช็คว่าสร้างคอลัมน์ logo_url(text) แล้ว ($e)'),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  Icons.delete_sweep,
                  'ลบ Mock',
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('กำลังกวาดล้าง Mock...')),
                    );
                    try {
                      await subRepo.purgeMockData();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('ลบ Mock ข้อมูลตัวอย่างสำเร็จ!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 12),
                _buildActionButton(Icons.ios_share, 'ส่งออก'),
                const SizedBox(width: 12),
                _buildActionButton(Icons.share, 'แชร์'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildViewToggleButton(ViewMode mode, String label, IconData icon) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC67C00) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    List<Subscription> subs,
    Map<String, Category> categoryMap,
    String currency,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _buildSearchAndFilter(isMobile),
          const SizedBox(height: 24),
          if (_viewMode == ViewMode.list)
            isMobile
                ? _buildMobileList(subs, categoryMap, currency)
                : _buildTableList(subs, categoryMap, currency)
          else
            _buildCostBreakdown(subs, categoryMap, currency, isMobile),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ค้นหาการสมัครสมาชิก...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.grey,
                size: 18,
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildActionIconButton(Icons.tune, isMobile ? null : 'ตัวกรอง'),
        const SizedBox(width: 8),
        _buildActionIconButton(Icons.settings, isMobile ? null : 'ตั้งค่า'),
      ],
    );
  }

  Widget _buildActionIconButton(IconData icon, String? label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label != null ? 12 : 10,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileList(
    List<Subscription> subs,
    Map<String, Category> categoryMap,
    String currencySymbol,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subs.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Colors.white10),
      itemBuilder: (context, index) {
        final sub = subs[index];
        final cat = categoryMap[sub.categoryId];
        return _buildMobileListTile(sub, cat, currencySymbol);
      },
    );
  }

  Widget _buildMobileListTile(
    Subscription sub,
    Category? cat,
    String currencySymbol,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysUntil = sub.nextPaymentDate.difference(today).inDays;
    final isCancelled = sub.status.toLowerCase() == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cat != null
              ? [
                  Color(cat.colorValue).withValues(alpha: 0.15),
                  Color(cat.colorValue).withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.1),
                ]
              : [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.01),
                  Colors.black.withValues(alpha: 0.05),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(sub),
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: isCancelled ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
            children: [
              if (sub.logoUrl != null && sub.logoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    sub.logoUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          cat != null
                              ? IconData(cat.iconCode, fontFamily: 'MaterialIcons')
                              : Icons.subscriptions,
                          color: cat != null ? Color(cat.colorValue) : Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      cat != null
                          ? IconData(cat.iconCode, fontFamily: 'MaterialIcons')
                          : Icons.subscriptions,
                      color: cat != null ? Color(cat.colorValue) : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      cat?.name ?? 'General',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currencySymbol${sub.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    daysUntil == 0
                        ? 'วันนี้'
                        : daysUntil < 0
                        ? 'เลยกำหนด'
                        : 'เหลือ $daysUntil วัน',
                    style: TextStyle(
                      color: daysUntil <= 3 ? Colors.orange : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildTableList(
    List<Subscription> subs,
    Map<String, Category> categoryMap,
    String currencySymbol,
  ) {
    return Column(
      children: [
        // Table Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 48),
              Expanded(
                flex: 3,
                child: Text(
                  'บริการ',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'หมวดหมู่',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'จำนวนเงิน',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'รอบจ่ายถัดไป',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'สถานะ',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10),
        // Table Rows
        ...subs.map(
          (sub) =>
              _buildTableRow(sub, categoryMap[sub.categoryId], currencySymbol),
        ),
      ],
    );
  }

  Widget _buildTableRow(
    Subscription sub,
    Category? cat,
    String currencySymbol,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysUntil = sub.nextPaymentDate.difference(today).inDays;
    final isToday = daysUntil == 0;
    final isCancelled = sub.status.toLowerCase() == 'cancelled';

    return InkWell(
      onTap: () => _navigateToDetail(sub),
      child: Opacity(
        opacity: isCancelled ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              if (sub.logoUrl != null && sub.logoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    sub.logoUrl!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          cat != null
                              ? IconData(cat.iconCode, fontFamily: 'MaterialIcons')
                              : Icons.subscriptions,
                          color: cat != null ? Color(cat.colorValue) : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      cat != null
                          ? IconData(cat.iconCode, fontFamily: 'MaterialIcons')
                          : Icons.subscriptions,
                      color: cat != null ? Color(cat.colorValue) : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              // Name
              Expanded(
                flex: 3,
                child: Text(
                  sub.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Category
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cat != null
                            ? Color(cat.colorValue).withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cat != null
                              ? Color(cat.colorValue).withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monitor_outlined,
                            size: 10,
                            color: cat != null
                                ? Color(cat.colorValue)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cat?.name ?? 'General',
                            style: TextStyle(
                              color: cat != null
                                  ? Color(cat.colorValue)
                                  : Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currencySymbol${sub.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      sub.cycle.name,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              // Next Billing
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday
                          ? 'Today'
                          : daysUntil < 0
                          ? 'Overdue'
                          : 'in $daysUntil days',
                      style: TextStyle(
                        color: isToday
                            ? Colors.orange
                            : (daysUntil < 0 ? Colors.red : Colors.white),
                        fontSize: 12,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(sub.nextPaymentDate),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              // Status
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      sub.status,
                      style: TextStyle(
                        color: isCancelled
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCostBreakdown(
    List<Subscription> subs,
    Map<String, Category> categoryMap,
    String currency,
    bool isMobile,
  ) {
    if (subs.isEmpty) {
      return const Center(
        child: Text(
          'No data for cost breakdown',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final activeSubs = subs
        .where((s) => s.status.toLowerCase() != 'cancelled')
        .toList();
    if (activeSubs.isEmpty) {
      return const Center(
        child: Text(
          'No active subscriptions',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    activeSubs.sort((a, b) => b.price.compareTo(a.price));
    final total = activeSubs.fold(0.0, (sum, item) => sum + item.price);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Cost Breakdown',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          'Visual breakdown of your subscription costs',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isBentoDesktop = width > 700;

            final top1 = activeSubs[0];
            final top2 = activeSubs.length > 1 ? activeSubs[1] : null;
            final top3 = activeSubs.length > 2 ? activeSubs[2] : null;
            final others = activeSubs.skip(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top 3 Bento Section
                if (isBentoDesktop)
                  SizedBox(
                    height: 380,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero Card (Top 1)
                        Expanded(
                          flex: 3,
                          child: _buildWeightedCard(
                            context,
                            top1,
                            categoryMap,
                            currency,
                            total,
                            isHero: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Secondary Cards Column (Top 2 & 3)
                        if (top2 != null || top3 != null)
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                if (top2 != null)
                                  Expanded(
                                    child: _buildWeightedCard(
                                      context,
                                      top2,
                                      categoryMap,
                                      currency,
                                      total,
                                      isSmall: true,
                                    ),
                                  ),
                                if (top2 != null && top3 != null)
                                  const SizedBox(height: 16),
                                if (top3 != null)
                                  Expanded(
                                    child: _buildWeightedCard(
                                      context,
                                      top3,
                                      categoryMap,
                                      currency,
                                      total,
                                      isSmall: true,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else
                          const Expanded(flex: 2, child: SizedBox.shrink()),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      _buildWeightedCard(
                        context,
                        top1,
                        categoryMap,
                        currency,
                        total,
                        isHero: true,
                      ),
                      if (top2 != null || top3 != null) ...[
                        const SizedBox(height: 16),
                        if (top2 != null)
                          _buildWeightedCard(
                            context,
                            top2,
                            categoryMap,
                            currency,
                            total,
                            isSmall: true,
                          ),
                        if (top2 != null && top3 != null)
                          const SizedBox(height: 16),
                        if (top3 != null)
                          _buildWeightedCard(
                            context,
                            top3,
                            categoryMap,
                            currency,
                            total,
                            isSmall: true,
                          ),
                      ],
                    ],
                  ),

                // Others Grid Section
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: others.map((sub) {
                      return SizedBox(
                        width: isMobile
                            ? double.infinity
                            : (width - 16) / 2,
                        child: _buildWeightedCard(
                          context,
                          sub,
                          categoryMap,
                          currency,
                          total,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeightedCard(
    BuildContext context,
    Subscription sub,
    Map<String, Category> categoryMap,
    String currency,
    double totalSpend, {
    bool isHero = false,
    bool isSmall = false,
  }) {
    final cat = categoryMap[sub.categoryId];
    final weight = sub.price / totalSpend;

    return Container(
      padding: EdgeInsets.all(isHero ? 28 : (isSmall ? 16 : 20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cat != null ? Color(cat.colorValue) : Colors.purple,
            cat != null
                ? Color(cat.colorValue).withValues(alpha: 0.8)
                : Colors.purple.withValues(alpha: 0.8),
            cat != null
                ? Color(cat.colorValue).withValues(alpha: 0.6)
                : Colors.purple.withValues(alpha: 0.6),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(isHero ? 32 : 24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: isHero
            ? [
                BoxShadow(
                  color: (cat != null ? Color(cat.colorValue) : Colors.purple)
                      .withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(isHero ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isHero ? 14 : 10),
                ),
                child: sub.logoUrl != null && sub.logoUrl!.isNotEmpty
                    ? Image.network(
                        sub.logoUrl!,
                        width: isHero ? 32 : 24,
                        height: isHero ? 32 : 24,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          cat != null
                              ? IconData(cat.iconCode, fontFamily: 'MaterialIcons')
                              : Icons.play_arrow,
                          color: cat != null ? Color(cat.colorValue) : Colors.red,
                          size: isHero ? 32 : 24,
                        ),
                      )
                    : Icon(
                        cat != null
                            ? IconData(cat.iconCode, fontFamily: 'MaterialIcons')
                            : Icons.play_arrow,
                        color: cat != null ? Color(cat.colorValue) : Colors.red,
                        size: isHero ? 32 : 24,
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(weight * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isHero ? 12 : 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (isHero) const SizedBox(height: 32),
          if (!isHero && !isSmall) const SizedBox(height: 16),
          if (isSmall) const SizedBox(height: 12),
          Text(
            sub.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: isHero ? 22 : (isSmall ? 14 : 18),
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$currency${sub.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: isHero ? 42 : (isSmall ? 22 : 32),
                fontWeight: FontWeight.bold,
                letterSpacing: isHero ? -1.0 : 0,
              ),
            ),
          ),
          Text(
            '~ $currency${(sub.price * 12).toStringAsFixed(0)}/yr',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: isHero ? 14 : 11,
            ),
          ),
        ],
      ),
    );
  }


  void _navigateToDetail(Subscription sub) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionDetailScreen(subscription: sub),
      ),
    );
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
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
