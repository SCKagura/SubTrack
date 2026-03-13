import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';
import 'package:subtrack/src/features/subscriptions/domain/payment_record.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/subscriptions/presentation/screens/add_subscription_screen.dart';

class SubscriptionDetailScreen extends ConsumerWidget {
  final Subscription subscription;

  const SubscriptionDetailScreen({super.key, required this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subRepo = ref.watch(subscriptionRepositoryProvider);
    final catRepo = ref.watch(categoryRepositoryProvider);

    return StreamBuilder<List<Category>>(
      stream: catRepo.watchCategories(),
      builder: (context, catSnapshot) {
        if (!catSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final categories = catSnapshot.data!;
        final category = categories.firstWhere(
          (c) => c.id == subscription.categoryId,
          orElse: () => Category(
            id: 'unknown',
            name: 'Uncategorized',
            iconCode: Icons.help.codePoint,
            colorValue: Colors.grey.toARGB32(),
            monthlyBudget: 0,
            currency: 'THB',
          ),
        );

        final daysUntil = subscription.nextPaymentDate
            .difference(DateTime.now())
            .inDays;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Hero Header
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'sub-${subscription.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(category.colorValue),
                            Color(category.colorValue).withValues(alpha: 0.6),
                            const Color(0xFF1E1E1E),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Color(
                                  category.colorValue,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Color(
                                    category.colorValue,
                                  ).withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                IconData(
                                  category.iconCode,
                                  fontFamily: 'MaterialIcons',
                                ),
                                size: 40,
                                color: Color(category.colorValue),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              subscription.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(category.colorValue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddSubscriptionScreen(
                            subscriptionToEdit: subscription,
                          ),
                        ),
                      );
                    },
                  ),
                  if (subscription.status.toLowerCase() != 'cancelled')
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'cancel') {
                          _cancelSubscription(context, ref);
                        } else if (value == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('ยกเลิกการสมัครสมาชิก'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('ลบถาวร'),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'ลบถาวร',
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              'รอบจ่ายถัดไป',
                              DateFormat(
                                'MMM d, yyyy',
                              ).format(subscription.nextPaymentDate),
                              daysUntil == 0
                                  ? 'ครบกำหนดวันนี้'
                                  : daysUntil < 0
                                  ? 'เลยกำหนด'
                                  : 'อีก $daysUntil วัน',
                              Icons.calendar_today,
                              daysUntil <= 3 ? Colors.orange : Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              'จำนวนเงิน',
                              '${_getCurrencySymbol(subscription.currency)}${subscription.price.toStringAsFixed(0)}',
                              subscription.cycle.name == 'monthly'
                                  ? 'รายเดือน'
                                  : subscription.cycle.name == 'yearly'
                                  ? 'รายปี'
                                  : 'รายสัปดาห์',
                              Icons.attach_money,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<List<PaymentRecord>>(
                              future: subRepo.getHistory(subscription.id),
                              builder: (context, snapshot) {
                                final history = snapshot.data ?? [];
                                final totalSpent = history
                                    .where((r) => r.status == 'Paid')
                                    .fold<double>(
                                      0,
                                      (sum, r) => sum + r.amount,
                                    );
                                  final skippedCount = history.where((r) => r.status == 'Skipped').length;
                                  return _buildInfoCard(
                                    'ยอดจ่ายรวม',
                                    '${_getCurrencySymbol(subscription.currency)}${totalSpent.toStringAsFixed(0)}',
                                    '${history.where((r) => r.status == 'Paid').length} จ่ายแล้ว${skippedCount > 0 ? ' • $skippedCount ข้าม/ยกเลิก' : ''}',
                                    Icons.receipt_long,
                                    Colors.purple,
                                  );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              'สถานะ',
                              subscription.status == 'Active'
                                  ? 'ใช้งานอยู่'
                                  : 'ยกเลิกแล้ว',
                              subscription.status == 'Active'
                                  ? 'ต่ออายุอัตโนมัติ'
                                  : 'ไม่ต่ออายุ',
                              Icons.info_outline,
                              _getStatusColor(subscription.status),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Quick Actions
                      if (subscription.status.toLowerCase() == 'cancelled')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.restart_alt),
                            label: const Text(
                              'เริ่มการสมัครสมาชิกใหม่อีกครั้ง',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () =>
                                _reactivateSubscription(context, ref),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle),
                                label: const Text('จ่ายแล้ว'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () =>
                                    _showPaymentDialog(context, ref, 'Paid'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.skip_next),
                                label: const Text('ข้าม'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: const BorderSide(color: Colors.orange),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () =>
                                    _showPaymentDialog(context, ref, 'Skipped'),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 32),

                      // Payment History
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ประวัติการชำระเงิน',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('ดูทั้งหมด'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // History List
                      FutureBuilder<List<PaymentRecord>>(
                        future: subRepo.getHistory(subscription.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.04),
                                    Colors.white.withValues(alpha: 0.01),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 48,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'ยังไม่มีประวัติการชำระเงิน',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final history = snapshot.data!;
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.04),
                                  Colors.white.withValues(alpha: 0.01),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: history.length > 5
                                  ? 5
                                  : history.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final record = history[index];
                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: record.status == 'Paid'
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      record.status == 'Paid'
                                          ? Icons.check_circle
                                          : Icons.remove_circle_outline,
                                      color: record.status == 'Paid'
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    DateFormat(
                                      'MMM d, yyyy',
                                    ).format(record.date),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  subtitle: Text(
                                    record.status == 'Paid'
                                        ? 'จ่ายแล้ว'
                                        : 'ข้ามแล้ว',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: record.status == 'Paid'
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  trailing: Text(
                                    '${_getCurrencySymbol(subscription.currency)}${record.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
            Colors.black.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
        ],
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

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบการสมัครสมาชิก?'),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการลบ ${subscription.name}? การดำเนินการนี้ไม่สามารถย้อนกลับได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref
          .read(subscriptionRepositoryProvider)
          .deleteSubscription(subscription.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    final paymentDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: status == 'Paid' ? 'เลือกวันที่ชำระเงิน' : 'เลือกวันที่ข้าม',
      confirmText: 'ถัดไป',
    );
    if (paymentDate == null) return;

    DateTime suggestedNextDate = subscription.nextPaymentDate;
    if (subscription.cycle == BillingCycle.monthly) {
      suggestedNextDate = DateTime(
        suggestedNextDate.year,
        suggestedNextDate.month + 1,
        suggestedNextDate.day,
      );
    } else if (subscription.cycle == BillingCycle.yearly) {
      suggestedNextDate = DateTime(
        suggestedNextDate.year + 1,
        suggestedNextDate.month,
        suggestedNextDate.day,
      );
    } else {
      suggestedNextDate = suggestedNextDate.add(const Duration(days: 7));
    }

    if (!context.mounted) return;

    final nextDate = await showDatePicker(
      context: context,
      initialDate: suggestedNextDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'ยืนยันรอบจ่ายถัดไป',
      confirmText: 'ยืนยัน',
    );
    if (nextDate == null) return;

    if (context.mounted) {
      if (status == 'Paid') {
        await ref
            .read(subscriptionRepositoryProvider)
            .markAsPaid(
              subscription.id,
              subscription.price,
              paymentDate,
              nextDate,
            );
      } else {
        await ref
            .read(subscriptionRepositoryProvider)
            .skipPayment(subscription.id, paymentDate, nextDate);
      }
      if (context.mounted) Navigator.pop(context);
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

  Future<void> _reactivateSubscription(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เริ่มการสมัครสมาชิกใหม่อีกครั้ง'),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการเริ่มการสมัครสมาชิก "${subscription.name}" ใหม่อีกครั้ง? รายการนี้จะกลับไปอยู่ในหน้าการสมัครสมาชิกที่ใช้งานอยู่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('เริ่มใหม่'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final updatedSub = subscription.copyWith(status: 'Active');
      await ref
          .read(subscriptionRepositoryProvider)
          .updateSubscription(updatedSub);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เริ่มการสมัครสมาชิกใหม่แล้ว')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cancelSubscription(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกการสมัครสมาชิก'),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการยกเลิก "${subscription.name}"? ประวัติการชำระเงินของคุณจะยังคงอยู่ และคุณสามารถเริ่มใช้งานใหม่ได้ในภายหลัง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('เก็บไว้'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('ยกเลิกการสมัครสมาชิก'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final updatedSub = subscription.copyWith(status: 'Cancelled');
      await ref
          .read(subscriptionRepositoryProvider)
          .updateSubscription(updatedSub);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยกเลิกการสมัครสมาชิกแล้ว')),
        );
        Navigator.pop(context);
      }
    }
  }
}
