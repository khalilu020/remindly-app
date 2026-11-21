import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/whatsapp_api_service.dart';
import '../theme/app_theme.dart';

/// In-app WhatsApp linking screen.
/// Lets normal users link WhatsApp directly inside the app via either:
/// 1) 8-Digit Phone Pairing Code (works on a single phone — no QR scanner needed!)
/// 2) Live In-App QR Code (rendered right inside the app)
class ConnectWhatsAppScreen extends StatefulWidget {
  final String initialPhoneNumber;

  const ConnectWhatsAppScreen({
    super.key,
    this.initialPhoneNumber = '',
  });

  @override
  State<ConnectWhatsAppScreen> createState() => _ConnectWhatsAppScreenState();
}

class _ConnectWhatsAppScreenState extends State<ConnectWhatsAppScreen> {
  final _api = WhatsAppApiService();
  late final TextEditingController _phoneController;

  bool _usePhoneCodeTab = true;
  bool _requestingCode = false;
  bool _disconnecting = false;
  bool _hasAttemptedPairing = false;
  String? _pairingCode;
  String? _errorMessage;
  BackendStatusResult? _status;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhoneNumber);
    _pollStatus();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollStatus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pollStatus() async {
    final result = await _api.checkStatus();
    if (!mounted) return;
    final wasConnected = _status?.whatsappConnected ?? false;
    setState(() => _status = result);

    // Only auto-pop if the user just paired on this screen
    if (!wasConnected && result.whatsappConnected && _hasAttemptedPairing) {
      _pollTimer?.cancel();
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.of(context).pop(
        result.linkedAccount ?? _phoneController.text.trim(),
      );
    }
  }

  Future<void> _disconnectAndRelink() async {
    setState(() {
      _disconnecting = true;
      _errorMessage = null;
    });
    await _api.logoutWhatsApp();
    final updated = await _api.checkStatus();
    if (!mounted) return;
    setState(() {
      _disconnecting = false;
      _status = updated;
      _pairingCode = null;
      _hasAttemptedPairing = true;
    });
  }

  Future<void> _generatePairingCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage =
          'Enter your WhatsApp number with country code (e.g. 923001234567).');
      return;
    }

    setState(() {
      _requestingCode = true;
      _hasAttemptedPairing = true;
      _errorMessage = null;
      _pairingCode = null;
    });

    final res = await _api.requestPairingCode(phone);
    if (!mounted) return;

    setState(() {
      _requestingCode = false;
      if (res.ok && res.code != null) {
        _pairingCode = res.code;
      } else {
        _errorMessage = res.message;
      }
    });
  }

  Uint8List? _decodeQrBytes(String? dataUrl) {
    if (dataUrl == null || !dataUrl.contains(',')) return null;
    try {
      final base64Part = dataUrl.split(',').last;
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final connected = _status?.whatsappConnected ?? false;
    final qrBytes = _decodeQrBytes(_status?.qrDataUrl);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect WhatsApp'),
      ),
      body: connected
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.whatsappGreen.withOpacity(0.18),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        size: 52,
                        color: AppPalette.whatsappGreen,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'WhatsApp Connected!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _status?.linkedAccount != null
                          ? 'Linked to: +${_status!.linkedAccount}'
                          : 'Linked to: +923195853020',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your 24/7 automated WhatsApp timetable dispatching is active.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.whatsappGreen,
                          foregroundColor: const Color(0xFF042611),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text(
                          'Done / Return to App',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _disconnecting ? null : _disconnectAndRelink,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.roseAccent,
                          side: const BorderSide(color: AppPalette.roseAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _disconnecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppPalette.roseAccent,
                                ),
                              )
                            : const Icon(Icons.link_off_rounded),
                        label: Text(
                          _disconnecting
                              ? 'Disconnecting...'
                              : 'Disconnect & Link Different Number',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // Intro card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF0F2A22), Color(0xFF131B2E)]
                          : const [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
                    ),
                    border: Border.all(
                      color: AppPalette.whatsappGreen.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppPalette.whatsappGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: AppPalette.whatsappGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Link once right here to automatically receive WhatsApp reminders at your scheduled times.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Method selector: Phone Number Code vs QR Code
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppPalette.darkCard : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _MethodTab(
                        icon: Icons.dialpad_rounded,
                        label: 'Phone Code',
                        selected: _usePhoneCodeTab,
                        onTap: () => setState(() => _usePhoneCodeTab = true),
                      ),
                      _MethodTab(
                        icon: Icons.qr_code_2_rounded,
                        label: 'Scan QR',
                        selected: !_usePhoneCodeTab,
                        onTap: () => setState(() => _usePhoneCodeTab = false),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                if (_status != null && !_status!.reachable) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: _status!.status == 'waking_up'
                          ? AppPalette.amberAccent.withOpacity(0.12)
                          : AppPalette.roseAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _status!.status == 'waking_up'
                            ? AppPalette.amberAccent.withOpacity(0.45)
                            : AppPalette.roseAccent.withOpacity(0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        _status!.status == 'waking_up'
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppPalette.amberAccent,
                                ),
                              )
                            : const Icon(
                                Icons.wifi_off_rounded,
                                color: AppPalette.roseAccent,
                              ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _status!.status == 'waking_up'
                                ? 'Cloud server is waking up (~20s). Getting QR & pairing code ready...'
                                : 'Could not reach server right now. Check your internet or tap below to wake server.',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        if (_status!.status != 'waking_up') ...[
                          TextButton(
                            onPressed: () {
                              _api.wakeServer();
                              _pollStatus();
                            },
                            child: const Text('Wake Server'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                if (_usePhoneCodeTab) ...[
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Your WhatsApp Number',
                      hintText: 'Country code + number, e.g. 923001234567',
                      prefixIcon: Icon(Icons.phone_iphone_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _requestingCode ? null : _generatePairingCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.whatsappGreen,
                        foregroundColor: const Color(0xFF042611),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _requestingCode
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF042611),
                              ),
                            )
                          : const Icon(Icons.vpn_key_rounded),
                      label: Text(
                        _requestingCode
                            ? 'Generating Code...'
                            : 'Get 8-Digit Pairing Code',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppPalette.roseAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_pairingCode != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppPalette.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppPalette.whatsappGreen.withOpacity(0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'YOUR PAIRING CODE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            _pairingCode!,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: AppPalette.whatsappGreen,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: _pairingCode!.replaceAll('-', ''),
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pairing code copied!'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 17),
                            label: const Text('Copy Code'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _StepsCard(
                    title: 'How to link (takes 10 seconds)',
                    steps: const [
                      'Tap "Get 8-Digit Pairing Code" above.',
                      'Tap the WhatsApp notification on your phone (or open WhatsApp → Linked Devices → Link a Device → Link with phone number instead).',
                      'Enter the 8-digit code — this screen updates automatically!',
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppPalette.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        if (qrBytes != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Image.memory(
                              qrBytes,
                              width: 230,
                              height: 230,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Scan with WhatsApp → Linked Devices → Link a Device',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 28),
                          const CircularProgressIndicator(
                            color: AppPalette.whatsappGreen,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Preparing live QR code...',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppPalette.darkCardElevated : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppPalette.whatsappGreen : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  final String title;
  final List<String> steps;

  const _StepsCard({required this.title, required this.steps});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.whatsappGreen.withOpacity(0.18),
                        ),
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.whatsappGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
