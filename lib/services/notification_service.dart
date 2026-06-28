import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  static void Function(Map<String, dynamic> data)? onNotificationTap;

  Future<void> initialize() async {
    await _requestPermissions();
    await _initLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleMessageTap(initial);

    _fcm.onTokenRefresh.listen(_onTokenRefresh);
  }

  static String? _pendingTokenRefreshUid;
  static void Function(String uid, String token)? onTokenRefresh;

  void _onTokenRefresh(String token) {
    if (_pendingTokenRefreshUid != null && onTokenRefresh != null) {
      onTokenRefresh!(_pendingTokenRefreshUid!, token);
    }
  }

  static void setCurrentUid(String uid) {
    _pendingTokenRefreshUid = uid;
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
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
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

    await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'New chat message notifications',
      importance: Importance.high,
      playSound: true,
    ));
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      onNotificationTap?.call(data);
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final isPageAlert = data['type'] == 'page_alert';

    if (isPageAlert) {
      _playAlarmSound();
    }

    final isChatMessage = data['type'] == 'chat_message';

    _showLocalNotification(
      title: message.notification?.title ?? 'Come Back',
      body: message.notification?.body ?? '',
      payload: jsonEncode(data),
      channelId: isPageAlert
          ? 'page_alerts'
          : isChatMessage
              ? 'chat_messages'
              : 'chat_messages',
      isPageAlert: isPageAlert,
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    if (data.isNotEmpty) {
      onNotificationTap?.call(data);
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'chat_messages',
    bool isPageAlert = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'page_alerts' ? 'Page Alerts' : 'Chat Messages',
      importance: isPageAlert ? Importance.max : Importance.high,
      priority: isPageAlert ? Priority.max : Priority.high,
      fullScreenIntent: isPageAlert,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> _playAlarmSound() async {
    await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
  }

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      return null;
    }
  }

  Future<String?> getAPNSToken() async {
    try {
      return await _fcm.getAPNSToken();
    } catch (_) {
      return null;
    }
  }

  Future<String> getPermissionStatus() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      return settings.authorizationStatus.toString();
    } catch (e) {
      return 'error: $e';
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
