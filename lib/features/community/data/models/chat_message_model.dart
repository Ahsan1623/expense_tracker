import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, expenseEvent, settlementEvent }

class ChatMessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final double? amount;
  final DateTime timestamp;
  final List<String> deletedBy; // Naya field

  ChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    this.amount,
    required this.timestamp,
    this.deletedBy = const [],
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessageModel(
      messageId: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      amount: (map['amount'] as num?)?.toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deletedBy: List<String>.from(map['deletedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type.name,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      'deletedBy': deletedBy,
    };
  }
}