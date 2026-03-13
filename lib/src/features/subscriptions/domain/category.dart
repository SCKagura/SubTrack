import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String name;
  final int iconCode; // Store IconData.codePoint
  final int colorValue; // Store Color.value
  final double monthlyBudget;
  final String currency;

  Category({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    required this.monthlyBudget,
    required this.currency,
  });

  factory Category.create({
    required String name,
    required IconData icon,
    required Color color,
    double monthlyBudget = 0.0,
    String currency = 'THB',
  }) {
    return Category(
      id: const Uuid().v4(),
      name: name,
      iconCode: icon.codePoint,
      colorValue: color.toARGB32(),
      monthlyBudget: monthlyBudget,
      currency: currency,
    );
  }

  Category copyWith({
    String? name,
    int? iconCode,
    int? colorValue,
    double? monthlyBudget,
    String? currency,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'monthlyBudget': monthlyBudget,
      'currency': currency,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map, String id) {
    return Category(
      id: id,
      name: map['name'] ?? '',
      iconCode: map['iconCode'] ?? Icons.category.codePoint,
      colorValue: map['colorValue'] ?? Colors.grey.toARGB32(),
      monthlyBudget: (map['monthlyBudget'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'THB',
    );
  }

  // Predefined defaults in Thai
  static List<Category> defaults(String currency) {
    return [
      Category.create(
        name: 'บันเทิงและสตรีมมิ่ง',
        icon: Icons.movie,
        color: Colors.redAccent,
        currency: currency,
      ),
      Category.create(
        name: 'การทำงานและซอฟต์แวร์',
        icon: Icons.computer,
        color: Colors.blueAccent,
        currency: currency,
      ),
      Category.create(
        name: 'ที่พักและสาธารณูปโภค',
        icon: Icons.bolt,
        color: Colors.amber,
        currency: currency,
      ),
      Category.create(
        name: 'สุขภาพและไลฟ์สไตล์',
        icon: Icons.fitness_center,
        color: Colors.pinkAccent,
        currency: currency,
      ),
      Category.create(
        name: 'การเงินและประกัน',
        icon: Icons.account_balance_wallet,
        color: Colors.green,
        currency: currency,
      ),
      Category.create(
        name: 'ช้อปปิ้งและจิปาถะ',
        icon: Icons.shopping_basket,
        color: Colors.deepPurpleAccent,
        currency: currency,
      ),
    ];
  }
}
