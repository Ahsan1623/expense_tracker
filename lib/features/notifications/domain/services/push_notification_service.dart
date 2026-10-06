import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level background function (App close/kill hone par OS isko execute karega)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM notification payload khud Android status bar par display ho jata hai.
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Financial Alerts & Chats',
    description: 'Notifications for transactions, reminders and direct chats.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  bool _isInitialized = false;

  Future<void> initialize(String currentUserId) async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Android 13+ OS Permission Dialog
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    // 2. FCM Authorization
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 3. Local Notifications Setup
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle tap if needed
      },
    );

    await androidImplementation?.createNotificationChannel(_channel);

    // 4. Device Token Firestore par update karna
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUserId).set(
          {'fcmToken': token, 'lastTokenUpdate': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}

    _fcm.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
        'fcmToken': newToken,
      });
    });

    // 5. Sirf Foreground state par Heads-Up Banner Display (Jab app screen par open ho)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;

      final prefs = await SharedPreferences.getInstance();
      final pushEnabled = prefs.getBool('pref_enable_push') ?? true;
      final soundEnabled = prefs.getBool('pref_sound') ?? true;
      final vibrateEnabled = prefs.getBool('pref_vibrate') ?? true;

      if (!pushEnabled) return;

      // Tag aur message ID use karein taake duplicate show na ho
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            playSound: soundEnabled,
            enableVibration: vibrateEnabled,
            icon: '@mipmap/ic_launcher',
            tag: message.messageId,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });
  }
}