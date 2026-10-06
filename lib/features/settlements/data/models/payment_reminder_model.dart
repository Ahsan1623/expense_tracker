import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentReminderModel {
  final String reminderId;
  final String groupId;
  final String fromUserId; // Jisne paise lene hain (Receiver)
  final String toUserId;   // Jisne paise dene hain (Debtor)
  final double amount;
  final DateTime createdAt;

  PaymentReminderModel({
    required this.reminderId,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.createdAt,
  });

  factory PaymentReminderModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentReminderModel(
      reminderId: id,
      groupId: map['groupId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}