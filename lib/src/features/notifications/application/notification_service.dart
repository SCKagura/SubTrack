import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize Timezone — must run on the main isolate so the DB
    //    is visible to all subsequent tz.getLocation() calls.
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    // flutter_timezone v5+ returns a TimezoneInfo object; .identifier is the IANA string.
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    // 2. Initialize Notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      return await _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      return await androidImplementation?.requestNotificationsPermission() ??
          false;
    }
    return false;
  }

  Future<void> scheduleSubscriptionReminder(Subscription sub) async {
    // If user disabled reminder for this subscription, ensure any existing is cancelled.
    if (!sub.hasReminder) {
      await cancelReminder(sub.id);
      return;
    }

    final int baseId = sub.id.hashCode;

    // We schedule 3 notifications as requested: 7 days before, 1 day before, and on the day.
    
    // 1. 7 Days Before
    await _scheduleOffsetReminder(
      baseId + 7,
      sub,
      7,
      'อีก 1 สัปดาห์จะถึงกำหนดชำระ: ${sub.name}',
      'บริการ ${sub.name} จะถึงกำหนดชำระ ฿${sub.price} ในอีก 7 วันครับ',
    );

    // 2. 3 Days Before
    await _scheduleOffsetReminder(
      baseId + 3,
      sub,
      3,
      'อีก 3 วันจะถึงกำหนดชำระ: ${sub.name}',
      'บริการ ${sub.name} จะถึงกำหนดชำระ ฿${sub.price} ในอีก 3 วันครับ',
    );

    // 3. 1 Day Before
    await _scheduleOffsetReminder(
      baseId + 1,
      sub,
      1,
      'พรุ่งนี้จะถึงกำหนดชำระ: ${sub.name}',
      'บริการ ${sub.name} มีนัดชำระเงิน ฿${sub.price} ในวันพรุ่งนี้ครับ',
    );

    // 4. On the Day
    await _scheduleOffsetReminder(
      baseId,
      sub,
      0,
      'วันนี้ถึงกำหนดชำระ: ${sub.name}',
      'ถึงกำหนดชำระเงิน ฿${sub.price} สำหรับ ${sub.name} แล้ววันนี้ครับ',
    );
  }

  Future<void> _scheduleOffsetReminder(
    int id,
    Subscription sub,
    int daysPrior,
    String title,
    String body,
  ) async {
    final reminderDate = sub.nextPaymentDate.subtract(Duration(days: daysPrior));
    final scheduledDate = tz.TZDateTime(
      tz.local,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9, // 9:00 AM
    );

    // If the date is in the past, don't schedule
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _zonedScheduleSafe(
      id,
      title,
      body,
      scheduledDate,
    );
  }

  /// Schedules a notification, automatically falling back to inexact alarms
  /// when exact alarm permission is denied or the permission check itself fails.
  Future<void> _zonedScheduleSafe(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'subscription_reminders',
        'Subscription Reminders',
        channelDescription: 'Notifications for upcoming subscription payments',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    // Try exact alarm first; fall back to inexact on permission denial.
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: await _resolveScheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        // Device denied exact alarms — retry with inexact, which always works.
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Checks whether the system grants exact alarm scheduling permission.
  /// Returns [inexactAllowWhileIdle] as a safe fallback on any error.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    if (Platform.isAndroid) {
      try {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final canExact =
            await androidImpl?.canScheduleExactNotifications() ?? false;
        return canExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;
      } catch (_) {
        // Permission check API unavailable or threw — use inexact safely.
        return AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  Future<void> cancelReminder(String subId) async {
    final int baseId = subId.hashCode;
    await _notificationsPlugin.cancel(baseId);
    await _notificationsPlugin.cancel(baseId + 1);
    await _notificationsPlugin.cancel(baseId + 3);
    await _notificationsPlugin.cancel(baseId + 7);
  }

  /// Fires an immediate test notification to verify the full pipeline.
  Future<void> testNotification() async {
    await _notificationsPlugin.show(
      999999,
      '🔔 ทดสอบการแจ้งเตือน',
      'ระบบแจ้งเตือนทำงานปกติ ✅',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'subscription_reminders',
          'Subscription Reminders',
          channelDescription:
              'Notifications for upcoming subscription payments',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
