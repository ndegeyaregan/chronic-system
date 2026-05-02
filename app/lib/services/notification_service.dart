import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await NotificationService.showLocalNotification(message);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'sanlam_chronic_high',
    'SanCare+',
    description: 'Notifications for medication reminders and appointments.',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _medsChannel =
      AndroidNotificationChannel(
    'sanlam_meds',
    'Medication Reminders',
    description: 'Daily medication reminders',
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    if (!kIsWeb) {
      tzdata.initializeTimeZones();
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    if (!kIsWeb) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_medsChannel);
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen(showLocalNotification);
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (_) {}
  }

  /// Show an immediate local notification.
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Schedule a daily recurring medication reminder.
  static Future<void> scheduleMedicationReminder({
    required int id,
    required String medicationName,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _local.zonedSchedule(
      id,
      '💊 Medication Reminder',
      'Time to take your $medicationName',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _medsChannel.id,
          _medsChannel.name,
          channelDescription: _medsChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule a one-shot local notification at a specific [when] time.
  /// Used by the cycle tracker for period/ovulation/fertile-window reminders.
  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    if (kIsWeb) return;
    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _local.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Cancel a single notification by id.
  static Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _local.cancel(id);
  }

  /// Cancel all scheduled and shown notifications.
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _local.cancelAll();
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _local.show(
      message.hashCode,
      notification.title ?? 'SanCare+',
      notification.body ?? '',
      details,
    );
  }

  static Future<String?> getDeviceToken() async {
    return FirebaseMessaging.instance.getToken();
  }

  static Future<void> scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await show(id: id, title: title, body: body);
  }
}
