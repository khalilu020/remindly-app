class AppSettings {
  /// Default recipient WhatsApp number (with country code, e.g. "923195853020")
  final String defaultWhatsAppNumber;

  /// Base URL of the Node.js Baileys cloud backend
  final String backendUrl;

  /// Optional x-api-key header matching API_SECRET on the backend
  final String apiSecret;

  /// IANA timezone sent to the backend for accurate automated WhatsApp scheduling
  final String timezone;

  /// User's default alert preferences when adding a new activity
  final bool defaultAlarm;
  final bool defaultNotification;
  final bool defaultWhatsApp;

  const AppSettings({
    this.defaultWhatsAppNumber = '923195853020',
    this.backendUrl = 'https://remindly-bot-cc713.containers.snapdeploy.app',
    this.apiSecret = '',
    this.timezone = 'Asia/Karachi',
    this.defaultAlarm = false,
    this.defaultNotification = true,
    this.defaultWhatsApp = true,
  });

  bool get hasDefaultNumber => defaultWhatsAppNumber.trim().isNotEmpty;

  AppSettings copyWith({
    String? defaultWhatsAppNumber,
    String? backendUrl,
    String? apiSecret,
    String? timezone,
    bool? defaultAlarm,
    bool? defaultNotification,
    bool? defaultWhatsApp,
  }) {
    return AppSettings(
      defaultWhatsAppNumber:
          defaultWhatsAppNumber ?? this.defaultWhatsAppNumber,
      backendUrl: backendUrl ?? this.backendUrl,
      apiSecret: apiSecret ?? this.apiSecret,
      timezone: timezone ?? this.timezone,
      defaultAlarm: defaultAlarm ?? this.defaultAlarm,
      defaultNotification: defaultNotification ?? this.defaultNotification,
      defaultWhatsApp: defaultWhatsApp ?? this.defaultWhatsApp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultWhatsAppNumber': defaultWhatsAppNumber,
      'backendUrl': backendUrl,
      'apiSecret': apiSecret,
      'timezone': timezone,
      'defaultAlarm': defaultAlarm,
      'defaultNotification': defaultNotification,
      'defaultWhatsApp': defaultWhatsApp,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      defaultWhatsAppNumber:
          json['defaultWhatsAppNumber'] as String? ?? '923195853020',
      backendUrl: json['backendUrl'] as String? ??
          'https://remindly-bot-cc713.containers.snapdeploy.app',
      apiSecret: json['apiSecret'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'Asia/Karachi',
      defaultAlarm: json['defaultAlarm'] as bool? ?? false,
      defaultNotification: json['defaultNotification'] as bool? ?? true,
      defaultWhatsApp: json['defaultWhatsApp'] as bool? ?? true,
    );
  }
}
