import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { expense, income }

class ExpenseModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final DateTime date;
  final String? groupId;
  final List<String>? splitWith;
  final String? note;
  final TransactionType type;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.date,
    this.groupId,
    this.splitWith,
    this.note,
    this.type = TransactionType.expense,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'amount': amount,
        'category': category,
        'date': Timestamp.fromDate(date),
        'groupId': groupId,
        'splitWith': splitWith,
        'note': note,
        'type': type.name,
      };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        date: (json['date'] as Timestamp).toDate(),
        groupId: json['groupId'] as String?,
        splitWith: json['splitWith'] != null ? List<String>.from(json['splitWith']) : null,
        note: json['note'] as String?,
        type: TransactionType.values.byName(json['type'] ?? 'expense'),
      );
}
