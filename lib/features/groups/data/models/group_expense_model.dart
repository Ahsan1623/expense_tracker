import 'package:cloud_firestore/cloud_firestore.dart';

class SplitItem {
  final String userId;
  final double owedAmount;

  SplitItem({required this.userId, required this.owedAmount});

  factory SplitItem.fromMap(Map<String, dynamic> map) {
    return SplitItem(
      userId: map['userId'] ?? '',
      owedAmount: (map['owedAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'owedAmount': owedAmount,
    };
  }
}

class GroupExpenseModel {
  final String expenseId;
  final String groupId;
  final String title;
  final double totalAmount;
  final String currency;
  final String category;
  final String paidByUserId; // Jis dost ne pay kia
  final String splitType; // 'EQUAL'
  final List<SplitItem> splits;
  final String createdById;
  final DateTime createdAt;

  GroupExpenseModel({
    required this.expenseId,
    required this.groupId,
    required this.title,
    required this.totalAmount,
    this.currency = 'PKR',
    this.category = 'General',
    required this.paidByUserId,
    this.splitType = 'EQUAL',
    required this.splits,
    required this.createdById,
    required this.createdAt,
  });

  factory GroupExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupExpenseModel(
      expenseId: id,
      groupId: map['groupId'] ?? '',
      title: map['title'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'PKR',
      category: map['category'] ?? 'General',
      paidByUserId: map['paidByUserId'] ?? '',
      splitType: map['splitType'] ?? 'EQUAL',
      splits: (map['splits'] as List<dynamic>?)
              ?.map((item) => SplitItem.fromMap(Map<String, dynamic>.from(item)))
              .toList() ??
          [],
      createdById: map['createdById'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'totalAmount': totalAmount,
      'currency': currency,
      'category': category,
      'paidByUserId': paidByUserId,
      'splitType': splitType,
      'splits': splits.map((s) => s.toMap()).toList(),
      'createdById': createdById,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}