import 'package:expense_tracker/models/budget_model.dart';
import 'package:expense_tracker/widgets/add_expense_sheet.dart';
import 'package:expense_tracker/widgets/set_budget_dialog.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/ml_service.dart';
import 'package:expense_tracker/services/firestore_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) return const Center(child: Text('Please login'));

    final expensesAsync = ref.watch(expensesStreamProvider(user.uid));
    final budgetsAsync = ref.watch(budgetsStreamProvider(user.uid));

    return Scaffold(
      body: expensesAsync.when(
        data: (expenses) {
          return budgetsAsync.when(
            data: (budgets) {
              final prediction = MLService.predictNextMonthSpending(expenses);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 800;

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(expensesStreamProvider(user.uid));
                      ref.invalidate(budgetsStreamProvider(user.uid));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBudgetStatusCard(context, expenses, budgets),
                          const SizedBox(height: 16),
                          _buildMLInsightCard(context, prediction, expenses),
                          const SizedBox(height: 24),
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildPieChart(context, expenses)),
                                const SizedBox(width: 24),
                                Expanded(flex: 1, child: _buildTransactions(context, expenses, ref)),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _buildPieChart(context, expenses),
                                const SizedBox(height: 24),
                                _buildTransactions(context, expenses, ref),
                              ],
                            ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading budgets: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading expenses: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpense(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBudgetStatusCard(BuildContext context, List<ExpenseModel> expenses, List<BudgetModel> budgets) {
    final theme = Theme.of(context);
    final totalBudget = budgets.firstWhere(
      (b) => b.category == 'Total' && b.period == 'Monthly', 
      orElse: () => BudgetModel(id: '', userId: '', amount: 0, category: 'Total', period: 'Monthly'),
    );

    final now = DateTime.now();
    final monthlyExpenses = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);

    final bool hasBudget = totalBudget.amount > 0;
    final bool isOver = hasBudget && monthlyExpenses > totalBudget.amount;
    final double percent = hasBudget ? (monthlyExpenses / totalBudget.amount).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: isOver 
                ? [Colors.red.shade700, Colors.red.shade400] 
                : [theme.colorScheme.primary, theme.colorScheme.primary.withBlue(200)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly Budget Status', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white70)),
                IconButton(
                  onPressed: () => _showSetBudgetDialog(context, totalBudget.amount > 0 ? totalBudget : null, 'Total'),
                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '₹${monthlyExpenses.toStringAsFixed(2)} / ₹${totalBudget.amount.toStringAsFixed(0)}',
              style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white24,
              color: isOver ? Colors.yellow : Colors.white,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text(
              hasBudget 
                ? (isOver 
                    ? 'Over budget by ₹${(monthlyExpenses - totalBudget.amount).toStringAsFixed(0)} ⚠️' 
                    : 'Under budget by ₹${(totalBudget.amount - monthlyExpenses).toStringAsFixed(0)} ✅')
                : 'No budget set for this month',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            if (budgets.any((b) => b.category != 'Total')) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                const Text('Category Budgets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...budgets.where((b) => b.category != 'Total').map((b) => _buildCategoryBudgetRow(b, expenses)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBudgetRow(BudgetModel budget, List<ExpenseModel> expenses) {
    final now = DateTime.now();
    double spent = 0;
    
    if (budget.period == 'Daily') {
      spent = expenses
          .where((e) => e.category == budget.category && e.date.year == now.year && e.date.month == now.month && e.date.day == now.day)
          .fold(0.0, (sum, e) => sum + e.amount);
    } else if (budget.period == 'Monthly') {
      spent = expenses
          .where((e) => e.category == budget.category && e.date.year == now.year && e.date.month == now.month)
          .fold(0.0, (sum, e) => sum + e.amount);
    } else {
      spent = expenses
          .where((e) => e.category == budget.category && e.date.year == now.year)
          .fold(0.0, (sum, e) => sum + e.amount);
    }

    final bool isOver = spent > budget.amount;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${budget.category} (${budget.period})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            '₹${spent.toStringAsFixed(0)} / ₹${budget.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: isOver ? Colors.yellow : Colors.white, 
              fontSize: 12, 
              fontWeight: FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(BuildContext context, List<ExpenseModel> expenses) {
    final theme = Theme.of(context);
    final Map<String, double> data = _getCategoryData(expenses);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending by Category', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.7,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: data.entries.map((e) {
                    return PieChartSectionData(
                      color: _getCategoryColor(e.key),
                      value: e.value,
                      title: e.key.split(' ').last,
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: data.keys.map((cat) => InkWell(
                onTap: () => _showSetBudgetDialog(context, null, cat),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: _getCategoryColor(cat), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(cat, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.add_circle_outline, size: 12, color: Colors.grey),
                  ],
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactions(BuildContext context, List<ExpenseModel> expenses, WidgetRef ref) {
    final theme = Theme.of(context);
    final List<ExpenseModel> recent = expenses.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Transactions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              itemBuilder: (context, index) {
                final e = recent[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    child: Text(e.category.split(' ').last),
                  ),
                  title: Text(e.category.split(' ').first, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(e.date.toString().split(' ')[0], style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${e.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () => _deleteExpense(context, ref, e.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).deleteExpense(id);
    }
  }

  Widget _buildMLInsightCard(BuildContext context, double prediction, List<ExpenseModel> expenses) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Text('ML Prediction', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Estimated next month: ₹${prediction.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getMLSpots(expenses),
                      isCurved: true,
                      color: theme.colorScheme.secondary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: theme.colorScheme.secondary.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getMLSpots(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) return [const FlSpot(0, 0)];
    final sorted = List<ExpenseModel>.from(expenses)..sort((a, b) => a.date.compareTo(b.date));
    final lastExpenses = sorted.length > 10 ? sorted.sublist(sorted.length - 10) : sorted;
    return List.generate(lastExpenses.length, (i) => FlSpot(i.toDouble(), lastExpenses[i].amount));
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

  Map<String, double> _getCategoryData(List<ExpenseModel> expenses) {
    final Map<String, double> data = {};
    for (var e in expenses) {
      data[e.category] = (data[e.category] ?? 0) + e.amount;
    }
    return data;
  }

  void _showAddExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddExpenseSheet(),
    );
  }

  void _showSetBudgetDialog(BuildContext context, BudgetModel? budget, String? category) {
    showDialog(
      context: context,
      builder: (context) => SetBudgetDialog(existingBudget: budget, initialCategory: category),
    );
  }
}
