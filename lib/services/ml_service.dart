import 'package:expense_tracker/models/expense_model.dart';

class MLService {
  /// Simple moving average to predict next month's spending
  static double predictNextMonthSpending(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) return 0.0;

    // Group by month
    final Map<String, double> monthlyTotals = {};
    for (var e in expenses) {
      final monthKey = '${e.date.year}-${e.date.month}';
      monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0) + e.amount;
    }

    if (monthlyTotals.isEmpty) return 0.0;

    final totals = monthlyTotals.values.toList();
    final sum = totals.reduce((a, b) => a + b);
    return sum / totals.length;
  }

  static Map<String, dynamic> getInsights(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) return {'trend': 0.0, 'topCategory': 'None'};

    final Map<String, double> categoryTotals = {};
    for (var e in expenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
    }

    final topCategory = categoryTotals.entries.isEmpty 
        ? 'None' 
        : categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Calculate trend (this month vs last month)
    final now = DateTime.now();
    final thisMonth = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
    
    final lastMonthDate = DateTime(now.year, now.month - 1);
    final lastMonth = expenses
        .where((e) => e.date.year == lastMonthDate.year && e.date.month == lastMonthDate.month)
        .fold(0.0, (sum, e) => sum + e.amount);

    double trend = 0.0;
    if (lastMonth > 0) {
      trend = ((thisMonth - lastMonth) / lastMonth) * 100;
    }

    return {
      'trend': trend,
      'topCategory': topCategory,
      'thisMonth': thisMonth,
    };
  }
}
