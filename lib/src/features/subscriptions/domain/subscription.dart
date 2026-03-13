import 'package:uuid/uuid.dart';

enum BillingCycle { weekly, monthly, yearly }

class Subscription {
  final String id;
  final String name;
  final String categoryId;
  final double price;
  final String currency;
  final BillingCycle cycle;
  final DateTime firstPaymentDate;
  final DateTime nextPaymentDate;
  final String status; // 'Active', 'Paused', 'Cancelled'
  final String? familyMemberId;
  final String? userId;
  final String? url;
  final String? logoUrl;
  final bool isFreeTrial;
  final bool isAutoRenew;
  final bool hasReminder;
  final int reminderDaysPrior;
  final DateTime? terminationDate;

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
    this.url,
    this.logoUrl,
    this.isFreeTrial = false,
    this.isAutoRenew = true,
    this.hasReminder = true,
    this.reminderDaysPrior = 1,
    this.terminationDate,
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
    String? url,
    String? logoUrl,
    bool isFreeTrial = false,
    bool isAutoRenew = true,
    bool hasReminder = true,
    int reminderDaysPrior = 1,
    DateTime? terminationDate,
  }) {
    return Subscription(
      id: const Uuid().v4(),
      name: name,
      categoryId: categoryId,
      price: price,
      currency: currency,
      cycle: cycle,
      firstPaymentDate: firstPaymentDate,
      nextPaymentDate: firstPaymentDate,
      status: 'Active',
      familyMemberId: familyMemberId,
      userId: userId,
      url: url,
      logoUrl: logoUrl,
      isFreeTrial: isFreeTrial,
      isAutoRenew: isAutoRenew,
      hasReminder: hasReminder,
      reminderDaysPrior: reminderDaysPrior,
      terminationDate: terminationDate,
    );
  }

  Subscription copyWith({
    String? name,
    double? price,
    DateTime? nextPaymentDate,
    String? status,
    String? userId,
    String? url,
    String? logoUrl,
    bool? isFreeTrial,
    bool? isAutoRenew,
    bool? hasReminder,
    int? reminderDaysPrior,
    DateTime? terminationDate,
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
      url: url ?? this.url,
      logoUrl: logoUrl ?? this.logoUrl,
      isFreeTrial: isFreeTrial ?? this.isFreeTrial,
      isAutoRenew: isAutoRenew ?? this.isAutoRenew,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderDaysPrior: reminderDaysPrior ?? this.reminderDaysPrior,
      terminationDate: terminationDate ?? this.terminationDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categoryId': categoryId,
      'price': price,
      'currency': currency,
      'cycle': cycle.name,
      'firstPaymentDate': firstPaymentDate.toIso8601String(),
      'nextPaymentDate': nextPaymentDate.toIso8601String(),
      'status': status,
      'familyMemberId': familyMemberId,
      'userId': userId,
      'url': url,
      'logoUrl': logoUrl,
      'isFreeTrial': isFreeTrial,
      'isAutoRenew': isAutoRenew,
      'hasReminder': hasReminder,
      'reminderDaysPrior': reminderDaysPrior,
      'terminationDate': terminationDate?.toIso8601String(),
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map, String id) {
    return Subscription(
      id: id,
      name: map['name'] ?? '',
      categoryId: map['categoryId'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'THB',
      cycle: BillingCycle.values.firstWhere(
        (e) => e.name == map['cycle'],
        orElse: () => BillingCycle.monthly,
      ),
      firstPaymentDate: DateTime.parse(
        map['firstPaymentDate'] ?? DateTime.now().toIso8601String(),
      ),
      nextPaymentDate: DateTime.parse(
        map['nextPaymentDate'] ?? DateTime.now().toIso8601String(),
      ),
      status: map['status'] ?? 'Active',
      familyMemberId: map['familyMemberId'],
      userId: map['userId'],
      url: map['url'],
      logoUrl: map['logoUrl'],
      isFreeTrial: map['isFreeTrial'] ?? false,
      isAutoRenew: map['isAutoRenew'] ?? true,
      hasReminder: map['hasReminder'] ?? true,
      reminderDaysPrior: map['reminderDaysPrior'] ?? 1,
      terminationDate: map['terminationDate'] != null
          ? DateTime.parse(map['terminationDate'])
          : null,
    );
  }
}
