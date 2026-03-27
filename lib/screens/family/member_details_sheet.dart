import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:expense_tracker/screens/home/home_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemberDetailsSheet extends ConsumerWidget {
  final String uid;
  final String name;

  const MemberDetailsSheet({super.key, required this.uid, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider(uid));
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "$name's Expenses",
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(
                    child: Text("No expenses found for this member."),
                  );
                }

                final categoryData = _getCategoryData(expenses);

                return Column(
                  children: [
                    // Small Pie Chart
                    SizedBox(
                      height: 150,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: categoryData.entries.map((e) {
                            return PieChartSectionData(
                              color: _getCategoryColor(e.key),
                              value: e.value,
                              title: e.key.split(' ').last,
                              radius: 40,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Expense History",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Scrollable List
                    Expanded(
                      child: ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final e = expenses[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              child: Text(
                                e.category.split(' ').last,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            title: Text(
                              e.category.split(' ').first,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              e.date.toString().split(' ')[0],
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              '₹${e.amount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text("Error: $e")),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _getCategoryData(List<ExpenseModel> expenses) {
    final Map<String, double> data = {};
    for (var e in expenses) {
      data[e.category] = (data[e.category] ?? 0) + e.amount;
    }
    return data;
  }

  Color _getCategoryColor(String category) {
    if (category.contains('Food')) return Colors.orange;
    if (category.contains('Travel')) return Colors.blue;
    if (category.contains('Shopping')) return Colors.pink;
    if (category.contains('Bills')) return Colors.amber;
    if (category.contains('Health')) return Colors.red;
    if (category.contains('Fuel')) return Colors.indigo;
    if (category.contains('EMI')) return Colors.deepPurple;
    if (category.contains('Emergency')) return Colors.redAccent;
    if (category.contains('Entertainment')) return Colors.purple;
    if (category.contains('Education')) return Colors.cyan;
    return Colors.teal;
  }
}
