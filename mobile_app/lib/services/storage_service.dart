import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/app_settings.dart';
import '../models/reminder_model.dart';

class StorageService {
  static const _remindersKey = 'saved_reminders_v1';
  static const _settingsKey = 'app_settings_v1';
  static const _deviceIdKey = 'device_unique_session_id_v2';

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  Future<List<ReminderItem>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_remindersKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => ReminderItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          final aMinutes = a.hour * 60 + a.minute;
          final bMinutes = b.hour * 60 + b.minute;
          return aMinutes.compareTo(bMinutes);
        });
    } catch (_) {
      return [];
    }
  }

  Future<void> saveReminders(List<ReminderItem> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(reminders.map((e) => e.toJson()).toList());
    await prefs.setString(_remindersKey, encoded);
  }

  Future<AppSettings> loadSettings({String fallbackTimezone = 'UTC'}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    final resolvedTz = AppConfig.detectFallbackTimezone(fallbackTimezone);

    if (raw == null || raw.isEmpty) {
      return AppSettings(
        backendUrl: AppConfig.backendUrl,
        timezone: resolvedTz,
      );
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = AppSettings.fromJson(decoded);
      return loaded.copyWith(
        backendUrl: AppConfig.backendUrl,
        timezone: loaded.timezone == 'UTC' ? resolvedTz : loaded.timezone,
      );
    } catch (_) {
      return AppSettings(
        backendUrl: AppConfig.backendUrl,
        timezone: resolvedTz,
      );
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
