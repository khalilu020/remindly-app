import 'package:flutter/material.dart';

class ReminderItem {
  final String id;
  final String title;
  final String note;
  final String category;

  /// Time in 24-hour "HH:mm" format (e.g., "07:30", "18:45")
  final int hour;
  final int minute;

  /// One-time date (nullable). Used when [daysOfWeek] is empty.
  final DateTime? oneTimeDate;

  /// Weekly timetable days using ISO weekday numbering: 1=Mon ... 7=Sun.
  /// Empty list means this is a one-time activity on [oneTimeDate].
  final List<int> daysOfWeek;

  /// Dynamic alert channel toggles
  final bool alarmEnabled;
  final bool notificationEnabled;
  final bool whatsappEnabled;

  /// If true, uses the user's pre-saved WhatsApp number from AppSettings.
  /// If false, uses [customWhatsAppNumber].
  final bool useDefaultWhatsAppNumber;
  final String customWhatsAppNumber;
  final String customWhatsAppMessage;

  final bool isEnabled;
  final bool syncedToBackend;
  final DateTime createdAt;

  const ReminderItem({
    required this.id,
    required this.title,
    this.note = '',
    this.category = 'General',
    required this.hour,
    required this.minute,
    this.oneTimeDate,
    this.daysOfWeek = const [],
    this.alarmEnabled = false,
    this.notificationEnabled = true,
    this.whatsappEnabled = true,
    this.useDefaultWhatsAppNumber = true,
    this.customWhatsAppNumber = '',
    this.customWhatsAppMessage = '',
    this.isEnabled = true,
    this.syncedToBackend = false,
    required this.createdAt,
  });

  bool get isRecurring => daysOfWeek.isNotEmpty;

  String get formattedTime24 =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get formattedTime12 {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String? get formattedOneTimeDate {
    if (oneTimeDate == null) return null;
    final y = oneTimeDate!.year.toString().padLeft(4, '0');
    final m = oneTimeDate!.month.toString().padLeft(2, '0');
    final d = oneTimeDate!.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String resolvePhoneNumber(String defaultPhoneNumber) {
    if (useDefaultWhatsAppNumber) {
      return defaultPhoneNumber.trim();
    }
    return customWhatsAppNumber.trim();
  }

  String get scheduleSummary {
    if (daysOfWeek.isEmpty) {
      return formattedOneTimeDate ?? 'One-time';
    }
    if (daysOfWeek.length == 7) return 'Every day';
    final sorted = [...daysOfWeek]..sort();
    if (sorted.length == 5 &&
        sorted[0] == 1 &&
        sorted[1] == 2 &&
        sorted[2] == 3 &&
        sorted[3] == 4 &&
        sorted[4] == 5) {
      return 'Weekdays (Mon–Fri)';
    }
    if (sorted.length == 2 && sorted[0] == 6 && sorted[1] == 7) {
      return 'Weekends (Sat–Sun)';
    }
    const names = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return sorted.map((d) => names[d] ?? '').join(', ');
  }

  bool occursOnWeekday(int isoWeekday, {DateTime? referenceDate}) {
    if (daysOfWeek.isNotEmpty) {
      return daysOfWeek.contains(isoWeekday);
    }
    if (oneTimeDate == null) return false;
    if (referenceDate != null) {
      return oneTimeDate!.year == referenceDate.year &&
          oneTimeDate!.month == referenceDate.month &&
          oneTimeDate!.day == referenceDate.day;
    }
    return oneTimeDate!.weekday == isoWeekday;
  }

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  ReminderItem copyWith({
    String? id,
    String? title,
    String? note,
    String? category,
    int? hour,
    int? minute,
    DateTime? oneTimeDate,
    bool clearOneTimeDate = false,
    List<int>? daysOfWeek,
    bool? alarmEnabled,
    bool? notificationEnabled,
    bool? whatsappEnabled,
    bool? useDefaultWhatsAppNumber,
    String? customWhatsAppNumber,
    String? customWhatsAppMessage,
    bool? isEnabled,
    bool? syncedToBackend,
    DateTime? createdAt,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      category: category ?? this.category,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      oneTimeDate: clearOneTimeDate ? null : (oneTimeDate ?? this.oneTimeDate),
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
      useDefaultWhatsAppNumber:
          useDefaultWhatsAppNumber ?? this.useDefaultWhatsAppNumber,
      customWhatsAppNumber: customWhatsAppNumber ?? this.customWhatsAppNumber,
      customWhatsAppMessage:
          customWhatsAppMessage ?? this.customWhatsAppMessage,
      isEnabled: isEnabled ?? this.isEnabled,
      syncedToBackend: syncedToBackend ?? this.syncedToBackend,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'category': category,
      'hour': hour,
      'minute': minute,
      'oneTimeDate': oneTimeDate?.toIso8601String(),
      'daysOfWeek': daysOfWeek,
      'alarmEnabled': alarmEnabled,
      'notificationEnabled': notificationEnabled,
      'whatsappEnabled': whatsappEnabled,
      'useDefaultWhatsAppNumber': useDefaultWhatsAppNumber,
      'customWhatsAppNumber': customWhatsAppNumber,
      'customWhatsAppMessage': customWhatsAppMessage,
      'isEnabled': isEnabled,
      'syncedToBackend': syncedToBackend,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    return ReminderItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Activity',
      note: json['note'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      hour: json['hour'] as int? ?? 9,
      minute: json['minute'] as int? ?? 0,
      oneTimeDate: json['oneTimeDate'] != null
          ? DateTime.tryParse(json['oneTimeDate'] as String)
          : null,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      alarmEnabled: json['alarmEnabled'] as bool? ?? false,
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      whatsappEnabled: json['whatsappEnabled'] as bool? ?? true,
      useDefaultWhatsAppNumber:
          json['useDefaultWhatsAppNumber'] as bool? ?? true,
      customWhatsAppNumber: json['customWhatsAppNumber'] as String? ?? '',
      customWhatsAppMessage: json['customWhatsAppMessage'] as String? ?? '',
      isEnabled: json['isEnabled'] as bool? ?? true,
      syncedToBackend: json['syncedToBackend'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Payload expected by the Node.js Baileys backend `/api/schedules` endpoint.
  Map<String, dynamic> toBackendPayload({
    required String defaultPhoneNumber,
    required String timezone,
  }) {
    return {
      'id': id,
      'title': title,
      'note': note,
      'category': category,
      'time': formattedTime24,
      'date': isRecurring ? null : formattedOneTimeDate,
      'daysOfWeek': daysOfWeek,
      'timezone': timezone,
      'phoneNumber': resolvePhoneNumber(defaultPhoneNumber),
      'customMessage': customWhatsAppMessage,
      'whatsappEnabled': whatsappEnabled,
      'enabled': isEnabled,
    };
  }
}

class ReminderCategories {
  static const List<String> all = [
    'General',
    'Study / Class',
    'Work / Meeting',
    'Fitness / Gym',
    'Health / Medicine',
    'Prayer / Routine',
    'Personal',
  ];

  static IconData iconFor(String category) {
    switch (category) {
      case 'Study / Class':
        return Icons.school_rounded;
      case 'Work / Meeting':
        return Icons.work_outline_rounded;
      case 'Fitness / Gym':
        return Icons.fitness_center_rounded;
      case 'Health / Medicine':
        return Icons.medication_rounded;
      case 'Prayer / Routine':
        return Icons.self_improvement_rounded;
      case 'Personal':
        return Icons.person_outline_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }
}

