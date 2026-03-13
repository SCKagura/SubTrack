import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/payment_record.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(subscriptionRepositoryProvider);

    return StreamBuilder<List<Subscription>>(
      stream: repo.watchSubscriptions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allSubs = snapshot.data!;
        if (allSubs.isEmpty) {
          return _buildEmptyState();
        }

        return FutureBuilder<List<List<PaymentRecord>>>(
          future: Future.wait(allSubs.map((s) => repo.getHistory(s.id))),
          builder: (context, historySnapshot) {
            if (!historySnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allPayments = <PaymentRecord>[];
            final subMap = <String, Subscription>{};

            for (var sub in allSubs) {
              subMap[sub.id] = sub;
            }

            for (var i = 0; i < allSubs.length; i++) {
              allPayments.addAll(historySnapshot.data![i]);
            }

            allPayments.sort((a, b) => b.date.compareTo(a.date));

            if (allPayments.isEmpty) {
              return _buildEmptyState();
            }

            final totalPaid = allPayments
                .where((r) => r.status == 'Paid')
                .fold<double>(0, (sum, r) => sum + r.amount);
            final totalSkipped = allPayments
                .where((r) => r.status == 'Skipped')
                .length;
            final paidCount = allPayments
                .where((r) => r.status == 'Paid')
                .length;

            // Group by month
            final grouped = <String, List<PaymentRecord>>{};
            for (final record in allPayments) {
              final key = DateFormat('MMMM yyyy').format(record.date);
              grouped.putIfAbsent(key, () => []).add(record);
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'ประวัติการชำระเงิน',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'รายการชำระเงินทั้งหมดและการข้ามรายการ',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'ยอดรวมที่จ่ายแล้ว',
                          '฿${NumberFormat('#,##0.00').format(totalPaid)}',
                          '$paidCount รายการ',
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'ที่ข้ามไป',
                          '$totalSkipped ครั้ง',
                          'รายการที่ถูกข้าม',
                          Icons.skip_next,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Grouped History
                  ...grouped.entries.map((entry) {
                    final monthTotal = entry.value
                        .where((r) => r.status == 'Paid')
                        .fold<double>(0, (sum, r) => sum + r.amount);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month Header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (monthTotal > 0)
                                Text(
                                  '฿${NumberFormat('#,##0').format(monthTotal)}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Records for this month
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: entry.value.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (context, index) {
                              final record = entry.value[index];
                              final sub = subMap[record.subscriptionId];
                              return _buildHistoryTile(record, sub);
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีประวัติการชำระเงิน',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'บันทึกสถานะการชำระเงินเพื่อดูประวัติที่นี่',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(PaymentRecord record, Subscription? sub) {
    final isPaid = record.status == 'Paid';
    final color = isPaid ? Colors.green : Colors.orange;
    final icon = isPaid ? Icons.check_circle : Icons.remove_circle_outline;
    final statusText = isPaid ? 'จ่ายแล้ว' : 'ข้ามแล้ว';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        sub?.name ?? 'Unknown',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        DateFormat('d MMM yyyy').format(record.date),
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isPaid ? '฿${NumberFormat('#,##0.00').format(record.amount)}' : '—',
            style: TextStyle(
              color: isPaid ? Colors.white : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
