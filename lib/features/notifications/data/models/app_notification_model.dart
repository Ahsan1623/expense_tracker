import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationTargetType { group, chat, community }

class AppNotificationModel {
  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final String title;
  final String message;
  final NotificationTargetType targetType;
  final String targetId; // groupId ya peerUid
  final String extraData; // optional metadata like groupName
  final bool isRead;
  final DateTime createdAt;

  AppNotificationModel({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    required this.title,
    required this.message,
    required this.targetType,
    required this.targetId,
    this.extraData = '',
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return AppNotificationModel(
      id: id,
      recipientId: map['recipientId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      targetType: NotificationTargetType.values.firstWhere(
        (e) => e.name == map['targetType'],
        orElse: () => NotificationTargetType.group,
      ),
      targetId: map['targetId'] ?? '',
      extraData: map['extraData'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'title': title,
      'message': message,
      'targetType': targetType.name,
      'targetId': targetId,
      'extraData': extraData,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}