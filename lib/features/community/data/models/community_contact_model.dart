import 'package:cloud_firestore/cloud_firestore.dart';

enum ContactStatus { pending, accepted, rejected }

class CommunityContactModel {
  final String requestId;
  final String senderId;
  final String senderEmail;
  final String senderName;
  final String receiverId;
  final String receiverEmail;
  final ContactStatus status;
  final DateTime createdAt;

  CommunityContactModel({
    required this.requestId,
    required this.senderId,
    required this.senderEmail,
    required this.senderName,
    required this.receiverId,
    required this.receiverEmail,
    required this.status,
    required this.createdAt,
  });

  factory CommunityContactModel.fromMap(Map<String, dynamic> map, String id) {
    return CommunityContactModel(
      requestId: id,
      senderId: map['senderId'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      senderName: map['senderName'] ?? 'Member',
      receiverId: map['receiverId'] ?? '',
      receiverEmail: map['receiverEmail'] ?? '',
      status: ContactStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ContactStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverEmail': receiverEmail,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}