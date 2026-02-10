import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catRepo = ref.watch(categoryRepositoryProvider);
    final subRepo = ref.watch(subscriptionRepositoryProvider);

    return StreamBuilder<List<Category>>(
      stream: catRepo.watchCategories(),
      builder: (context, catSnapshot) {
        if (!catSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final categories = catSnapshot.data!;

        return StreamBuilder<List<Subscription>>(
          stream: subRepo.watchSubscriptions(),
          builder: (context, subSnapshot) {
            if (!subSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final subs = subSnapshot.data!;
            final activeSubs = subs.where((s) => s.status == 'Active').toList();

            // Calculations
            double totalMonthlyBudget = 0;
            final categorySpending = <String, double>{};
            final categorySubCount = <String, int>{};

            for (final cat in categories) {
              totalMonthlyBudget += cat.monthlyBudget;
              categorySpending[cat.id] = 0;
              categorySubCount[cat.id] = 0;
            }

            double totalSpent = 0;
            for (final sub in activeSubs) {
              double monthlyPrice = sub.price;
              if (sub.cycle == BillingCycle.weekly) monthlyPrice *= 4;
              if (sub.cycle == BillingCycle.yearly) monthlyPrice /= 12;

              totalSpent += monthlyPrice;
              // Handle safe map access in case category was deleted but sub still points to it
              if (categorySpending.containsKey(sub.categoryId)) {
                categorySpending[sub.categoryId] =
                    (categorySpending[sub.categoryId] ?? 0) + monthlyPrice;
                categorySubCount[sub.categoryId] =
                    (categorySubCount[sub.categoryId] ?? 0) + 1;
              }
            }

            final budgetUtilization = totalMonthlyBudget > 0
                ? (totalSpent / totalMonthlyBudget) * 100
                : 0.0;

            return Scaffold(
              appBar: AppBar(title: const Text('Categories')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Summary Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Categories',
                            '${categories.length}',
                            '${categories.where((c) => c.monthlyBudget > 0).length} with budget limits',
                            Icons.category,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Monthly Budget',
                            '฿${totalMonthlyBudget.toStringAsFixed(0)}',
                            'Across all categories',
                            Icons.attach_money,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Budget Utilization',
                            '${budgetUtilization.toStringAsFixed(0)}%',
                            'of budget',
                            Icons.pie_chart,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Category Grid
                    categories.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                'No categories found.\nTap + to add one!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.4,
                                ),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final spent = categorySpending[cat.id] ?? 0;
                              final count = categorySubCount[cat.id] ?? 0;
                              final budget = cat.monthlyBudget;
                              final isOverBudget = budget > 0 && spent > budget;
                              final progress = budget > 0
                                  ? (spent / budget).clamp(0.0, 1.0)
                                  : 0.0;
                              final percent = budget > 0
                                  ? (spent / budget * 100).toStringAsFixed(0)
                                  : '0';

                              return _buildCategoryCard(
                                context,
                                cat,
                                spent,
                                count,
                                isOverBudget,
                                progress,
                                percent,
                                ref,
                              );
                            },
                          ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton(
                child: const Icon(Icons.add),
                onPressed: () => _showAddCategoryDialog(context, ref),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Category cat,
    double spent,
    int count,
    bool isOverBudget,
    double progress,
    String percent,
    WidgetRef ref,
  ) {
    return InkWell(
      onTap: () => _editCategory(context, ref, cat),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E1E1E),
              Color(cat.colorValue).withOpacity( 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(cat.colorValue).withOpacity( 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Color(cat.colorValue).withOpacity( 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                        size: 18,
                        color: Color(cat.colorValue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$count subscriptions',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Spent this month',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    Text(
                      '฿${spent.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Budget Limit',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    Text(
                      '฿${cat.monthlyBudget.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isOverBudget ? 'Over budget' : 'On track',
                      style: TextStyle(
                        color: isOverBudget ? Colors.red : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: isOverBudget ? Colors.red : Colors.green,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[800],
                  color: isOverBudget ? Colors.red : Colors.green,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    Color selectedColor = Colors.blue;
    int selectedIcon = Icons.category.codePoint;

    // Simple predefined colors
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    // Simple predefined icons
    final List<IconData> icons = [
      Icons.category,
      Icons.movie,
      Icons.music_note,
      Icons.work,
      Icons.home,
      Icons.fitness_center,
      Icons.cloud,
      Icons.shopping_cart,
      Icons.fastfood,
      Icons.games,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                    ),
                  ),
                  TextField(
                    controller: budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Budget',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Pick Color'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colors.map((c) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: selectedColor == c
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Pick Icon'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: icons.map((i) {
                      return IconButton(
                        icon: Icon(
                          i,
                          color: selectedIcon == i.codePoint
                              ? selectedColor
                              : Colors.grey,
                        ),
                        onPressed: () =>
                            setState(() => selectedIcon = i.codePoint),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final newCat = Category.create(
                  name: nameController.text,
                  color: selectedColor,
                  icon: IconData(selectedIcon, fontFamily: 'MaterialIcons'),
                  monthlyBudget: double.tryParse(budgetController.text) ?? 0.0,
                );
                ref.read(categoryRepositoryProvider).addCategory(newCat);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editCategory(BuildContext context, WidgetRef ref, Category category) {
    final budgetController = TextEditingController(
      text: category.monthlyBudget.toString(),
    );
    final nameController = TextEditingController(text: category.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${category.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Category Name'),
            ),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly Budget'),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              // Confirm delete
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Category?'),
                  content: const Text(
                    'Subscriptions in this category will not be deleted but may have display issues if not reassigned.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () {
                        ref
                            .read(categoryRepositoryProvider)
                            .deleteCategory(category.id);
                        Navigator.pop(context); // Close confirm
                        Navigator.pop(context); // Close edit
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newBudget = double.tryParse(budgetController.text) ?? 0.0;
              final updated = category.copyWith(
                name: nameController.text,
                monthlyBudget: newBudget,
              );
              ref.read(categoryRepositoryProvider).addCategory(updated);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
