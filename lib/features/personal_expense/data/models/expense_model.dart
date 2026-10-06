import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  entertainment,
  health,
  other,
}

class ExpenseModel {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String? note;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String docId) {
    return ExpenseModel(
      id: docId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ExpenseCategory.other,
      ),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'category': category.name,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }
}