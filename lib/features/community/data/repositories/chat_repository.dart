import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message_model.dart';
import 'package:expense_tracker/features/notifications/domain/services/notifications_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final peerChatMessagesStreamProvider =
    StreamProvider.family<
      List<ChatMessageModel>,
      ({String myUid, String peerUid})
    >((ref, args) {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.getMessagesStream(args.myUid, args.peerUid);
    });

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getChannelId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  Stream<List<ChatMessageModel>> getMessagesStream(String uid1, String uid2) {
    final channelId = getChannelId(uid1, uid2);
    return _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
              .where((msg) => !msg.deletedBy.contains(uid1))
              .toList(),
        );
  }

  Future<void> clearChatHistory({
    required String myUid,
    required String peerUid,
  }) async {
    final channelId = getChannelId(myUid, peerUid);
    final snap = await _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'deletedBy': FieldValue.arrayUnion([myUid]),
      });
    }
    await batch.commit();
  }

  Future<void> sendTextMessage({
    required String senderId,
    required String receiverId,
    required String senderName,
    required String text,
  }) async {
    final channelId = getChannelId(senderId, receiverId);
    final docRef = _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('messages')
        .doc();

    final cleanText = text.trim();
    final effectiveSenderName = senderName.trim().isNotEmpty ? senderName.trim() : 'Friend';

    final msg = ChatMessageModel(
      messageId: docRef.id,
      senderId: senderId,
      senderName: effectiveSenderName,
      content: cleanText,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    await docRef.set(msg.toMap());

    // Notification title directly shows sender's actual display name
    await NotificationDispatchService.triggerAlert(
      firestore: _firestore,
      recipientUid: receiverId,
      senderId: senderId,
      senderName: effectiveSenderName,
      title: effectiveSenderName,
      message: cleanText,
      targetType: 'chat',
      targetId: senderId,
    );
  }

  Future<void> logFinancialMessage({
    required String senderId,
    required String receiverId,
    required String senderName,
    required String description,
    required double amount,
    required MessageType type,
  }) async {
    final channelId = getChannelId(senderId, receiverId);
    final docRef = _firestore
        .collection('direct_channels')
        .doc(channelId)
        .collection('messages')
        .doc();

    final msg = ChatMessageModel(
      messageId: docRef.id,
      senderId: senderId,
      senderName: senderName,
      content: description,
      type: type,
      amount: amount,
      timestamp: DateTime.now(),
    );

    await docRef.set(msg.toMap());
  }
}