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
    final repository = ref.watch(subscriptionRepositoryProvider);
    final catRepo = ref.watch(categoryRepositoryProvider);
    final categories = catRepo.getAllCategories();
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
                        Color(category.colorValue).withOpacity( 0.3),
                        Color(category.colorValue).withOpacity( 0.1),
                        const Color(0xFF1E1E1E),
                      ],
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
                            ).withOpacity( 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Color(
                                category.colorValue,
                              ).withOpacity( 0.5),
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
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
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
                  icon: const Icon(Icons.more_vert),
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
                          Text('Cancel Subscription'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Permanently'),
                        ],
                      ),
                    ),
                  ],
                )
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete Permanently',
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
                          'Next Payment',
                          DateFormat(
                            'MMM d, yyyy',
                          ).format(subscription.nextPaymentDate),
                          daysUntil == 0
                              ? 'Due today'
                              : daysUntil < 0
                              ? 'Overdue'
                              : 'In $daysUntil days',
                          Icons.calendar_today,
                          daysUntil <= 3 ? Colors.orange : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'Amount',
                          '${_getCurrencySymbol(subscription.currency)}${subscription.price.toStringAsFixed(0)}',
                          subscription.cycle.name,
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
                          future: Future.value(
                            repository.getHistory(subscription.id),
                          ),
                          builder: (context, snapshot) {
                            final history = snapshot.data ?? [];
                            final totalSpent = history
                                .where((r) => r.status == 'Paid')
                                .fold<double>(0, (sum, r) => sum + r.amount);
                            return _buildInfoCard(
                              'Total Spent',
                              '${_getCurrencySymbol(subscription.currency)}${totalSpent.toStringAsFixed(0)}',
                              '${history.where((r) => r.status == 'Paid').length} payments',
                              Icons.receipt_long,
                              Colors.purple,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'Status',
                          subscription.status,
                          subscription.status == 'Active'
                              ? 'Renews automatically'
                              : 'Not renewing',
                          Icons.info_outline,
                          _getStatusColor(subscription.status),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  if (subscription.status.toLowerCase() == 'cancelled')
                    // Reactivate button for cancelled subscriptions
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reactivate Subscription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _reactivateSubscription(context, ref),
                      ),
                    )
                  else
                    // Mark Paid/Skip buttons for active subscriptions
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Mark Paid'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                            label: const Text('Skip'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                        'Payment History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // History List
                  FutureBuilder<List<PaymentRecord>>(
                    future: Future.value(
                      repository.getHistory(subscription.id),
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
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
                                  'No payment history yet',
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
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: history.length > 5 ? 5 : history.length,
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
                                      ? Colors.green.withOpacity( 0.2)
                                      : Colors.orange.withOpacity( 0.2),
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
                                DateFormat('MMM d, yyyy').format(record.date),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                record.status,
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        title: const Text('Delete Subscription?'),
        content: Text(
          'Are you sure you want to delete ${subscription.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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

  // ฟังก์ชันแสดง Dialog การจ่ายเงิน (Two-Step Process)
  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    // 1. ให้ผู้ใช้เลือก "วันที่จ่ายจริง" (History)
    // เพื่อบันทึกลงประวัติว่าจ่ายวันไหน (ยอมให้เลือกย้อนหลังได้)
    final paymentDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: status == 'Paid' ? 'SELECT PAYMENT DATE' : 'SELECT SKIP DATE',
      confirmText: 'NEXT',
    );
    if (paymentDate == null) return;

    // 2. คำนวณ "วันครบกำหนดรอบถัดไป" (Next Due Date) ล่วงหน้า
    // *Anchor Date Logic:* เราใช้ฐานจากวันครบกำหนดเดิม ไม่ใช่วันที่จ่ายจริง
    // เพื่อให้รอบบิลไม่เลื่อน (No Drift)
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

    // 3. ให้ผู้ใช้ยืนยัน "วันครบกำหนดรอบถัดไป" อีกครั้ง (Double Check)
    // เพื่อความยืดหยุ่น ถ้าต้องการเปลี่ยนรอบบิลก็สามารถแก้ได้ตรงนี้
    final nextDate = await showDatePicker(
      context: context,
      initialDate: suggestedNextDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'CONFIRM NEXT BILL DATE',
      confirmText: 'CONFIRM',
    );
    if (nextDate == null) return;

    if (context.mounted) {
      if (status == 'Paid') {
        // บันทึกสถานะ "จ่ายแล้ว" โดยส่งทั้ง 2 วันที่แยกกัน
        await ref
            .read(subscriptionRepositoryProvider)
            .markAsPaid(
              subscription.id,
              subscription.price,
              paymentDate, // ใช้วันที่จ่ายจริง (สำหรับ History)
              nextDate, // ใช้วันครบกำหนดที่ยืนยันแล้ว (สำหรับ Next Due)
            );
      } else {
        // กรณี Skip: ก็ส่ง 2 วันเช่นกัน แต่ยอดเงินเป็น 0
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
        title: const Text('Reactivate Subscription'),
        content: Text(
          'Are you sure you want to reactivate "${subscription.name}"? It will appear in your active subscriptions again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reactivate'),
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
          const SnackBar(content: Text('Subscription reactivated')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cancelSubscription(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: Text(
          'Are you sure you want to cancel "${subscription.name}"? Your payment history will be preserved, and you can reactivate it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Subscription'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Subscription cancelled')));
        Navigator.pop(context);
      }
    }
  }
}
