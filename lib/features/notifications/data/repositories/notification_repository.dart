import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_notification_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final userNotificationsStreamProvider = StreamProvider<List<AppNotificationModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUserNotifications(user.uid);
});

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AppNotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppNotificationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> sendNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String title,
    required String message,
    required NotificationTargetType targetType,
    required String targetId,
    String extraData = '',
  }) async {
    final docRef = _firestore
        .collection('users')
        .doc(recipientId)
        .collection('notifications')
        .doc();

    final item = AppNotificationModel(
      id: docRef.id,
      recipientId: recipientId,
      senderId: senderId,
      senderName: senderName,
      title: title,
      message: message,
      targetType: targetType,
      targetId: targetId,
      extraData: extraData,
      createdAt: DateTime.now(),
    );

    await docRef.set(item.toMap());
  }

  Future<void> dismissNotification(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> clearAllNotifications(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}