import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../config/app_config.dart';
import '../models/reminder_model.dart';

typedef AlarmTapCallback = void Function(Map<String, dynamic> payload);

/// Handles offline native Mobile Alarms and Standard Push Notifications
/// directly through Android's AlarmManager without any external background services.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Distinct channel IDs force Android OS to create fresh max-importance channels
  static const _notificationChannelId = 'remindly_standard_channel_v4';
  static const _alarmChannelId = 'remindly_loud_alarm_channel_v4';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  String _deviceTimezone = 'Asia/Karachi';
  String get deviceTimezone => _deviceTimezone;

  AlarmTapCallback? onAlarmNotificationTapped;

  bool get _supportsMobileNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    tz_data.initializeTimeZones();

    // 1. Resolve true local timezone matching the device's clock offset
    String detectedTz = 'Asia/Karachi';
    try {
      if (_supportsMobileNotifications) {
        final platformTz = await FlutterTimezone.getLocalTimezone();
        if (platformTz.isNotEmpty &&
            platformTz.contains('/') &&
            tz.timeZoneDatabase.locations.containsKey(platformTz)) {
          detectedTz = platformTz;
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to detect timezone: $e');
    }

    // Verify against timezone database with offset fallback
    if (!tz.timeZoneDatabase.locations.containsKey(detectedTz)) {
      detectedTz = AppConfig.detectFallbackTimezone(detectedTz);
    }

    _deviceTimezone = detectedTz;
    try {
      final loc = tz.getLocation(detectedTz);
      tz.setLocalLocation(loc);
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2. Initialize FlutterLocalNotificationsPlugin safely
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = jsonDecode(response.payload!) as Map<String, dynamic>;
              if (data['isAlarm'] == true) {
                onAlarmNotificationTapped?.call(data);
              }
            } catch (e) {
              debugPrint('[NotificationService] Error parsing response payload: $e');
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[NotificationService] Plugin init error: $e');
    }

    // 3. Create high-priority notification channels on Android
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      const alarmChannel = AndroidNotificationChannel(
        _alarmChannelId,
        'Reminder Alarms',
        description: 'High-priority loud alarm alerts for scheduled activities',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      const standardChannel = AndroidNotificationChannel(
        _notificationChannelId,
        'Activity Notifications',
        description: 'Standard reminder notifications for scheduled activities',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      await androidImpl?.createNotificationChannel(alarmChannel);
      await androidImpl?.createNotificationChannel(standardChannel);
    } catch (e) {
      debugPrint('[NotificationService] Channel creation error: $e');
    }
  }

  /// Checks whether exact alarms can be scheduled on Android 12+ (API 31+).
  Future<bool> canScheduleExactNotifications() async {
    if (!_supportsMobileNotifications) return true;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final result = await androidImpl.canScheduleExactNotifications();
        return result ?? true;
      }
    } catch (_) {}
    return true;
  }

  /// Checks whether notifications are allowed by the user.
  Future<bool> areNotificationsEnabled() async {
    if (!_supportsMobileNotifications) return true;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final result = await androidImpl.areNotificationsEnabled();
        return result ?? true;
      }
    } catch (_) {}
    return true;
  }

  /// Requests notification permission on Android 13+ (API 33+).
  Future<bool?> requestNotificationsPermission() async {
    if (!_supportsMobileNotifications) return true;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidImpl?.requestNotificationsPermission();
    } catch (_) {
      return null;
    }
  }

  /// Requests exact alarms permission by opening system settings on Android 12+.
  Future<void> requestExactAlarmsPermission() async {
    if (!_supportsMobileNotifications) return;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[NotificationService] requestExactAlarmsPermission error: $e');
    }
  }

  /// Requests all necessary permissions at runtime.
  Future<void> requestPermissions() async {
    if (!_supportsMobileNotifications) return;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();
        final canExact = await androidImpl.canScheduleExactNotifications();
        if (canExact == false) {
          await androidImpl.requestExactAlarmsPermission();
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] requestPermissions error: $e');
    }
  }

  /// Generates a stable positive integer base ID from a reminder UUID.
  static int baseIdFor(String reminderId) =>
      (reminderId.hashCode.abs() % 100000) * 20;

  /// Cancels all local notifications and alarms for a reminder.
  Future<void> cancelReminder(String reminderId) async {
    if (!_supportsMobileNotifications) return;
    try {
      final baseId = baseIdFor(reminderId);
      for (int offset = 0; offset < 20; offset++) {
        await _plugin.cancel(baseId + offset);
      }
    } catch (e) {
      debugPrint('[NotificationService] cancelReminder error: $e');
    }
  }

  /// Schedules local offline Alarm and Notification.
  Future<void> scheduleReminder(ReminderItem reminder) async {
    if (!_supportsMobileNotifications) return;
    try {
      await cancelReminder(reminder.id);
    } catch (_) {}

    if (!reminder.isEnabled) return;
    final baseId = baseIdFor(reminder.id);

    // 1. Local banner notification
    if (reminder.notificationEnabled) {
      try {
        await _scheduleChannel(
          reminder: reminder,
          baseOffset: baseId,
          isAlarm: false,
        );
      } catch (e) {
        debugPrint('[NotificationService] Schedule notification error: $e');
      }
    }

    // 2. Loud local alarm sound
    if (reminder.alarmEnabled) {
      try {
        await _scheduleChannel(
          reminder: reminder,
          baseOffset: baseId + 8,
          isAlarm: true,
        );
      } catch (e) {
        debugPrint('[NotificationService] Schedule alarm error: $e');
      }
    }
  }

  Future<void> _scheduleChannel({
    required ReminderItem reminder,
    required int baseOffset,
    required bool isAlarm,
  }) async {
    final details = isAlarm ? _alarmDetails() : _standardNotificationDetails();
    final title =
        isAlarm ? '⏰ ALARM: ${reminder.title}' : '🔔 ${reminder.title}';
    final body = reminder.note.isNotEmpty
        ? reminder.note
        : 'Scheduled for ${reminder.formattedTime12} (${reminder.category})';

    final payload = jsonEncode({
      'id': reminder.id,
      'title': reminder.title,
      'note': reminder.note,
      'time': reminder.formattedTime12,
      'category': reminder.category,
      'isAlarm': isAlarm,
    });

    if (reminder.isRecurring) {
      for (final weekday in reminder.daysOfWeek) {
        final scheduled = _nextInstanceOfWeekdayTime(
          weekday: weekday,
          hour: reminder.hour,
          minute: reminder.minute,
        );
        try {
          await _plugin.zonedSchedule(
            baseOffset + weekday,
            title,
            body,
            scheduled,
            details,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.wallClockTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e) {
          debugPrint(
              '[NotificationService] Exact schedule failed for weekday $weekday ($e). Falling back to inexact...');
          try {
            await _plugin.zonedSchedule(
              baseOffset + weekday,
              title,
              body,
              scheduled,
              details,
              payload: payload,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.wallClockTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
          } catch (fallbackError) {
            debugPrint(
                '[NotificationService] Inexact fallback also failed: $fallbackError');
          }
        }
      }
    } else if (reminder.oneTimeDate != null) {
      final date = reminder.oneTimeDate!;
      final scheduled = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        reminder.hour,
        reminder.minute,
        0,
      );
      final now = tz.TZDateTime.now(tz.local);
      if (scheduled.isAfter(now)) {
        try {
          await _plugin.zonedSchedule(
            baseOffset,
            title,
            body,
            scheduled,
            details,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.wallClockTime,
          );
        } catch (e) {
          debugPrint(
              '[NotificationService] Exact one-time schedule failed ($e). Falling back to inexact...');
          try {
            await _plugin.zonedSchedule(
              baseOffset,
              title,
              body,
              scheduled,
              details,
              payload: payload,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.wallClockTime,
            );
          } catch (fallbackError) {
            debugPrint(
                '[NotificationService] Inexact fallback failed: $fallbackError');
          }
        }
      }
    }
  }

  /// Snoozes an active alarm by [minutes] (default 5 minutes).
  Future<void> snoozeAlarm({
    required String title,
    required String note,
    int minutes = 5,
  }) async {
    if (!_supportsMobileNotifications) return;
    final snoozeTime =
        tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    final payload = jsonEncode({
      'title': title,
      'note': note,
      'time': 'Snoozed',
      'isAlarm': true,
    });

    try {
      await _plugin.zonedSchedule(
        999900 + (DateTime.now().millisecondsSinceEpoch % 99),
        '⏰ SNOOZED ALARM: $title',
        note.isNotEmpty ? note : 'Snooze ended — time for your activity!',
        snoozeTime,
        _alarmDetails(),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          999900 + (DateTime.now().millisecondsSinceEpoch % 99),
          '⏰ SNOOZED ALARM: $title',
          note.isNotEmpty ? note : 'Snooze ended — time for your activity!',
          snoozeTime,
          _alarmDetails(),
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
        );
      } catch (_) {}
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      0,
    );

    if (scheduled.weekday == weekday &&
        scheduled.isAfter(now.add(const Duration(seconds: 5)))) {
      return scheduled;
    }

    while (scheduled.weekday != weekday ||
        !scheduled.isAfter(now.add(const Duration(seconds: 5)))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  NotificationDetails _standardNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      'Activity Notifications',
      channelDescription:
          'Standard reminder notifications for scheduled activities',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  NotificationDetails _alarmDetails() {
    final androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      'Reminder Alarms',
      channelDescription:
          'High-priority loud alarm alerts for scheduled activities',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      enableVibration: true,
      vibrationPattern:
          Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Immediately shows a test push notification with 0 seconds delay.
  Future<void> showInstantNotification() async {
    if (!_supportsMobileNotifications) return;
    try {
      await _plugin.show(
        888801,
        '🔔 Remindly Notification Test',
        'Push notification banner is active and working properly!',
        _standardNotificationDetails(),
      );
    } catch (e) {
      debugPrint('[NotificationService] showInstantNotification error: $e');
    }
  }

  /// Immediately sounds a test alarm notification with 0 seconds delay.
  Future<void> showInstantAlarm() async {
    if (!_supportsMobileNotifications) return;
    try {
      await _plugin.show(
        888802,
        '⏰ Remindly Loud Alarm Test',
        'Offline Alarm is ringing! Tap to dismiss or snooze.',
        _alarmDetails(),
        payload: jsonEncode({
          'id': 'instant_test_alarm_id',
          'title': 'Remindly Loud Alarm Test',
          'note': 'Offline Alarm is ringing! Tap to dismiss or snooze.',
          'time': 'Instant Alert',
          'category': 'Test',
          'isAlarm': true,
        }),
      );
    } catch (e) {
      debugPrint('[NotificationService] showInstantAlarm error: $e');
    }
  }

  /// Schedules a test Notification and Alarm [seconds] from now with exact timing.
  Future<void> testDelayedAlarmAndNotification({int seconds = 5}) async {
    if (!_supportsMobileNotifications) return;
    final now = tz.TZDateTime.now(tz.local);
    final scheduledNotif = now.add(Duration(seconds: seconds));
    final scheduledAlarm = now.add(Duration(seconds: seconds + 2));

    try {
      await _plugin.zonedSchedule(
        888811,
        '🔔 Remindly Notification Test',
        'Delayed push notification banner fired on time!',
        scheduledNotif,
        _standardNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
      );
    } catch (e) {
      debugPrint('[NotificationService] Delayed notif exact error: $e');
      try {
        await _plugin.zonedSchedule(
          888811,
          '🔔 Remindly Notification Test',
          'Delayed push notification banner fired on time!',
          scheduledNotif,
          _standardNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
        );
      } catch (_) {}
    }

    try {
      await _plugin.zonedSchedule(
        888812,
        '⏰ Remindly Loud Alarm Test',
        'Offline Alarm is ringing! Tap to dismiss or snooze.',
        scheduledAlarm,
        _alarmDetails(),
        payload: jsonEncode({
          'id': 'delayed_test_alarm_id',
          'title': 'Remindly Loud Alarm Test',
          'note': 'Offline Alarm is ringing! Tap to dismiss or snooze.',
          'time': 'Test Alert',
          'category': 'Test',
          'isAlarm': true,
        }),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
      );
    } catch (e) {
      debugPrint('[NotificationService] Delayed alarm exact error: $e');
      try {
        await _plugin.zonedSchedule(
          888812,
          '⏰ Remindly Loud Alarm Test',
          'Offline Alarm is ringing! Tap to dismiss or snooze.',
          scheduledAlarm,
          _alarmDetails(),
          payload: jsonEncode({
            'id': 'delayed_test_alarm_id',
            'title': 'Remindly Loud Alarm Test',
            'note': 'Offline Alarm is ringing! Tap to dismiss or snooze.',
            'time': 'Test Alert',
            'category': 'Test',
            'isAlarm': true,
          }),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
        );
      } catch (_) {}
    }
  }

  /// Legacy helper method for backward compatibility
  Future<void> testAlarmAndNotification() =>
      testDelayedAlarmAndNotification(seconds: 5);
}
