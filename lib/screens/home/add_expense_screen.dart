import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveExpense() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final expense = ExpenseModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        amount: double.tryParse(_amountController.text) ?? 0,
        category: _categoryController.text.trim(),
        date: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).addExpense(expense);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveExpense,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text('Save Expense'),
                  ),
          ],
        ),
      ),
    );
  }
}
