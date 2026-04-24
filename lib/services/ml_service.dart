import 'package:expense_tracker/models/expense_model.dart';
import 'dart:math';

class MLService {
  /// Simple Linear Regression with fallback to average for small/volatile datasets
  static double predictNextMonthSpending(List<ExpenseModel> expenses) {
    final validExpenses = expenses.where((e) => e.type == TransactionType.expense).toList();
    if (validExpenses.isEmpty) return 0.0;

    // Group by month/year index
    final Map<int, double> monthlyTotals = {};
    for (var e in validExpenses) {
      final monthIndex = (e.date.year * 12) + e.date.month;
      monthlyTotals[monthIndex] = (monthlyTotals[monthIndex] ?? 0) + e.amount;
    }

    final sortedKeys = monthlyTotals.keys.toList()..sort();
    final yValues = sortedKeys.map((k) => monthlyTotals[k]!).toList();

    if (sortedKeys.length < 2) {
      return yValues.first;
    }

    // Prepare data for regression
    final n = yValues.length;
    final xValues = List.generate(n, (i) => (i + 1).toDouble());

    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += xValues[i];
      sumY += yValues[i];
      sumXY += xValues[i] * yValues[i];
      sumX2 += xValues[i] * xValues[i];
    }

    final denominator = (n * sumX2 - sumX * sumX);
    if (denominator == 0) return yValues.last;

    final m = (n * sumXY - sumX * sumY) / denominator;
    final c = (sumY - m * sumX) / n;

    final nextMonthX = n + 1;
    double prediction = (m * nextMonthX) + c;

    // If regression results in negative or extreme drop (e.g. 0), 
    // fallback to a simple average of the last few months.
    if (prediction <= 0 || (n >= 2 && prediction < yValues.last * 0.2)) {
      return yValues.reduce((a, b) => a + b) / n;
    }

    return prediction;
  }

  static Map<String, dynamic> getInsights(List<ExpenseModel> expenses) {
    final validExpenses = expenses.where((e) => e.type == TransactionType.expense).toList();
    if (validExpenses.isEmpty) return {'trend': 0.0, 'topCategory': 'None', 'thisMonth': 0.0};

    final Map<String, double> categoryTotals = {};
    for (var e in validExpenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
    }

    final topCategory = categoryTotals.entries.isEmpty 
        ? 'None' 
        : categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final now = DateTime.now();
    final thisMonthTotal = validExpenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
    
    int lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
    int lastMonthNum = now.month == 1 ? 12 : now.month - 1;
    
    final lastMonthTotal = validExpenses
        .where((e) => e.date.year == lastMonthYear && e.date.month == lastMonthNum)
        .fold(0.0, (sum, e) => sum + e.amount);

    double trend = 0.0;
    if (lastMonthTotal > 0) {
      trend = ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
    }

    return {
      'trend': trend,
      'topCategory': topCategory,
      'thisMonth': thisMonthTotal,
    };
  }
}
