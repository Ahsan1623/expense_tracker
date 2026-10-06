import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:expense_tracker/features/notifications/data/models/app_notification_model.dart';
import 'package:expense_tracker/features/notifications/data/repositories/notification_repository.dart';
import 'package:expense_tracker/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:expense_tracker/features/community/presentation/screens/peer_chat_screen.dart';
import 'package:expense_tracker/features/auth/data/models/user_model.dart';

class NotificationSheet extends ConsumerWidget {
  final String userId;

  const NotificationSheet({super.key, required this.userId});

  void _handleNotificationTap(
  BuildContext context,
  WidgetRef ref,
  AppNotificationModel item,
) async {
  final nav = Navigator.of(context);

  // 1. Sheet close karein
  nav.pop();

  // 2. Notification record clear karein
  await ref.read(notificationRepositoryProvider).dismissNotification(userId, item.id);

  // 3. Screen navigation
  if (item.targetType == NotificationTargetType.group) {
    nav.push(
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(
          groupId: item.targetId,
          initialName: item.extraData.isNotEmpty ? item.extraData : 'Shared Group',
        ),
      ),
    );
  } else if (item.targetType == NotificationTargetType.chat) {
    // Sender ka actual profile data fetch karein
    final peerUid = item.senderId.isNotEmpty ? item.senderId : item.targetId;
    final userSnap = await FirebaseFirestore.instance.collection('users').doc(peerUid).get();
    
    UserModel peer;
    if (userSnap.exists) {
      peer = UserModel.fromMap(userSnap.data()!, userSnap.id);
    } else {
      peer = UserModel(
        uid: peerUid,
        email: '',
        displayName: item.senderName.isNotEmpty ? item.senderName : 'Friend',
        createdAt: DateTime.now(),
      );
    }

    nav.push(
      MaterialPageRoute(
        builder: (context) => PeerChatScreen(peerUser: peer),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsStreamProvider);

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications & Alerts',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(notificationRepositoryProvider).clearAllNotifications(userId);
                  },
                  child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: notificationsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text(
                            'No new notifications',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      IconData icon = Icons.notifications_rounded;
                      Color iconColor = Colors.teal;
                      if (item.targetType == NotificationTargetType.chat) {
                        icon = Icons.chat_bubble_outline_rounded;
                        iconColor = Colors.blue;
                      } else if (item.targetType == NotificationTargetType.group) {
                        icon = Icons.groups_3_rounded;
                        iconColor = Colors.teal;
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withValues(alpha: 0.12),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.message, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(item.createdAt),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          onPressed: () {
                            ref.read(notificationRepositoryProvider).dismissNotification(userId, item.id);
                          },
                        ),
                        onTap: () => _handleNotificationTap(context, ref, item),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, stack) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}