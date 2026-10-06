import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/features/auth/presentation/controllers/auth_controller.dart';
import 'package:expense_tracker/features/notifications/data/repositories/notification_repository.dart';
import 'notifications_sheet.dart';

class NotificationBellIcon extends ConsumerWidget {
  const NotificationBellIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final notificationsAsync = ref.watch(userNotificationsStreamProvider);

    final unreadCount = notificationsAsync.value?.length ?? 0;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1E293B)),
          tooltip: 'Notifications',
          onPressed: () {
            if (user != null) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => NotificationSheet(userId: user.uid),
              );
            }
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}