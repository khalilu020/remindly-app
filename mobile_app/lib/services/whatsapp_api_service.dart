import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/app_settings.dart';
import '../models/reminder_model.dart';

class BackendStatusResult {
  final bool reachable;
  final bool whatsappConnected;
  final String status;
  final String statusText;
  final String? linkedAccount;
  final String? qrDataUrl;
  final String? error;

  const BackendStatusResult({
    required this.reachable,
    required this.whatsappConnected,
    required this.status,
    required this.statusText,
    this.linkedAccount,
    this.qrDataUrl,
    this.error,
  });
}

/// Automated WhatsApp delivery service powered by the 24/7 SnapDeploy Cloud Backend.
class WhatsAppApiService {
  String get _baseUrl => AppConfig.backendUrl;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (AppConfig.apiSecret.isNotEmpty) {
      headers['x-api-key'] = AppConfig.apiSecret;
    }
    return headers;
  }

  /// Wakes up the sleeping container on SnapDeploy if idle
  Future<void> wakeServer() async {
    try {
      await http
          .post(
            Uri.parse(
                'https://snapdeploy.dev/api/public/wake/remindly-bot-cc713'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Checks whether the 24/7 cloud server is reachable and if WhatsApp is linked.
  Future<BackendStatusResult> checkStatus({AppSettings? settings}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/whatsapp/status'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 503 ||
          response.body.contains('<!DOCTYPE html>') ||
          response.body.contains('Waking up your container')) {
        unawaited(wakeServer());
        return const BackendStatusResult(
          reachable: false,
          whatsappConnected: false,
          status: 'waking_up',
          statusText: 'Server waking up (~20s)...',
          error: 'Cloud container is spinning up from idle sleep.',
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final connected = data['connected'] == true;
        final status = data['status'] as String? ?? 'unknown';
        final userMap = data['user'] as Map<String, dynamic>?;
        final userId = userMap?['id'] as String?;
        final qrDataUrl = data['qrDataUrl'] as String?;

        return BackendStatusResult(
          reachable: true,
          whatsappConnected: connected,
          status: status,
          statusText: connected
              ? 'WhatsApp Connected'
              : status == 'waiting_qr'
                  ? 'Ready to link WhatsApp'
                  : 'Connecting...',
          linkedAccount: userId?.split(':').first,
          qrDataUrl: qrDataUrl,
        );
      }

      return BackendStatusResult(
        reachable: true,
        whatsappConnected: false,
        status: 'error',
        statusText: 'Server online (HTTP ${response.statusCode})',
        error: response.body,
      );
    } catch (e) {
      return BackendStatusResult(
        reachable: false,
        whatsappConnected: false,
        status: 'unreachable',
        statusText: 'Cloud Server Waking Up / Offline',
        error: e.toString(),
      );
    }
  }

  /// Sends an immediate WhatsApp message through the cloud backend.
  Future<({bool ok, String message})> sendInstantWhatsApp({
    required AppSettings settings,
    required String phoneNumber,
    required String message,
    String? title,
  }) async {
    final targetPhone = phoneNumber.isNotEmpty
        ? phoneNumber
        : settings.defaultWhatsAppNumber;

    final cleanPhone = targetPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) {
      return (
        ok: false,
        message: 'Please provide a valid WhatsApp number with country code.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/whatsapp/send-now'),
            headers: _headers,
            body: jsonEncode({
              'phoneNumber': cleanPhone,
              'message': message.trim(),
              'title': title ?? 'Instant Alert from Remindly',
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (ok: true, message: 'WhatsApp message sent to +$cleanPhone!');
      }
      return (
        ok: false,
        message: data['error'] as String? ??
            'Failed to dispatch WhatsApp message (${response.statusCode}).',
      );
    } catch (e) {
      return (
        ok: false,
        message: 'Could not connect to Remindly Cloud: ${e.toString()}',
      );
    }
  }

  /// Syncs a scheduled reminder with the 24/7 cloud backend scheduler.
  Future<bool> syncReminder(ReminderItem reminder, AppSettings settings) async {
    if (!reminder.whatsappEnabled) {
      return deleteReminder(reminder.id);
    }

    final phone = reminder.resolvePhoneNumber(settings.defaultWhatsAppNumber);
    if (phone.isEmpty) return false;

    try {
      final payload = reminder.toBackendPayload(
        defaultPhoneNumber: settings.defaultWhatsAppNumber,
        timezone: settings.timezone,
      );

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/schedules'),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a schedule from the 24/7 cloud backend.
  Future<bool> deleteReminder(String reminderId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/api/schedules/$reminderId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return true;
    }
  }

  /// Logs out the connected WhatsApp session on the cloud server.
  Future<bool> logoutWhatsApp() async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/whatsapp/logout'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Requests an 8-digit pairing code to link WhatsApp from mobile.
  Future<({bool ok, String? code, String? message})> requestPairingCode(
    String phoneNumber,
  ) async {
    try {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/whatsapp/pair-code'),
            headers: _headers,
            body: jsonEncode({'phoneNumber': cleanPhone}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (
          ok: true,
          code: data['code'] as String?,
          message: null,
        );
      }
      return (
        ok: false,
        code: null,
        message: data['error'] as String? ?? 'Failed to request pairing code.',
      );
    } catch (e) {
      return (
        ok: false,
        code: null,
        message: 'Could not connect to cloud server: ${e.toString()}',
      );
    }
  }
}
