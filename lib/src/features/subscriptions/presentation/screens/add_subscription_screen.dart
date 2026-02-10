import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/src/features/authentication/data/auth_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';

class AddSubscriptionScreen extends ConsumerStatefulWidget {
  final Subscription? subscriptionToEdit;

  const AddSubscriptionScreen({super.key, this.subscriptionToEdit});

  @override
  ConsumerState<AddSubscriptionScreen> createState() =>
      _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedCategoryId;
  BillingCycle _selectedCycle = BillingCycle.monthly;
  DateTime _firstPaymentDate = DateTime.now();
  String _currency = 'THB'; // Default

  @override
  void initState() {
    super.initState();
    if (widget.subscriptionToEdit != null) {
      final sub = widget.subscriptionToEdit!;
      _nameController.text = sub.name;
      _priceController.text = sub.price.toString();
      _selectedCategoryId = sub.categoryId;
      _selectedCycle = sub.cycle;
      _firstPaymentDate = sub.firstPaymentDate;
      _currency = sub.currency;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.read(categoryRepositoryProvider).getAllCategories();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subscriptionToEdit != null
              ? 'Edit Subscription'
              : 'New Subscription',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Service Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Category Selector
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(
                          IconData(c.iconCode, fontFamily: 'MaterialIcons'),
                          color: Color(c.colorValue),
                        ),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Price & Currency
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price'),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _currency,
                    items: ['THB', 'USD', 'EUR']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => setState(() => _currency = val!),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Billing Cycle
              DropdownButtonFormField<BillingCycle>(
                value: _selectedCycle,
                decoration: const InputDecoration(labelText: 'Billing Cycle'),
                items: BillingCycle.values.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCycle = val!),
              ),
              const SizedBox(height: 16),

              // First Payment Date
              ListTile(
                title: const Text('First Payment Date'),
                subtitle: Text(
                  DateFormat('yyyy-MM-dd').format(_firstPaymentDate),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _firstPaymentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null)
                    setState(() => _firstPaymentDate = picked);
                },
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saveSubscription,
                child: Text(
                  widget.subscriptionToEdit != null
                      ? 'Update Subscription'
                      : 'Save Subscription',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveSubscription() {
    if (_formKey.currentState!.validate()) {
      if (widget.subscriptionToEdit != null) {
        // Update existing
        // Note: Subscription.copyWith in domain might not support all fields.
        // Safest to create a new instance with the same ID.

        final newSub = Subscription(
          id: widget.subscriptionToEdit!.id,
          name: _nameController.text,
          categoryId: _selectedCategoryId!,
          price: double.parse(_priceController.text),
          currency: _currency,
          cycle: _selectedCycle,
          firstPaymentDate: _firstPaymentDate,
          // Keep existing schedule unless we want to reset it?
          // For MVP, allow editing metadata without resetting nextPaymentDate logic complexly.
          nextPaymentDate: widget.subscriptionToEdit!.nextPaymentDate,
          status: widget.subscriptionToEdit!.status,
          familyMemberId: widget.subscriptionToEdit!.familyMemberId,
        );

        ref.read(subscriptionRepositoryProvider).updateSubscription(newSub);
      } else {
        // Create new
        final userId = ref.read(authRepositoryProvider).currentUser?.uid;
        final sub = Subscription.create(
          name: _nameController.text,
          categoryId: _selectedCategoryId!,
          price: double.parse(_priceController.text),
          currency: _currency,
          cycle: _selectedCycle,
          firstPaymentDate: _firstPaymentDate,
          userId: userId,
        );
        ref.read(subscriptionRepositoryProvider).addSubscription(sub);
      }
      Navigator.pop(context);
    }
  }
}
