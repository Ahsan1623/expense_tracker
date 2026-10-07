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

class PayerItem {
  final String userId;
  final double amount;

  PayerItem({required this.userId, required this.amount});

  factory PayerItem.fromMap(Map<String, dynamic> map) {
    return PayerItem(
      userId: map['userId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
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
  final String paidByUserId;
  final List<PayerItem> payers;
  final String splitType;
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
    this.payers = const [], // Optional with default empty list to resolve compile errors
    this.splitType = 'EQUAL',
    required this.splits,
    required this.createdById,
    required this.createdAt,
  });

  factory GroupExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    List<PayerItem> parsedPayers = [];
    if (map['payers'] != null && (map['payers'] as List).isNotEmpty) {
      parsedPayers = (map['payers'] as List<dynamic>)
          .map((item) => PayerItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } else {
      final singlePayer = map['paidByUserId'] ?? '';
      final total = (map['totalAmount'] as num?)?.toDouble() ?? 0.0;
      if (singlePayer.isNotEmpty) {
        parsedPayers = [PayerItem(userId: singlePayer, amount: total)];
      }
    }

    return GroupExpenseModel(
      expenseId: id,
      groupId: map['groupId'] ?? '',
      title: map['title'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'PKR',
      category: map['category'] ?? 'General',
      paidByUserId: map['paidByUserId'] ?? (parsedPayers.isNotEmpty ? parsedPayers.first.userId : ''),
      payers: parsedPayers,
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
    final effectivePayers = payers.isNotEmpty
        ? payers
        : (paidByUserId.isNotEmpty ? [PayerItem(userId: paidByUserId, amount: totalAmount)] : <PayerItem>[]);

    return {
      'groupId': groupId,
      'title': title,
      'totalAmount': totalAmount,
      'currency': currency,
      'category': category,
      'paidByUserId': effectivePayers.isNotEmpty ? effectivePayers.first.userId : paidByUserId,
      'payers': effectivePayers.map((p) => p.toMap()).toList(),
      'splitType': splitType,
      'splits': splits.map((s) => s.toMap()).toList(),
      'createdById': createdById,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}