import 'package:expense_tracker/models/budget_model.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SetBudgetDialog extends ConsumerStatefulWidget {
  final BudgetModel? existingBudget;
  final String? initialCategory;

  const SetBudgetDialog({super.key, this.existingBudget, this.initialCategory});

  @override
  ConsumerState<SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends ConsumerState<SetBudgetDialog> {
  late final TextEditingController _amountController;
  late String _selectedCategory;
  late String _selectedPeriod;
  bool _isLoading = false;

  final List<String> _categories = [
    'Total',
    'Food 🍔',
    'Travel ✈️',
    'Shopping 🛍️',
    'Bills 💡',
    'Health 💊',
    'Fuel ⛽',
    'EMI/Loan 🏦',
    'Emergency 🚨',
    'Entertainment 🎬',
    'Education 📚',
  ];

  final List<String> _periods = ['Daily', 'Monthly', 'Yearly'];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.existingBudget?.amount.toString() ?? '',
    );
    _selectedCategory = widget.initialCategory ?? widget.existingBudget?.category ?? _categories[0];
    _selectedPeriod = widget.existingBudget?.period ?? _periods[1]; // Default Monthly
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final user = ref.read(authServiceProvider).currentUser;
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (user == null || amount <= 0) return;

    setState(() => _isLoading = true);

    try {
      final budget = BudgetModel(
        id: widget.existingBudget?.id ?? '${user.uid}_${_selectedCategory}_${_selectedPeriod}',
        userId: user.uid,
        amount: amount,
        category: _selectedCategory,
        period: _selectedPeriod,
      );

      await ref.read(firestoreServiceProvider).setBudget(budget);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingBudget == null ? 'Set Budget' : 'Edit Budget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _selectedPeriod = v!),
              decoration: const InputDecoration(labelText: 'Period'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBudget,
          child: _isLoading ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Save'),
        ),
      ],
    );
  }
}
