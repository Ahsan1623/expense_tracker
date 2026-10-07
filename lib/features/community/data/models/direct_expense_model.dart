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
  final String settlementStatus; // 'PENDING', 'CONFIRMED', 'REJECTED'
  final String paymentMode;
  final bool isArchived; // <-- Clear settle ke liye
  final DateTime createdAt;

  DirectExpenseModel({
    required this.expenseId,
    required this.payerId,
    required this.borrowerId,
    required this.title,
    required this.totalAmount,
    required this.owedAmount,
    required this.splitType,
    required this.isSettlement,
    this.settlementStatus = 'CONFIRMED',
    this.paymentMode = 'Cash',
    this.isArchived = false,
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
      splitType: map['splitType'] == 'equal50_50'
          ? DirectSplitType.equal50_50
          : DirectSplitType.fullAmount,
      isSettlement: map['isSettlement'] ?? false,
      settlementStatus: map['settlementStatus'] ?? 'CONFIRMED',
      paymentMode: map['paymentMode'] ?? 'Cash',
      isArchived: map['isArchived'] ?? false,
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
      'settlementStatus': settlementStatus,
      'paymentMode': paymentMode,
      'isArchived': isArchived,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}