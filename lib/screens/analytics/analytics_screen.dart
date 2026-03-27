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
        data: (expenses) {
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
                const SizedBox(height: 16),
                _buildInsightCard(
                  context,
                  'Spending Trend',
                  '${insights['trend'] > 0 ? '+' : ''}${insights['trend'].toStringAsFixed(1)}% from last month',
                  insights['trend'] > 0 ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 16),
                _buildInsightCard(
                  context,
                  'Top Category',
                  insights['topCategory'],
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                const Text('Monthly Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
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
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPredictionCard(BuildContext context, double prediction) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ML Prediction', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Estimated next month: ₹${prediction.toStringAsFixed(2)}'),
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
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  List<FlSpot> _getLineData(List<ExpenseModel> expenses) {
    final sorted = List<ExpenseModel>.from(expenses)..sort((a, b) => a.date.compareTo(b.date));
    final last30Days = sorted.where((e) => e.date.isAfter(DateTime.now().subtract(const Duration(days: 30))));
    
    final Map<int, double> daily = {};
    for (var e in last30Days) {
      daily[e.date.day] = (daily[e.date.day] ?? 0) + e.amount;
    }

    final List<FlSpot> spots = [];
    final days = daily.keys.toList()..sort();
    for (var i = 0; i < days.length; i++) {
      spots.add(FlSpot(i.toDouble(), daily[days[i]]!));
    }
    return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
  }
}
