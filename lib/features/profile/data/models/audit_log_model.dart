import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditType { personalExpense, groupExpense, settlementSent, settlementReceived }

class AuditLogModel {
  final String logId;
  final String title;
  final String description;
  final double amount;
  final AuditType type;
  final String? groupName;
  final String? personName;
  final DateTime timestamp;

  AuditLogModel({
    required this.logId,
    required this.title,
    required this.description,
    required this.amount,
    required this.type,
    this.groupName,
    this.personName,
    required this.timestamp,
  });

  factory AuditLogModel.fromMap(Map<String, dynamic> map, String id) {
    return AuditLogModel(
      logId: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: AuditType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AuditType.personalExpense,
      ),
      groupName: map['groupName'],
      personName: map['personName'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'amount': amount,
      'type': type.name,
      'groupName': groupName,
      'personName': personName,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}