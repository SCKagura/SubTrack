import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/src/features/authentication/data/auth_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/add_subscription_screen.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/subscription_detail_screen.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(subscriptionRepositoryProvider);
    final catRepo = ref.watch(categoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SubTrack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Category>>(
        stream: catRepo.watchCategories(),
        builder: (context, catSnapshot) {
          final categories = catSnapshot.data ?? [];
          final categoryMap = {for (var c in categories) c.id: c};

          return StreamBuilder<List<Subscription>>(
            stream: repository.watchSubscriptions(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final subs = snapshot.data!;

              if (subs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.subscriptions_outlined,
                        size: 80,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No subscriptions yet',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to add one!',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: subs.length,
                itemBuilder: (context, index) {
                  final sub = subs[index];
                  final category = categoryMap[sub.categoryId];
                  final daysUntil = sub.nextPaymentDate
                      .difference(DateTime.now())
                      .inDays;
                  final isUrgent = daysUntil <= 3 && daysUntil >= 0;
                  final isOverdue = daysUntil < 0;
                  final isCancelled = sub.status.toLowerCase() == 'cancelled';

                  return Opacity(
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
                                : Colors.black.withOpacity( isCancelled ? 0.1 : 0.2),
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SubscriptionDetailScreen(subscription: sub),
                            ),
                          );
                        },
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
                                    ).withOpacity( 0.3)
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
                                              Colors.grey.withOpacity( 0.3,
                                              ),
                                              Colors.grey.withOpacity( 0.15,
                                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      Text(
                                        '${_getCurrencySymbol(sub.currency)}${sub.price.toStringAsFixed(0)} / ${sub.cycle.name}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.w500,
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
                                              borderRadius:
                                                  BorderRadius.circular(6),
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
                                            'Due: ${sub.nextPaymentDate.day}/${sub.nextPaymentDate.month}',
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

                                // Status Badge
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
                        // Cancelled badge overlay
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
                );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSubscriptionScreen(),
            ),
          );
        },
        label: const Text('Add New'),
        icon: const Icon(Icons.add),
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
