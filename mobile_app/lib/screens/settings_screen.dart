import 'package:flutter/material.dart';
import '../models/app_settings.dart';
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

  final _api = WhatsAppApiService();

  @override
  void initState() {
    super.initState();
    _phoneController =
        TextEditingController(text: widget.settings.defaultWhatsAppNumber);
    _defaultAlarm = widget.settings.defaultAlarm;
    _defaultNotification = widget.settings.defaultNotification;
    _defaultWhatsApp = widget.settings.defaultWhatsApp;
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
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                      label: Text(
                        isConnected ? 'Switch Account' : 'Connect QR',
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
                hintText: 'e.g. 923195853020 (country code + number)',
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
