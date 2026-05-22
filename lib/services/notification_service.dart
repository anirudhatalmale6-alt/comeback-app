import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> initialize() async {
    await _requestPermissions();
    await _initLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleMessageTap(initial);
  }

  Future<void> _requestPermissions() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {},
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
      'page_alerts',
      'Page Alerts',
      description: 'Urgent page alerts from your employer',
      importance: Importance.max,
      playSound: true,
    ));
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final isPageAlert = data['type'] == 'page_alert';

    if (isPageAlert) {
      _playAlarmSound();
    }

    _showLocalNotification(
      title: message.notification?.title ?? 'Come Back',
      body: message.notification?.body ?? '',
      payload: jsonEncode(data),
      channelId: isPageAlert ? 'page_alerts' : 'default',
      isPageAlert: isPageAlert,
    );
  }

  void _handleMessageTap(RemoteMessage message) {}

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'default',
    bool isPageAlert = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'page_alerts' ? 'Page Alerts' : 'General',
      importance: isPageAlert ? Importance.max : Importance.high,
      priority: isPageAlert ? Priority.max : Priority.high,
      fullScreenIntent: isPageAlert,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> _playAlarmSound() async {
    await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
  }

  Future<String?> getToken() => _fcm.getToken();

  void dispose() {
    _audioPlayer.dispose();
  }
}
