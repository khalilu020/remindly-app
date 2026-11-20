import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_reminder_app/models/reminder_model.dart';

void main() {
  test('ReminderItem serializes to JSON and backend payload accurately', () {
    final item = ReminderItem(
      id: 'rem-1',
      title: 'Morning Workout',
      note: 'Cardio + Stretch',
      category: 'Fitness / Gym',
      hour: 7,
      minute: 30,
      daysOfWeek: const [1, 3, 5],
      alarmEnabled: true,
      notificationEnabled: true,
      whatsappEnabled: true,
      useDefaultWhatsAppNumber: true,
      createdAt: DateTime(2026, 11, 18),
    );

    final roundTripped = ReminderItem.fromJson(item.toJson());
    expect(roundTripped.id, 'rem-1');
    expect(roundTripped.formattedTime24, '07:30');
    expect(roundTripped.formattedTime12, '07:30 AM');
    expect(roundTripped.scheduleSummary, 'Mon, Wed, Fri');
    expect(roundTripped.occursOnWeekday(3), isTrue);
    expect(roundTripped.occursOnWeekday(2), isFalse);

    final payload = roundTripped.toBackendPayload(
      defaultPhoneNumber: '923001234567',
      timezone: 'Asia/Karachi',
    );
    expect(payload['phoneNumber'], '923001234567');
    expect(payload['time'], '07:30');
    expect(payload['daysOfWeek'], [1, 3, 5]);
    expect(payload['whatsappEnabled'], isTrue);
  });

  test('ReminderItem uses custom contact number when useDefaultWhatsAppNumber is false', () {
    final item = ReminderItem(
      id: 'rem-2',
      title: 'Send Report to Sir',
      hour: 15,
      minute: 0,
      oneTimeDate: DateTime(2026, 11, 20),
      daysOfWeek: const [],
      whatsappEnabled: true,
      useDefaultWhatsAppNumber: false,
      customWhatsAppNumber: '923119998877',
      createdAt: DateTime(2026, 11, 18),
    );

    expect(item.isRecurring, isFalse);
    expect(item.resolvePhoneNumber('923001234567'), '923119998877');
    expect(item.formattedOneTimeDate, '2026-11-20');
  });
}

