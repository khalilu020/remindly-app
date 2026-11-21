import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
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

  static const _notificationChannelId = 'reminder_standard_channel';
  static const _alarmChannelId = 'reminder_alarm_channel';

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
    } catch (_) {}

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
            } catch (_) {}
          }
        },
      );
    } catch (_) {}

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
    } catch (_) {}
  }

  /// Requests notification and exact alarm permissions at runtime.
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
    } catch (_) {}
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
    } catch (_) {}
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
      } catch (_) {}
    }

    // 2. Loud local alarm sound
    if (reminder.alarmEnabled) {
      try {
        await _scheduleChannel(
          reminder: reminder,
          baseOffset: baseId + 8,
          isAlarm: true,
        );
      } catch (_) {}
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
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (_) {
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
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
          } catch (_) {}
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
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {
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
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          } catch (_) {}
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
            UILocalNotificationDateInterpretation.absoluteTime,
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
              UILocalNotificationDateInterpretation.absoluteTime,
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
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Instantly schedules a test Notification and Alarm 5 seconds from now.
  Future<void> testAlarmAndNotification() async {
    if (!_supportsMobileNotifications) return;
    final now = tz.TZDateTime.now(tz.local);
    final scheduledNotif = now.add(const Duration(seconds: 5));
    final scheduledAlarm = now.add(const Duration(seconds: 7));

    try {
      await _plugin.zonedSchedule(
        888801,
        '🔔 Remindly Notification Test',
        'Push notification banner is working properly!',
        scheduledNotif,
        _standardNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          888801,
          '🔔 Remindly Notification Test',
          'Push notification banner is working properly!',
          scheduledNotif,
          _standardNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }

    try {
      await _plugin.zonedSchedule(
        888802,
        '⏰ Remindly Loud Alarm Test',
        'Offline Alarm is ringing! Tap to dismiss or snooze.',
        scheduledAlarm,
        _alarmDetails(),
        payload: jsonEncode({
          'id': 'test_alarm_id',
          'title': 'Remindly Loud Alarm Test',
          'note': 'Offline Alarm is ringing! Tap to dismiss or snooze.',
          'time': 'Test Alert',
          'category': 'Test',
          'isAlarm': true,
        }),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          888802,
          '⏰ Remindly Loud Alarm Test',
          'Offline Alarm is ringing! Tap to dismiss or snooze.',
          scheduledAlarm,
          _alarmDetails(),
          payload: jsonEncode({
            'id': 'test_alarm_id',
            'title': 'Remindly Loud Alarm Test',
            'note': 'Offline Alarm is ringing! Tap to dismiss or snooze.',
            'time': 'Test Alert',
            'category': 'Test',
            'isAlarm': true,
          }),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }
}
