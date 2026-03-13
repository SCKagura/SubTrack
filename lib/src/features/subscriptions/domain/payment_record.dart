import 'package:uuid/uuid.dart';

class PaymentRecord {
  final String id;
  final String subscriptionId;
  final DateTime date;
  final double amount;
  final String status; // 'Paid', 'Skipped'
  final String? note;
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

  Map<String, dynamic> toMap() {
    return {
      'subscriptionId': subscriptionId,
      'date': date.toIso8601String(),
      'amount': amount,
      'status': status,
      'note': note,
      'userId': userId,
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map, String id) {
    return PaymentRecord(
      id: id,
      subscriptionId: map['subscriptionId'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      amount: (map['amount'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'Paid',
      note: map['note'],
      userId: map['userId'],
    );
  }
}
