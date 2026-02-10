import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'category.g.dart';

@HiveType(typeId: 1)
class Category {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int iconCode; // Store IconData.codePoint

  @HiveField(3)
  final int colorValue; // Store Color.value

  @HiveField(4)
  final double monthlyBudget;

  @HiveField(5)
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
      colorValue: color.value,
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

  // Predefined defaults
  static List<Category> defaults(String currency) {
    return [
      Category.create(
        name: 'Entertainment',
        icon: Icons.movie,
        color: Colors.redAccent,
        currency: currency,
      ),
      Category.create(
        name: 'Music',
        icon: Icons.music_note,
        color: Colors.greenAccent,
        currency: currency,
      ),
      Category.create(
        name: 'Productivity',
        icon: Icons.work,
        color: Colors.blueAccent,
        currency: currency,
      ),
      Category.create(
        name: 'Utilities',
        icon: Icons.bolt,
        color: Colors.amber,
        currency: currency,
      ),
    ];
  }
}
