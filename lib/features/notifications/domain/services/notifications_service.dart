import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

enum NotificationType { chat, group, settlementApproval, paymentReminder, communityInvite }

class AppNotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final NotificationType type;
  final DateTime timestamp;
  final String targetId;
  final String senderId;
  final String senderName;
  final String extraData;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.timestamp,
    required this.targetId,
    required this.senderId,
    required this.senderName,
    required this.extraData,
  });

  factory AppNotificationItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawType = data['targetType'] ?? 'group';
    NotificationType t = NotificationType.group;
    if (rawType == 'chat') t = NotificationType.chat;
    if (rawType == 'settlement') t = NotificationType.settlementApproval;
    if (rawType == 'reminder') t = NotificationType.paymentReminder;

    return AppNotificationItem(
      id: doc.id,
      title: data['title'] ?? 'Notification',
      subtitle: data['message'] ?? '',
      type: t,
      timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetId: data['targetId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      extraData: data['extraData'] ?? '',
    );
  }
}

class NotificationDispatchService {
  static ServiceAccountCredentials? _credentials;
  static AutoRefreshingAuthClient? _authClient;

  // Single-instance Fast Access Token Generator
  static Future<String?> _getAccessToken() async {
    try {
      if (_credentials == null) {
        final jsonString =
            await rootBundle.loadString('assets/keys/service-account.json');
        final jsonMap = jsonDecode(jsonString);
        _credentials = ServiceAccountCredentials.fromJson(jsonMap);
      }

      if (_authClient == null ||
          DateTime.now().isAfter(_authClient!.credentials.accessToken.expiry.subtract(const Duration(minutes: 5)))) {
        final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
        _authClient = await clientViaServiceAccount(_credentials!, scopes);
      }

      return _authClient?.credentials.accessToken.data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> triggerAlert({
    required FirebaseFirestore firestore,
    required String recipientUid,
    required String senderId,
    required String senderName,
    required String title,
    required String message,
    required String targetType,
    required String targetId,
    String extraData = '',
  }) async {
    if (recipientUid.isEmpty || recipientUid == senderId) return;

    // 1. In-App Notification Record Save (Sheet ke liye)
    await firestore
        .collection('users')
        .doc(recipientUid)
        .collection('notifications')
        .add({
      'recipientId': recipientUid,
      'senderId': senderId,
      'senderName': senderName,
      'title': title,
      'message': message,
      'targetType': targetType,
      'targetId': targetId,
      'extraData': extraData,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Asynchronous FCM Delivery (UI ko block kiye baghair background me dispatch karein)
    _dispatchFcmInBackground(
      firestore: firestore,
      recipientUid: recipientUid,
      title: title,
      message: message,
      targetType: targetType,
      targetId: targetId,
    );
  }

  static void _dispatchFcmInBackground({
    required FirebaseFirestore firestore,
    required String recipientUid,
    required String title,
    required String message,
    required String targetType,
    required String targetId,
  }) async {
    try {
      final userDoc = await firestore.collection('users').doc(recipientUid).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) return;

      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      const projectId = 'expense-tracker-b9ad5';
      final url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

      // Unique collapse key aur tag taake duplicate popup na bane
      final collapseId = '${targetType}_$targetId';

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': message,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'targetType': targetType,
              'targetId': targetId,
            },
            'android': {
              'priority': 'HIGH',
              'collapse_key': collapseId,
              'notification': {
                'channel_id': 'high_importance_channel',
                'tag': collapseId,
                'sound': 'default',
              },
            },
          },
        }),
      );
    } catch (_) {}
  }
}

final globalNotificationsStreamProvider =
    StreamProvider<List<AppNotificationItem>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => AppNotificationItem.fromDoc(d)).toList());
});