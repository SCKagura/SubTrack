import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'payment_record.g.dart';

@HiveType(typeId: 2)
class PaymentRecord {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String subscriptionId;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final String status; // 'Paid', 'Skipped'

  @HiveField(5)
  final String? note;

  @HiveField(6)
  final String? userId;

  PaymentRecord({
    required this.id,
    required this.subscriptionId,
    required this.date,
    required this.amount,
    required this.status,
    this.note,
    this.userId,
  });

  factory PaymentRecord.create({
    required String subscriptionId,
    required double amount,
    required String status,
    DateTime? date,
    String? note,
    String? userId,
  }) {
    return PaymentRecord(
      id: const Uuid().v4(),
      subscriptionId: subscriptionId,
      date: date ?? DateTime.now(),
      amount: amount,
      status: status,
      note: note,
      userId: userId,
    );
  }
}
