import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  final bool enablePush;
  final bool soundEnabled;
  final bool vibrateEnabled;
  final bool chatAlerts;
  final bool settlementAlerts;

  const NotificationPreferences({
    this.enablePush = true,
    this.soundEnabled = true,
    this.vibrateEnabled = true,
    this.chatAlerts = true,
    this.settlementAlerts = true,
  });

  NotificationPreferences copyWith({
    bool? enablePush,
    bool? soundEnabled,
    bool? vibrateEnabled,
    bool? chatAlerts,
    bool? settlementAlerts,
  }) {
    return NotificationPreferences(
      enablePush: enablePush ?? this.enablePush,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrateEnabled: vibrateEnabled ?? this.vibrateEnabled,
      chatAlerts: chatAlerts ?? this.chatAlerts,
      settlementAlerts: settlementAlerts ?? this.settlementAlerts,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationPreferences> {
  NotificationSettingsNotifier() : super(const NotificationPreferences()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationPreferences(
      enablePush: prefs.getBool('pref_enable_push') ?? true,
      soundEnabled: prefs.getBool('pref_sound') ?? true,
      vibrateEnabled: prefs.getBool('pref_vibrate') ?? true,
      chatAlerts: prefs.getBool('pref_chat_alerts') ?? true,
      settlementAlerts: prefs.getBool('pref_settlement_alerts') ?? true,
    );
  }

  Future<void> updateSettings({
    bool? enablePush,
    bool? soundEnabled,
    bool? vibrateEnabled,
    bool? chatAlerts,
    bool? settlementAlerts,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      enablePush: enablePush,
      soundEnabled: soundEnabled,
      vibrateEnabled: vibrateEnabled,
      chatAlerts: chatAlerts,
      settlementAlerts: settlementAlerts,
    );

    if (enablePush != null) await prefs.setBool('pref_enable_push', enablePush);
    if (soundEnabled != null) await prefs.setBool('pref_sound', soundEnabled);
    if (vibrateEnabled != null) await prefs.setBool('pref_vibrate', vibrateEnabled);
    if (chatAlerts != null) await prefs.setBool('pref_chat_alerts', chatAlerts);
    if (settlementAlerts != null) await prefs.setBool('pref_settlement_alerts', settlementAlerts);
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationPreferences>((ref) {
  return NotificationSettingsNotifier();
});