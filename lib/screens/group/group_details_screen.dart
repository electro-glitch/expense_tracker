import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/models/group_model.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupDetailsScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This would typically use a stream for the specific group
    return Scaffold(
      appBar: AppBar(title: const Text('Group Details')),
      body: Column(
        children: [
          const ListTile(
            title: Text('Balances', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          // List member balances here
          const Divider(),
          const ListTile(
            title: Text('Group Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          // List group expenses here
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGroupExpenseDialog(context, ref),
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }

  void _showAddGroupExpenseDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Group Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final user = ref.read(authServiceProvider).currentUser;
              if (user != null) {
                final expense = ExpenseModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: user.uid,
                  amount: double.tryParse(amountController.text) ?? 0,
                  category: categoryController.text,
                  date: DateTime.now(),
                  groupId: groupId,
                );
                await ref.read(firestoreServiceProvider).addExpense(expense);
                // logic to update group balances would go here
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
