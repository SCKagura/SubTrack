import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/add_subscription_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/subscription_detail_screen.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';

enum ViewMode { list, grid }

enum SortBy { name, price, nextPayment, category }

class SubscriptionListScreen extends ConsumerStatefulWidget {
  const SubscriptionListScreen({super.key});

  @override
  ConsumerState<SubscriptionListScreen> createState() =>
      _SubscriptionListScreenState();
}

class _SubscriptionListScreenState
    extends ConsumerState<SubscriptionListScreen> {
  ViewMode _viewMode = ViewMode.list;
  SortBy _sortBy = SortBy.nextPayment;
  String? _filterCategoryId;

  @override
  Widget build(BuildContext context) {
    final subRepo = ref.watch(subscriptionRepositoryProvider);
    final catRepo = ref.watch(categoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          // View Mode Toggle
          IconButton(
            icon: Icon(
              _viewMode == ViewMode.list ? Icons.grid_view : Icons.view_list,
            ),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == ViewMode.list
                    ? ViewMode.grid
                    : ViewMode.list;
              });
            },
          ),
          // Sort Menu
          PopupMenuButton<SortBy>(
            icon: const Icon(Icons.sort),
            onSelected: (SortBy value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortBy.name,
                child: Text('Sort by Name'),
              ),
              const PopupMenuItem(
                value: SortBy.price,
                child: Text('Sort by Price'),
              ),
              const PopupMenuItem(
                value: SortBy.nextPayment,
                child: Text('Sort by Next Payment'),
              ),
              const PopupMenuItem(
                value: SortBy.category,
                child: Text('Sort by Category'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Category>>(
        stream: catRepo.watchCategories(),
        builder: (context, catSnapshot) {
          final categories = catSnapshot.data ?? [];
          final categoryMap = {for (var c in categories) c.id: c};

          return StreamBuilder<List<Subscription>>(
            stream: subRepo.watchSubscriptions(),
            builder: (context, snapshot) {
              // StreamBuilder: รอรับข้อมูลจาก Repository แบบ Real-time
              // เมื่อข้อมูลเปลี่ยน (เช่น เพิ่ม/ลบ) หน้าจอจะรีเฟรชเองอัตโนมัติ
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var subs = snapshot.data!;

              // Filter by category (กรองตามหมวดหมู่ถ้ามีการเลือก)
              if (_filterCategoryId != null) {
                subs = subs
                    .where((s) => s.categoryId == _filterCategoryId)
                    .toList();
              }

              // Sort
              switch (_sortBy) {
                case SortBy.name:
                  subs.sort((a, b) => a.name.compareTo(b.name));
                  break;
                case SortBy.price:
                  subs.sort((a, b) => b.price.compareTo(a.price));
                  break;
                case SortBy.nextPayment:
                  subs.sort(
                    (a, b) => a.nextPaymentDate.compareTo(b.nextPaymentDate),
                  );
                  break;
                case SortBy.category:
                  subs.sort((a, b) {
                    final catA = categoryMap[a.categoryId]?.name ?? '';
                    final catB = categoryMap[b.categoryId]?.name ?? '';
                    return catA.compareTo(catB);
                  });
                  break;
              }

              if (subs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.subscriptions_outlined,
                        size: 64,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No subscriptions yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Filter Chips
                  if (categories.isNotEmpty)
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: _filterCategoryId == null,
                            onSelected: (_) {
                              setState(() {
                                _filterCategoryId = null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ...categories.map(
                            (cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(cat.name),
                                selected: _filterCategoryId == cat.id,
                                onSelected: (_) {
                                  setState(() {
                                    _filterCategoryId = cat.id;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // List/Grid View
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _viewMode == ViewMode.list
                          ? _buildListView(subs, categoryMap)
                          : _buildGridView(subs, categoryMap),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSubscriptionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(
    List<Subscription> subs,
    Map<String, Category> categoryMap,
  ) {
    return ListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.all(16),
      itemCount: subs.length,
      itemBuilder: (context, index) {
        final sub = subs[index];
        final category = categoryMap[sub.categoryId];
        final daysUntil = sub.nextPaymentDate.difference(DateTime.now()).inDays;
        final isUrgent = daysUntil <= 3 && daysUntil >= 0;
        final isOverdue = daysUntil < 0;
        // ตรวจสอบสถานะว่าถูกยกเลิกหรือไม่
        final isCancelled = sub.status.toLowerCase() == 'cancelled';

        return Hero(
          tag: 'sub-${sub.id}',
          child: Opacity(
            // Ghosting Effect: ถ้าสถานะเป็น Cancelled ให้จางลงเหลือ 50% (0.5)
            // ถ้าสถานะปกติ ให้ชัด 100% (1.0) ทำให้ผู้ใช้รู้ว่าเป็นอดีต
            opacity: isCancelled ? 0.5 : 1.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: category != null
                        ? Color(
                            category.colorValue,
                          ).withOpacity( isCancelled ? 0.08 : 0.15)
                        : Colors.black.withOpacity( isCancelled ? 0.1 : 0.2,
                          ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _navigateToDetail(sub),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1E1E1E),
                              category != null
                                  ? Color(
                                      category.colorValue,
                                    ).withOpacity( 0.04)
                                  : const Color(0xFF1A1A1A),
                            ],
                          ),
                          border: Border.all(
                            color: category != null
                                ? Color(
                                    category.colorValue,
                                  ).withOpacity( isCancelled ? 0.15 : 0.3)
                                : Colors.white10,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Category Icon
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: category != null
                                        ? [
                                            Color(
                                              category.colorValue,
                                            ).withOpacity( 0.3),
                                            Color(
                                              category.colorValue,
                                            ).withOpacity( 0.15),
                                          ]
                                        : [
                                            Colors.grey.withOpacity( 0.3),
                                            Colors.grey.withOpacity( 0.15),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: category != null
                                        ? Color(
                                            category.colorValue,
                                          ).withOpacity( 0.5)
                                        : Colors.grey.withOpacity( 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  category != null
                                      ? IconData(
                                          category.iconCode,
                                          fontFamily: 'MaterialIcons',
                                        )
                                      : Icons.subscriptions,
                                  color: category != null
                                      ? Color(category.colorValue)
                                      : Colors.grey,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: category != null
                                            ? Color(
                                                category.colorValue,
                                              ).withOpacity( 0.15)
                                            : Colors.grey.withOpacity( 0.15,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: category != null
                                              ? Color(
                                                  category.colorValue,
                                                ).withOpacity( 0.3)
                                              : Colors.grey.withOpacity( 0.3,
                                                ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        category?.name ?? 'Uncategorized',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: category != null
                                              ? Color(category.colorValue)
                                              : Colors.grey,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isOverdue
                                                ? Colors.red.withOpacity( 0.15,
                                                  )
                                                : isUrgent
                                                ? Colors.orange.withOpacity( 0.15,
                                                  )
                                                : Colors.blue.withOpacity( 0.15,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: isOverdue
                                                ? Colors.red
                                                : isUrgent
                                                ? Colors.orange
                                                : Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          daysUntil == 0
                                              ? 'Due today'
                                              : isOverdue
                                              ? 'Overdue by ${-daysUntil} days'
                                              : 'Due in $daysUntil days',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isOverdue
                                                ? Colors.red
                                                : isUrgent
                                                ? Colors.orange
                                                : Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Price & Status
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.green.withOpacity( 0.15),
                                          Colors.green.withOpacity( 0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.withOpacity( 0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${_getCurrencySymbol(sub.currency)}${sub.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        sub.status,
                                      ).withOpacity( 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _getStatusColor(
                                          sub.status,
                                        ).withOpacity( 0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(sub.status),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          sub.status,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _getStatusColor(sub.status),
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Cancelled badge overlay: ถ้าสถานะ Cancel ให้แปะป้ายทับมุมขวาบน
                      if (isCancelled)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity( 0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withOpacity( 0.5),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'CANCELLED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(
    List<Subscription> subs,
    Map<String, Category> categoryMap,
  ) {
    return GridView.builder(
      key: const ValueKey('grid'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: subs.length,
      itemBuilder: (context, index) {
        final sub = subs[index];
        final category = categoryMap[sub.categoryId];
        final daysUntil = sub.nextPaymentDate.difference(DateTime.now()).inDays;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: category != null
                  ? Color(category.colorValue).withOpacity( 0.3)
                  : Colors.white10,
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _navigateToDetail(sub),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E1E1E),
                    const Color(0xFF1E1E1E).withOpacity( 0.8),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: category != null
                                ? Color(
                                    category.colorValue,
                                  ).withOpacity( 0.2)
                                : Colors.grey.withOpacity( 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            category != null
                                ? IconData(
                                    category.iconCode,
                                    fontFamily: 'MaterialIcons',
                                  )
                                : Icons.subscriptions,
                            color: category != null
                                ? Color(category.colorValue)
                                : Colors.grey,
                            size: 24,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              sub.status,
                            ).withOpacity( 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sub.status,
                            style: TextStyle(
                              fontSize: 9,
                              color: _getStatusColor(sub.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Info
                    Column(
                      children: [
                        Text(
                          sub.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category?.name ?? 'Uncategorized',
                          style: TextStyle(
                            fontSize: 11,
                            color: category != null
                                ? Color(category.colorValue)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),

                    // Price & Due Date
                    Column(
                      children: [
                        // Price
                        Text(
                          '${_getCurrencySymbol(sub.currency)}${sub.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Due Date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              daysUntil == 0
                                  ? 'Today'
                                  : daysUntil < 0
                                  ? 'Overdue'
                                  : '$daysUntil days',
                              style: TextStyle(
                                fontSize: 11,
                                color: daysUntil <= 3
                                    ? Colors.orange
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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



