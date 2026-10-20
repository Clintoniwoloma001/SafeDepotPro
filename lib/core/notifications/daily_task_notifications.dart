// © Flatra Tech Ltd. All rights reserved.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local reminders for incomplete daily routine tasks.
class DailyTaskNotifications {
  DailyTaskNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    // Request runtime permission on Android 13+.
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    await _scheduleAll();
    _initialized = true;
  }

  static tz.TZDateTime _localToUtcTz(DateTime local) {
    final utc = local.toUtc();
    return tz.TZDateTime.from(utc, tz.UTC);
  }

  static Future<void> _scheduleAll() async {
    await _plugin.cancelAll();

    const androidDetails = AndroidNotificationDetails(
      'daily_tasks',
      'Daily Tasks',
      channelDescription: 'Reminders for incomplete daily routine tasks.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // In-day incomplete-task alerts.
    for (final hour in const [9, 12, 15]) {
      final now = DateTime.now();
      var scheduled = DateTime(now.year, now.month, now.day, hour, 0);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        1000 + hour,
        'Incomplete daily tasks',
        'Some required daily tasks are still incomplete. Please complete them.',
        _localToUtcTz(scheduled),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // 5:00 PM final daily reminder.
    final now = DateTime.now();
    var fivePm = DateTime(now.year, now.month, now.day, 17, 0);
    if (fivePm.isBefore(now)) {
      fivePm = fivePm.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      1700,
      'Final daily reminder',
      'Have you completed all possible tasks for today? If not, please provide reasons for any incomplete tasks.',
      _localToUtcTz(fivePm),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
