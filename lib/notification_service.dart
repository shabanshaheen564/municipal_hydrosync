import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

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

    _initialized = true;
  }

  static Future<void> show({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    await initialize();

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
