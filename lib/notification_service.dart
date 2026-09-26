import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }

  // Notification payloads are displayed by Android while the app is in the
  // background/terminated state. Data-only messages need a local notification.
  if (message.notification == null && message.data.isNotEmpty) {
    await NotificationService.initializeLocalOnly();
    final title = '${message.data['title'] ?? 'إدارة الشكاوى'}';
    final body = '${message.data['body'] ?? 'لديك تحديث جديد.'}';
    await NotificationService.show(
      title: title,
      body: body,
      payload: '${message.data['type'] ?? 'general'}',
    );
  }
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _localInitialized = false;
  static bool _initialized = false;
  static bool _fcmListenersAttached = false;

  static Future<void> initializeLocalOnly() async {
    if (_localInitialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
    );

    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'municipal_operations',
        'إشعارات العمليات',
        description: 'إشعارات الشكاوى والمهام والمزامنة في تطبيق إدارة الشكاوى.',
        importance: Importance.high,
      ),
    );
    await android?.requestNotificationsPermission();

    _localInitialized = true;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    await initializeLocalOnly();

    if (!kIsWeb) {
      try {
        await Firebase.initializeApp();
        final messaging = FirebaseMessaging.instance;
        await messaging.setAutoInitEnabled(true);
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (!_fcmListenersAttached) {
          FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler,
          );
          FirebaseMessaging.onMessage.listen((message) async {
            final notification = message.notification;
            final title = notification?.title ?? message.data['title'];
            final body = notification?.body ?? message.data['body'];
            if (title != null && body != null) {
              await show(
                title: '$title',
                body: '$body',
                payload: '${message.data['type'] ?? 'general'}',
              );
            }
          });
          _fcmListenersAttached = true;
        }

        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _registerToken(token);
        }
        messaging.onTokenRefresh.listen(_registerToken);
      } catch (_) {
        // Local notifications must continue to work even when Firebase has
        // not been configured on this installation yet.
      }
    }

    _initialized = true;
  }

  static Future<void> _registerToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      if (authToken == null || authToken.isEmpty) return;

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/device/fcm-token'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'token': token, 'platform': 'android'}),
          )
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) return;
    } catch (_) {
      // Token registration is retried on the next app start/token refresh.
    }
  }

  static Future<void> show({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    await initializeLocalOnly();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'municipal_operations',
        'إشعارات العمليات',
        channelDescription:
            'إشعارات الشكاوى والمهام والمزامنة في تطبيق إدارة الشكاوى.',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_launcher',
      ),
    );

    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> showSyncCompleted(int count) async {
    if (count <= 0) return;
    await show(
      title: 'إدارة الشكاوى',
      body: 'تمت مزامنة $count عملية بنجاح مع الخادم.',
      payload: 'sync',
    );
  }

  static Future<void> showComplaintCreated({String? number}) async {
    await show(
      title: 'شكوى جديدة',
      body: number == null
          ? 'تم حفظ الشكوى بنجاح.'
          : 'تم حفظ الشكوى رقم $number بنجاح.',
      payload: 'complaint',
    );
  }

  static Future<void> showWorkOrderCreated({String? number}) async {
    await show(
      title: 'مهمة جديدة',
      body: number == null
          ? 'تم حفظ المهمة بنجاح.'
          : 'تم حفظ المهمة رقم $number بنجاح.',
      payload: 'work_order',
    );
  }
}
