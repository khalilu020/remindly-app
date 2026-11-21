import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/notification_service.dart';
import '../services/whatsapp_api_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final BackendStatusResult? backendStatus;
  final ValueChanged<AppSettings> onSaveSettings;
  final VoidCallback onOpenConnectWhatsApp;
  final VoidCallback onDisconnectWhatsApp;
  final VoidCallback onRefreshConnection;
  final VoidCallback onSyncAllSchedules;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.backendStatus,
    required this.onSaveSettings,
    required this.onOpenConnectWhatsApp,
    required this.onDisconnectWhatsApp,
    required this.onRefreshConnection,
    required this.onSyncAllSchedules,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _phoneController;
  late bool _defaultAlarm;
  late bool _defaultNotification;
  late bool _defaultWhatsApp;
  bool _sendingTest = false;
  bool _testingNotif = false;
  bool _testingAlarm = false;
  bool _testingDelayed = false;
  bool _notifGranted = true;
  bool _exactGranted = true;

  final _api = WhatsAppApiService();

  Future<void> _checkPermissions() async {
    final notif = await NotificationService.instance.areNotificationsEnabled();
    final exact =
        await NotificationService.instance.canScheduleExactNotifications();
    if (mounted) {
      setState(() {
        _notifGranted = notif;
        _exactGranted = exact;
      });
    }
  }

  Future<void> _testInstantNotification() async {
    setState(() => _testingNotif = true);
    await NotificationService.instance.showInstantNotification();
    if (!mounted) return;
    setState(() => _testingNotif = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔔 Notification sent! Check your notification tray.'),
        backgroundColor: AppPalette.notifIndigo,
      ),
    );
  }

  Future<void> _testInstantAlarm() async {
    setState(() => _testingAlarm = true);
    await NotificationService.instance.showInstantAlarm();
    if (!mounted) return;
    setState(() => _testingAlarm = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('⏰ Loud Alarm alert triggered! Tap it to open Alarm screen.'),
        backgroundColor: AppPalette.alarmCoral,
      ),
    );
  }

  Future<void> _testDelayedAlarm() async {
    setState(() => _testingDelayed = true);
    await NotificationService.instance
        .testDelayedAlarmAndNotification(seconds: 5);
    if (!mounted) return;
    setState(() => _testingDelayed = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '⏱️ Test alarm set for 5s from now! Lock your screen now to verify waking.',
        ),
        backgroundColor: AppPalette.alarmCoral,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _requestExactAlarmPermissions() async {
    await NotificationService.instance.requestExactAlarmsPermission();
    await Future.delayed(const Duration(seconds: 1));
    await _checkPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    await NotificationService.instance.requestNotificationsPermission();
    await Future.delayed(const Duration(seconds: 1));
    await _checkPermissions();
  }

  @override
  void initState() {
    super.initState();
    _phoneController =
        TextEditingController(text: widget.settings.defaultWhatsAppNumber);
    _defaultAlarm = widget.settings.defaultAlarm;
    _defaultNotification = widget.settings.defaultNotification;
    _defaultWhatsApp = widget.settings.defaultWhatsApp;
    _checkPermissions();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.defaultWhatsAppNumber !=
            widget.settings.defaultWhatsAppNumber &&
        _phoneController.text != widget.settings.defaultWhatsAppNumber) {
      _phoneController.text = widget.settings.defaultWhatsAppNumber;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  AppSettings _collectSettings() {
    return widget.settings.copyWith(
      defaultWhatsAppNumber: _phoneController.text.trim(),
      defaultAlarm: _defaultAlarm,
      defaultNotification: _defaultNotification,
      defaultWhatsApp: _defaultWhatsApp,
    );
  }

  void _save() {
    widget.onSaveSettings(_collectSettings());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully!')),
    );
  }

  Future<void> _sendTestWhatsApp() async {
    final current = _collectSettings();
    final phone = current.defaultWhatsAppNumber.replaceAll(RegExp(r'\D'), '');

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your WhatsApp recipient number first.'),
        ),
      );
      return;
    }

    setState(() => _sendingTest = true);
    final result = await _api.sendInstantWhatsApp(
      settings: current,
      phoneNumber: phone,
      message:
          '🎉 *Remindly Live Test!*\nYour 24/7 automated WhatsApp reminders are active and connected.',
      title: 'Remindly Live Test',
    );
    if (!mounted) return;
    setState(() => _sendingTest = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.ok ? AppPalette.whatsappDeep : AppPalette.roseAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final isConnected = widget.backendStatus?.whatsappConnected ?? false;
    final linked = widget.backendStatus?.linkedAccount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      children: [
        // Hero 24/7 Cloud Engine Status Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isConnected
                  ? const [Color(0xFF15803D), Color(0xFF065F46)]
                  : (isDark
                      ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
                      : const [Color(0xFF1E293B), Color(0xFF334155)]),
            ),
            boxShadow: [
              BoxShadow(
                color: (isConnected ? AppPalette.whatsappGreen : Colors.black)
                    .withOpacity(0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isConnected
                          ? Icons.verified_rounded
                          : Icons.cloud_sync_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected
                              ? 'WhatsApp Connected & Active'
                              : 'Connecting Cloud Dispatcher...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isConnected
                              ? 'Linked to: +${linked ?? "Ready"} • 24/7 Cloud Host'
                              : 'Waiting for cloud connection...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onRefreshConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onOpenConnectWhatsApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF064E3B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                      label: Text(
                        isConnected ? 'Manage WhatsApp' : 'Connect WhatsApp',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Default Recipient Settings
        _SettingsGroupCard(
          title: 'Automated WhatsApp Delivery',
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Default Recipient Phone Number',
                hintText: 'e.g. 923001234567 (country code + number)',
                prefixIcon: Icon(Icons.phone_iphone_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Timetable reminders will be sent automatically to this number at their scheduled minutes. You can also pick a specific contact per activity.',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sendingTest ? null : _sendTestWhatsApp,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.whatsappGreen,
                  foregroundColor: const Color(0xFF042611),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: _sendingTest
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF042611),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 17),
                label: const Text(
                  'Send Test WhatsApp Now',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Default Alert Channels
        _SettingsGroupCard(
          title: 'Default Channels for New Schedules',
          children: [
            _MiniToggleRow(
              icon: Icons.alarm_rounded,
              color: AppPalette.alarmCoral,
              title: 'Loud Alarm',
              subtitle: 'Offline ringing sound with Snooze screen',
              value: _defaultAlarm,
              onChanged: (v) => setState(() => _defaultAlarm = v),
            ),
            Divider(color: cs.outlineVariant.withOpacity(0.5), height: 18),
            _MiniToggleRow(
              icon: Icons.notifications_active_rounded,
              color: AppPalette.notifIndigo,
              title: 'Push Notification',
              subtitle: 'Offline system banner',
              value: _defaultNotification,
              onChanged: (v) => setState(() => _defaultNotification = v),
            ),
            Divider(color: cs.outlineVariant.withOpacity(0.5), height: 18),
            _MiniToggleRow(
              icon: Icons.chat_bubble_rounded,
              color: AppPalette.whatsappGreen,
              title: 'Automated WhatsApp',
              subtitle: 'Dispatches automatically at the exact scheduled minute',
              value: _defaultWhatsApp,
              onChanged: (v) => setState(() => _defaultWhatsApp = v),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Device Permissions & Offline Alert Verification
        _SettingsGroupCard(
          title: 'Offline Alarm & Notification System',
          children: [
            Text(
              'Remindly uses native Android AlarmManager to ring offline even when your phone is locked or Doze mode is active.',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),

            // Live Permission Status Badges
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _notifGranted
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        color: _notifGranted
                            ? AppPalette.whatsappGreen
                            : AppPalette.roseAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Push Notification Permission',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _notifGranted
                                  ? 'Granted'
                                  : 'Blocked — banner alerts will not show',
                              style: TextStyle(
                                fontSize: 11,
                                color: _notifGranted
                                    ? cs.onSurfaceVariant
                                    : AppPalette.roseAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_notifGranted)
                        TextButton(
                          onPressed: _requestNotificationPermission,
                          child: const Text('Allow'),
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Icon(
                        _exactGranted
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded,
                        color: _exactGranted
                            ? AppPalette.whatsappGreen
                            : AppPalette.amberAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Exact Alarms & Reminders',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _exactGranted
                                  ? 'Active — exact-minute alarms allowed'
                                  : 'Tap to Allow in Android Settings',
                              style: TextStyle(
                                fontSize: 11,
                                color: _exactGranted
                                    ? cs.onSurfaceVariant
                                    : AppPalette.amberAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_exactGranted)
                        FilledButton.tonal(
                          onPressed: _requestExactAlarmPermissions,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('Enable',
                              style: TextStyle(fontSize: 11.5)),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Test Device Sound & Notifications:',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            // 3 Interactive Test Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testingNotif ? null : _testInstantNotification,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.notifIndigo,
                      side: BorderSide(
                          color: AppPalette.notifIndigo.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: _testingNotif
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.notifications_active_rounded,
                            size: 16),
                    label: const Text(
                      'Banner (0s)',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 11.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testingAlarm ? null : _testInstantAlarm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.alarmCoral,
                      side: BorderSide(
                          color: AppPalette.alarmCoral.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: _testingAlarm
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.alarm_on_rounded, size: 16),
                    label: const Text(
                      'Alarm (0s)',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 11.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _testingDelayed ? null : _testDelayedAlarm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.alarmCoral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: _testingDelayed
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.timer_rounded, size: 16),
                label: const Text(
                  'Test 5s Delayed Alarm (Lock Phone to Test)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? Colors.white : cs.primary,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text(
              'Save Preferences',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroupCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _MiniToggleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MiniToggleRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: Colors.white,
          activeTrackColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
