import 'dart:convert';
import 'dart:typed_data';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder_model.dart';
import 'storage_service.dart';
import 'whatsapp_api_service.dart';

typedef AlarmTapCallback = void Function(Map<String, dynamic> payload);

/// Handles offline native Mobile Alarms, Standard Push Notifications,
/// and automated background WhatsApp message dispatching directly from the device.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _notificationChannelId = 'reminder_standard_channel';
  static const _alarmChannelId = 'reminder_alarm_channel';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  String _deviceTimezone = 'UTC';
  String get deviceTimezone => _deviceTimezone;

  AlarmTapCallback? onAlarmNotificationTapped;

  bool get _supportsMobileNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _supportsAndroidAlarmManager =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    if (!_supportsMobileNotifications) {
      _deviceTimezone = 'UTC';
      tz.setLocalLocation(tz.getLocation('UTC'));
      return;
    }

    try {
      final String detected = await FlutterTimezone.getLocalTimezone();
      _deviceTimezone = detected;
      tz.setLocalLocation(tz.getLocation(detected));
    } catch (_) {
      _deviceTimezone = 'UTC';
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Initialize native Android exact alarm scheduler for background execution
    if (_supportsAndroidAlarmManager) {
      try {
        await AndroidAlarmManager.initialize();
      } catch (_) {}
    }

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

    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  /// Generates a stable positive integer base ID from a reminder UUID.
  static int baseIdFor(String reminderId) =>
      (reminderId.hashCode.abs() % 100000) * 20;

  /// Cancels all local notifications, alarms, and background WhatsApp timers.
  Future<void> cancelReminder(String reminderId) async {
    if (!_supportsMobileNotifications) return;
    try {
      final baseId = baseIdFor(reminderId);

      for (int offset = 0; offset < 20; offset++) {
        await _plugin.cancel(baseId + offset);
      }

      if (_supportsAndroidAlarmManager) {
        for (int offset = 0; offset < 20; offset++) {
          await AndroidAlarmManager.cancel(baseId + offset);
        }
      }
    } catch (_) {}
  }

  /// Schedules local offline Alarm, Notification, AND background WhatsApp auto-send.
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

    // 2. Loud local alarm sound & snooze screen
    if (reminder.alarmEnabled) {
      try {
        await _scheduleChannel(
          reminder: reminder,
          baseOffset: baseId + 8,
          isAlarm: true,
        );
      } catch (_) {}
    }

    // 3. Automated WhatsApp message dispatching directly from device
    if (reminder.whatsappEnabled && _supportsAndroidAlarmManager) {
      try {
        await _scheduleWhatsAppAlarm(reminder, baseId + 16);
      } catch (_) {}
    }
  }

  Future<void> _scheduleWhatsAppAlarm(
    ReminderItem reminder,
    int baseOffset,
  ) async {
    try {
      if (reminder.isRecurring) {
        for (final weekday in reminder.daysOfWeek) {
          final scheduled = _nextInstanceOfWeekdayTime(
            weekday: weekday,
            hour: reminder.hour,
            minute: reminder.minute,
          );
          final exactDateTime = DateTime.fromMillisecondsSinceEpoch(
            scheduled.millisecondsSinceEpoch,
          );

          try {
            await AndroidAlarmManager.oneShotAt(
              exactDateTime,
              baseOffset + weekday,
              whatsappBackgroundDispatcher,
              exact: true,
              wakeup: true,
              rescheduleOnReboot: true,
            );
          } catch (_) {
            try {
              await AndroidAlarmManager.oneShotAt(
                exactDateTime,
                baseOffset + weekday,
                whatsappBackgroundDispatcher,
                exact: false,
                wakeup: true,
                rescheduleOnReboot: true,
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
        );
        if (scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
          final exactDateTime = DateTime.fromMillisecondsSinceEpoch(
            scheduled.millisecondsSinceEpoch,
          );
          try {
            await AndroidAlarmManager.oneShotAt(
              exactDateTime,
              baseOffset,
              whatsappBackgroundDispatcher,
              exact: true,
              wakeup: true,
              rescheduleOnReboot: true,
            );
          } catch (_) {
            try {
              await AndroidAlarmManager.oneShotAt(
                exactDateTime,
                baseOffset,
                whatsappBackgroundDispatcher,
                exact: false,
                wakeup: true,
                rescheduleOnReboot: true,
              );
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
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
              androidScheduleMode: AndroidScheduleMode.inexact,
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
      );
      if (scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
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
              androidScheduleMode: AndroidScheduleMode.inexact,
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
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
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
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
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
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
      additionalFlags: Int32List.fromList([4]),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }
}

/// Standalone background execution entry point called by AndroidAlarmManager
/// when an exact scheduled time hits — even if the phone is locked or app is closed.
@pragma('vm:entry-point')
void whatsappBackgroundDispatcher(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final storage = StorageService();
    final settings = await storage.loadSettings();

    final reminders = await storage.loadReminders();
    ReminderItem? matched;

    for (final r in reminders) {
      final base = NotificationService.baseIdFor(r.id);
      if (id >= base && id <= base + 24) {
        matched = r;
        break;
      }
    }

    if (matched != null && matched.isEnabled && matched.whatsappEnabled) {
      final msg = matched.customWhatsAppMessage.isNotEmpty
          ? matched.customWhatsAppMessage
          : '⏰ *Reminder: ${matched.title}*\n🕒 Scheduled Time: ${matched.formattedTime12}${matched.note.isNotEmpty ? '\n📝 ${matched.note}' : ''}';

      final targetPhone =
          matched.resolvePhoneNumber(settings.defaultWhatsAppNumber);

      final api = WhatsAppApiService();
      await api.sendInstantWhatsApp(
        settings: settings,
        phoneNumber: targetPhone,
        message: msg,
        title: matched.title,
      );

      // If it's a recurring weekly reminder, reschedule next week's occurrence
      if (matched.isRecurring) {
        await NotificationService.instance.scheduleReminder(matched);
      }
    }
  } catch (_) {}
}
