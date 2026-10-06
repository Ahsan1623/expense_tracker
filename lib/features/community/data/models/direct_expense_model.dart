import 'package:cloud_firestore/cloud_firestore.dart';

enum DirectSettlementStatus { pending, approved, rejected, none }
enum DirectSplitType { equal50_50, fullAmount }

class DirectExpenseModel {
  final String expenseId;
  final String payerId;
  final String borrowerId;
  final String title;
  final double totalAmount;
  final double owedAmount;
  final DirectSplitType splitType;
  final bool isSettlement;
  final DateTime createdAt;

  DirectExpenseModel({
    required this.expenseId,
    required this.payerId,
    required this.borrowerId,
    required this.title,
    required this.totalAmount,
    required this.owedAmount,
    required this.splitType,
    this.isSettlement = false,
    required this.createdAt,
  });

  factory DirectExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return DirectExpenseModel(
      expenseId: id,
      payerId: map['payerId'] ?? '',
      borrowerId: map['borrowerId'] ?? '',
      title: map['title'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      owedAmount: (map['owedAmount'] as num?)?.toDouble() ?? 0.0,
      splitType: DirectSplitType.values.firstWhere(
        (e) => e.name == map['splitType'],
        orElse: () => DirectSplitType.equal50_50,
      ),
      isSettlement: map['isSettlement'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'payerId': payerId,
      'borrowerId': borrowerId,
      'title': title,
      'totalAmount': totalAmount,
      'owedAmount': owedAmount,
      'splitType': splitType.name,
      'isSettlement': isSettlement,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}