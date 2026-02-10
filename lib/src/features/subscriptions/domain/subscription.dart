import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'subscription.g.dart';

@HiveType(typeId: 3)
enum BillingCycle {
  @HiveField(0)
  weekly,
  @HiveField(1)
  monthly,
  @HiveField(2)
  yearly,
}

@HiveType(typeId: 4)
class Subscription {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String categoryId;

  @HiveField(3)
  final double price;

  @HiveField(4)
  final String currency;

  @HiveField(5)
  final BillingCycle cycle;

  @HiveField(6)
  final DateTime firstPaymentDate;

  @HiveField(7)
  final DateTime nextPaymentDate; // Manual input

  @HiveField(8)
  final String status; // 'Active', 'Paused', 'Cancelled'

  @HiveField(9)
  final String? familyMemberId;

  @HiveField(10)
  final String? userId; // Adding userId for data isolation

  Subscription({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.currency,
    required this.cycle,
    required this.firstPaymentDate,
    required this.nextPaymentDate,
    required this.status,
    this.familyMemberId,
    this.userId,
  });

  factory Subscription.create({
    required String name,
    required String categoryId,
    required double price,
    required BillingCycle cycle,
    required DateTime firstPaymentDate,
    String currency = 'THB',
    String? familyMemberId,
    String? userId,
  }) {
    return Subscription(
      id: const Uuid().v4(),
      name: name,
      categoryId: categoryId,
      price: price,
      currency: currency,
      cycle: cycle,
      firstPaymentDate: firstPaymentDate,
      nextPaymentDate: firstPaymentDate, // Default next is first
      status: 'Active',
      familyMemberId: familyMemberId,
      userId: userId,
    );
  }

  Subscription copyWith({
    String? name,
    double? price,
    DateTime? nextPaymentDate,
    String? status,
    String? userId,
  }) {
    return Subscription(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId,
      price: price ?? this.price,
      currency: currency,
      cycle: cycle,
      firstPaymentDate: firstPaymentDate,
      nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
      status: status ?? this.status,
      familyMemberId: familyMemberId,
      userId: userId ?? this.userId,
    );
  }
}
