import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/features/notifications/domain/services/notification_settings_service.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Notification & Sound',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E293B)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.notifications_active_rounded, color: Colors.teal.shade800, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notifications',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Receive real-time alerts on your device',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: settings.enablePush,
                  activeTrackColor: Colors.teal.shade700,
                  onChanged: (val) => notifier.updateSettings(enablePush: val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Alert Style & Ringtones',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.volume_up_rounded, color: Colors.indigo.shade700),
                  title: const Text('Play Sound', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Play sound on incoming alert', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: Switch.adaptive(
                    value: settings.soundEnabled,
                    activeTrackColor: Colors.teal.shade700,
                    onChanged: settings.enablePush
                        ? (val) => notifier.updateSettings(soundEnabled: val)
                        : null,
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade100),
                ListTile(
                  leading: Icon(Icons.vibration_rounded, color: Colors.amber.shade800),
                  title: const Text('Vibration', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Vibrate phone on incoming transaction', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: Switch.adaptive(
                    value: settings.vibrateEnabled,
                    activeTrackColor: Colors.teal.shade700,
                    onChanged: settings.enablePush
                        ? (val) => notifier.updateSettings(vibrateEnabled: val)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Alert Categories',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue.shade700),
                  title: const Text('1-to-1 Chat Messages', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Alert when a friend sends a message', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: Switch.adaptive(
                    value: settings.chatAlerts,
                    activeTrackColor: Colors.teal.shade700,
                    onChanged: settings.enablePush
                        ? (val) => notifier.updateSettings(chatAlerts: val)
                        : null,
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade100),
                ListTile(
                  leading: Icon(Icons.handshake_rounded, color: Colors.teal.shade700),
                  title: const Text('Settlements & Reminders', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Alert when a settlement is requested or confirmed', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: Switch.adaptive(
                    value: settings.settlementAlerts,
                    activeTrackColor: Colors.teal.shade700,
                    onChanged: settings.enablePush
                        ? (val) => notifier.updateSettings(settlementAlerts: val)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}