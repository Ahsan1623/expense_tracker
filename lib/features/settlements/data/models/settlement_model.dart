import 'package:cloud_firestore/cloud_firestore.dart';

enum SettlementStatus { pending, approved, rejected }

class SettlementModel {
  final String settlementId;
  final String groupId;
  final String fromUserId; // Jo paise de raha hai
  final String toUserId;   // Jisko paise milne hain
  final double amount;
  final String note;
  final SettlementStatus status;
  final DateTime createdAt;

  SettlementModel({
    required this.settlementId,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.note = 'Debt Settlement',
    this.status = SettlementStatus.pending,
    required this.createdAt,
  });

  factory SettlementModel.fromMap(Map<String, dynamic> map, String id) {
    return SettlementModel(
      settlementId: id,
      groupId: map['groupId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] ?? 'Debt Settlement',
      status: SettlementStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SettlementStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'note': note,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}