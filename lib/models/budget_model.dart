class BudgetModel {
  final String id;
  final String userId;
  final double amount;
  final String category; // 'Total' or specific category name
  final String period; // 'Daily', 'Monthly', 'Yearly'

  BudgetModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.period,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'amount': amount,
        'category': category,
        'period': period,
      };

  factory BudgetModel.fromJson(Map<String, dynamic> json) => BudgetModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        period: json['period'] as String,
      );
}
