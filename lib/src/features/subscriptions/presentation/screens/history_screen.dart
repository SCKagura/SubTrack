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
    // Note: detailed implementation would require a dedicated stream for all payments
    // or fetching all. For now, we iterate all subscriptions and their history.
    // Optimization: Store all payments in a separate Hive box that is iterable by date?
    // Current repo implementation separates payments but doesn't expose easy "getAllPayments".
    // Let's implement a simple fetch for now.

    return FutureBuilder<List<PaymentRecord>>(
      future: _fetchAllPayments(repo),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final payments = snapshot.data!;
        if (payments.isEmpty)
          return const Center(child: Text("No history yet."));

        return Scaffold(
          appBar: AppBar(title: const Text('Payment History')),
          body: ListView.builder(
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final record = payments[index];
              final sub = repo.getAllSubscriptions().firstWhere(
                (s) => s.id == record.subscriptionId,
                orElse: () => Subscription.create(
                  name: 'Unknown',
                  categoryId: '?',
                  price: 0,
                  cycle: BillingCycle.monthly,
                  firstPaymentDate: DateTime.now(),
                ),
              );

              return ListTile(
                leading: Icon(
                  record.status == 'Paid'
                      ? Icons.check_circle
                      : Icons.remove_circle_outline,
                  color: record.status == 'Paid' ? Colors.green : Colors.orange,
                ),
                title: Text(sub.name),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(record.date)),
                trailing: Text('${record.amount} ${sub.currency}'),
              );
            },
          ),
        );
      },
    );
  }

  Future<List<PaymentRecord>> _fetchAllPayments(
    SubscriptionRepository repo,
  ) async {
    // This is inefficient for large datasets but fine for MVP.
    // Ideally, we maintain a separate index or list of all payments sorted by date.
    // Repo implementation:
    // We only access history via getHistory(subscriptionId).
    // We need to iterate all subscriptions.

    final allSubs = repo
        .getAllSubscriptions(); // Only active? No, we might want archived too.
    final allPayments = <PaymentRecord>[];

    // Also include archived subs?
    final archivedSubs = repo.getArchivedSubscriptions();

    for (final sub in [...allSubs, ...archivedSubs]) {
      allPayments.addAll(repo.getHistory(sub.id));
    }

    allPayments.sort((a, b) => b.date.compareTo(a.date)); // Newest first
    return allPayments;
  }
}
