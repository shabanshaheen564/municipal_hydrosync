import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

bool _validNotificationText(String? value) {
  if (value == null) return false;
  final text = value.trim();
  if (text.isEmpty) return false;
  return true;
}

bool get _isMobileNotificationPlatform =>
    !kIsWeb &&
    Platform.environment['FLUTTER_TEST'] != 'true' &&
    (Platform.isAndroid || Platform.isIOS);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (_isMobileNotificationPlatform) {
    await Firebase.initializeApp();
  }

  if (message.notification == null && message.data.isNotEmpty) {
    await NotificationService.initializeLocalOnly();
    final title = '${message.data['title'] ?? 'إدارة الشكاوى'}';
    final body = '${message.data['body'] ?? 'لديك تحديث جديد.'}';
    if (_validNotificationText(title) && _validNotificationText(body)) {
      await NotificationService.show(
        title: title,
        body: body,
        payload: '${message.data['type'] ?? 'general'}',
      );
    }
  }
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _localInitialized = false;
  static bool _initialized = false;
  static Future<void>? _initializationFuture;
  static bool _fcmListenersAttached = false;
  static String? _lastInitializationError;

  static String? get lastInitializationError => _lastInitializationError;

  static bool get _isMobilePlatform => _isMobileNotificationPlatform;

  static Future<void> initializeLocalOnly() async {
    if (!_isMobilePlatform) return;
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

  static Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializationFuture ??= _initializeInternal();
  }

  static Future<void> _initializeInternal() async {
    try {
      await initializeLocalOnly();

      if (_isMobileNotificationPlatform) {
        try {
          await Firebase.initializeApp();
          final messaging = FirebaseMessaging.instance;
          await messaging.setAutoInitEnabled(true);

          final settings = await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
          debugPrint(
            'FCM notification authorization: ${settings.authorizationStatus}',
          );

          if (!_fcmListenersAttached) {
            FirebaseMessaging.onBackgroundMessage(
              firebaseMessagingBackgroundHandler,
            );
            FirebaseMessaging.onMessage.listen((message) async {
              final notification = message.notification;
              final title = notification?.title ?? message.data['title'];
              final body = notification?.body ?? message.data['body'];
              if (_validNotificationText(title?.toString()) &&
                  _validNotificationText(body?.toString())) {
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
          debugPrint(
            token == null || token.isEmpty
                ? 'FCM token: unavailable'
                : 'FCM token: received (${token.length} chars)',
          );
          if (token != null && token.isNotEmpty) {
            await _registerToken(token);
          }
          messaging.onTokenRefresh.listen(_registerToken);
        } on FirebaseException catch (e) {
          _lastInitializationError =
              'Firebase ${e.code}: ${e.message ?? 'unknown error'}';
          debugPrint(
            'NotificationService Firebase error: $_lastInitializationError',
          );
        } on PlatformException catch (e) {
          _lastInitializationError =
              'Platform ${e.code}: ${e.message ?? 'unknown error'}';
          debugPrint(
            'NotificationService platform error: $_lastInitializationError',
          );
        } catch (e) {
          _lastInitializationError = '$e';
          debugPrint('NotificationService initialization error: $e');
        }
      }
    } catch (e) {
      _lastInitializationError = '$e';
      debugPrint('NotificationService startup error: $e');
    } finally {
      _initialized = true;
      _initializationFuture = null;
    }
  }

  static Future<void> registerCurrentToken() async {
    if (!_isMobilePlatform) return;

    try {
      if (!_initialized) await initialize();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('FCM current token registration error: $e');
    }
  }

  static Future<void> unregisterCurrentToken() async {
    if (!_initialized || !_isMobilePlatform) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      if (authToken == null || authToken.isEmpty) return;

      await http
          .delete(
            Uri.parse('${AppConfig.apiBaseUrl}/device/fcm-token'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'token': token}),
          )
          .timeout(AppConfig.requestTimeout);
    } catch (_) {
      // Logout must still complete if token cleanup is temporarily unavailable.
    }
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

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'FCM token registration failed: HTTP ${response.statusCode} ${response.body}',
        );
        return;
      }
      debugPrint('FCM token registered successfully.');
    } catch (e) {
      debugPrint('FCM token registration error: $e');
    }
  }

  static Future<void> show({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    if (!_validNotificationText(title) || !_validNotificationText(body)) return;
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
