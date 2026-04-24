import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/services/ml_service.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) return const Center(child: Text('Please login'));

    final expensesAsync = ref.watch(expensesStreamProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & ML Insights')),
      body: expensesAsync.when(
        data: (allTransactions) {
          final expenses = allTransactions.where((t) => t.type == TransactionType.expense).toList();
          
          if (expenses.isEmpty) {
            return const Center(child: Text('No data for analysis'));
          }

          final insights = MLService.getInsights(expenses);
          final prediction = MLService.predictNextMonthSpending(expenses);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPredictionCard(context, prediction),
                const SizedBox(height: 12),
                _buildInsightCard(
                  context,
                  'Spending Trend',
                  '${insights['trend'] > 0 ? '+' : ''}${insights['trend'].toStringAsFixed(1)}% from last month',
                  insights['trend'] > 0 ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 12),
                _buildInsightCard(
                  context,
                  'Top Category',
                  insights['topCategory'],
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                _buildPieChart(context, expenses),
                const SizedBox(height: 24),
                const Text('Monthly Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _getLineData(expenses),
                              isCurved: true,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 4,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context, List<ExpenseModel> expenses) {
    final theme = Theme.of(context);
    final data = _getCategoryData(expenses);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending by Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180, 
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: data.entries.map((e) {
                    return PieChartSectionData(
                      color: _getCategoryColor(e.key),
                      value: e.value,
                      title: '', 
                      radius: 40,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: data.keys.map((cat) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _getCategoryColor(cat), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(cat, style: const TextStyle(fontSize: 10)),
                ],
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard(BuildContext context, double prediction) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ML Prediction (Linear Regression)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    'Estimated next month: ₹${prediction.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, String title, String value, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ListTile(
        dense: true,
        title: Text(title, style: const TextStyle(fontSize: 13)),
        trailing: Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  List<FlSpot> _getLineData(List<ExpenseModel> expenses) {
    final Map<int, double> monthly = {};
    for (var e in expenses) {
      final key = e.date.year * 12 + e.date.month;
      monthly[key] = (monthly[key] ?? 0) + e.amount;
    }
    
    final sortedKeys = monthly.keys.toList()..sort();
    return List.generate(sortedKeys.length, (i) {
      return FlSpot(i.toDouble(), monthly[sortedKeys[i]]!);
    });
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
}
