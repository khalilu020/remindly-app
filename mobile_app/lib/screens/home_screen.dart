import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/app_settings.dart';
import '../models/reminder_model.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/whatsapp_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reminder_card.dart';
import 'add_edit_reminder_screen.dart';
import 'alarm_ring_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _api = WhatsAppApiService();

  List<ReminderItem> _reminders = [];
  AppSettings _settings = const AppSettings();
  BackendStatusResult? _backendStatus;
  bool _loading = true;
  int _currentTab = 0;
  int _selectedTimetableDay = DateTime.now().weekday;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.onAlarmNotificationTapped = _openAlarmScreen;
    _loadInitialData();
  }

  void _openAlarmScreen(Map<String, dynamic> payload) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlarmRingScreen(
          title: payload['title'] as String? ?? 'Scheduled Activity',
          note: payload['note'] as String? ?? '',
          scheduledTime: payload['time'] as String? ?? '',
        ),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    final settings = await _storage.loadSettings(
      fallbackTimezone: NotificationService.instance.deviceTimezone,
    );
    final reminders = await _storage.loadReminders();
    if (!mounted) return;

    setState(() {
      _settings = settings;
      _reminders = reminders;
      _loading = false;
    });

    await _refreshBackendStatus();
  }

  Future<void> _refreshBackendStatus() async {
    final status = await _api.checkStatus(settings: _settings);
    if (!mounted) return;
    setState(() => _backendStatus = status);
  }

  void _openConnectWhatsApp() {
    setState(() => _currentTab = 2);
  }

  Future<void> _disconnectWhatsApp() async {
    final ok = await _api.logoutWhatsApp();
    await _refreshBackendStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'WhatsApp disconnected. Tap Connect WhatsApp to link again.'
              : 'Could not disconnect right now.',
        ),
      ),
    );
  }

  Future<void> _persistAndSort() async {
    _reminders.sort(
      (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
    );
    await _storage.saveReminders(_reminders);
  }

  Future<void> _loadSampleTimetable() async {
    final uuid = const Uuid();
    final samples = [
      ReminderItem(
        id: uuid.v4(),
        title: 'Morning Workout & Stretch',
        note: '30 mins cardio + hydration',
        category: 'Fitness / Gym',
        hour: 7,
        minute: 0,
        daysOfWeek: const [1, 3, 5],
        alarmEnabled: true,
        notificationEnabled: true,
        whatsappEnabled: true,
        createdAt: DateTime.now(),
      ),
      ReminderItem(
        id: uuid.v4(),
        title: 'University Lecture / Study Block',
        note: 'Bring laptop & project notes',
        category: 'Study / Class',
        hour: 10,
        minute: 30,
        daysOfWeek: const [1, 2, 3, 4, 5],
        alarmEnabled: false,
        notificationEnabled: true,
        whatsappEnabled: true,
        createdAt: DateTime.now(),
      ),
      ReminderItem(
        id: uuid.v4(),
        title: 'Evening Vitamins & Walk',
        note: 'After dinner',
        category: 'Health / Medicine',
        hour: 20,
        minute: 0,
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
        alarmEnabled: false,
        notificationEnabled: false,
        whatsappEnabled: true,
        createdAt: DateTime.now(),
      ),
    ];

    final savedList = <ReminderItem>[];
    for (final s in samples) {
      await NotificationService.instance.scheduleReminder(s);
      final synced = await _api.syncReminder(s, _settings);
      savedList.add(s.copyWith(syncedToBackend: synced));
    }

    setState(() => _reminders.addAll(savedList));
    await _persistAndSort();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample timetable added!')),
    );
  }

  Future<void> _openAddEditScreen({ReminderItem? existing}) async {
    final result = await Navigator.of(context).push<ReminderItem>(
      MaterialPageRoute(
        builder: (_) => AddEditReminderScreen(
          existing: existing,
          settings: _settings,
        ),
      ),
    );

    if (result == null) return;

    await NotificationService.instance.scheduleReminder(result);

    bool synced = false;
    if (result.whatsappEnabled) {
      synced = await _api.syncReminder(result, _settings);
    } else {
      await _api.deleteReminder(result.id);
    }

    final savedItem = result.copyWith(syncedToBackend: synced);

    setState(() {
      final index = _reminders.indexWhere((r) => r.id == savedItem.id);
      if (index >= 0) {
        _reminders[index] = savedItem;
      } else {
        _reminders.add(savedItem);
      }
    });
    await _persistAndSort();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedItem.whatsappEnabled
              ? (synced
                  ? 'Activity saved & synced to WhatsApp scheduler!'
                  : 'Saved locally (WhatsApp backend unreachable).')
              : 'Local offline activity saved!',
        ),
      ),
    );
  }

  Future<void> _toggleReminderEnabled(ReminderItem item, bool enabled) async {
    var updated = item.copyWith(isEnabled: enabled);
    await NotificationService.instance.scheduleReminder(updated);

    if (updated.whatsappEnabled) {
      final synced = await _api.syncReminder(updated, _settings);
      updated = updated.copyWith(syncedToBackend: synced);
    }

    setState(() {
      final idx = _reminders.indexWhere((r) => r.id == updated.id);
      if (idx >= 0) _reminders[idx] = updated;
    });
    await _persistAndSort();
  }

  Future<void> _deleteReminder(ReminderItem item) async {
    await NotificationService.instance.cancelReminder(item.id);
    if (item.whatsappEnabled) {
      await _api.deleteReminder(item.id);
    }
    setState(() {
      _reminders.removeWhere((r) => r.id == item.id);
    });
    await _persistAndSort();
  }

  Future<void> _testSingleReminderWhatsApp(ReminderItem item) async {
    final phone = item.resolvePhoneNumber(_settings.defaultWhatsAppNumber);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set your default WhatsApp number in Settings first.'),
        ),
      );
      return;
    }

    final msg = item.customWhatsAppMessage.isNotEmpty
        ? item.customWhatsAppMessage
        : '⏰ *Reminder: ${item.title}*\n🕒 Time: ${item.formattedTime12}'
            '${item.note.isNotEmpty ? '\n📝 ${item.note}' : ''}';

    final res = await _api.sendInstantWhatsApp(
      settings: _settings,
      phoneNumber: phone,
      message: msg,
      title: item.title,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor:
            res.ok ? AppPalette.whatsappDeep : AppPalette.roseAccent,
      ),
    );
  }

  Future<void> _saveSettings(AppSettings updated) async {
    setState(() => _settings = updated);
    await _storage.saveSettings(updated);
    await _refreshBackendStatus();
  }

  Future<void> _syncAllSchedules() async {
    int syncedCount = 0;
    final updatedList = <ReminderItem>[];

    for (final item in _reminders) {
      if (item.whatsappEnabled) {
        final ok = await _api.syncReminder(item, _settings);
        if (ok) syncedCount++;
        updatedList.add(item.copyWith(syncedToBackend: ok));
      } else {
        updatedList.add(item);
      }
    }

    setState(() => _reminders = updatedList);
    await _persistAndSort();
    await _refreshBackendStatus();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Synced $syncedCount WhatsApp schedule(s) with server.'),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildHeroHeader() {
    final connected = _backendStatus?.whatsappConnected ?? false;
    final activeCount = _reminders.where((r) => r.isEnabled).length;
    final waCount =
        _reminders.where((r) => r.isEnabled && r.whatsappEnabled).length;
    final todayCount = _reminders
        .where(
          (r) =>
              r.isEnabled &&
              r.occursOnWeekday(
                DateTime.now().weekday,
                referenceDate: DateTime.now(),
              ),
        )
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2A22), Color(0xFF13203A)],
        ),
        border: Border.all(
          color: AppPalette.whatsappGreen.withOpacity(0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A0F1C).withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.68),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => connected
                    ? setState(() => _currentTab = 2)
                    : _openConnectWhatsApp(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (connected
                            ? AppPalette.whatsappGreen
                            : AppPalette.amberAccent)
                        .withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: (connected
                              ? AppPalette.whatsappGreen
                              : AppPalette.amberAccent)
                          .withOpacity(0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: connected
                              ? AppPalette.whatsappGreen
                              : AppPalette.amberAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        connected ? 'WA Live' : 'Link WA',
                        style: TextStyle(
                          color: connected
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFDE68A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(label: 'Today', value: '$todayCount'),
              _HeroStatDivider(),
              _HeroStat(label: 'Active', value: '$activeCount'),
              _HeroStatDivider(),
              _HeroStat(
                label: 'Auto-WA',
                value: '$waCount',
                accent: AppPalette.whatsappGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesTab() {
    if (_reminders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          _buildHeroHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppPalette.whatsappGreen.withOpacity(0.25),
                        AppPalette.notifIndigo.withOpacity(0.2),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 40,
                    color: AppPalette.whatsappGreen,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Timetable is Clear',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add daily routines or one-time tasks and dynamically choose Alarm, Notification, or Automated WhatsApp alerts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _openAddEditScreen(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.whatsappGreen,
                    foregroundColor: const Color(0xFF042611),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Create First Activity',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _loadSampleTimetable,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                  label: const Text('Load Sample Timetable'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        _buildHeroHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Activities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                '${_reminders.length} scheduled',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: _reminders
                .map(
                  (item) => ReminderCard(
                    reminder: item,
                    defaultWhatsAppNumber: _settings.defaultWhatsAppNumber,
                    onToggleEnabled: (v) => _toggleReminderEnabled(item, v),
                    onEdit: () => _openAddEditScreen(existing: item),
                    onDelete: () => _deleteReminder(item),
                    onTestWhatsApp: () => _testSingleReminderWhatsApp(item),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimetableTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    const dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    // Calculate calendar dates for current week Mon..Sun
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    final filtered = _reminders
        .where((r) => r.occursOnWeekday(_selectedTimetableDay))
        .toList();

    return Column(
      children: [
        // Modern 7-day strip with activity dot indicators
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final dateObj = monday.add(Duration(days: index));
              final selected = _selectedTimetableDay == dayNum;
              final hasEvents =
                  _reminders.any((r) => r.occursOnWeekday(dayNum));

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTimetableDay = dayNum),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppPalette.whatsappGreen
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          dayLabels[index],
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? const Color(0xFF042611)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dateObj.day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? const Color(0xFF042611)
                                : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasEvents
                                ? (selected
                                    ? const Color(0xFF042611)
                                    : AppPalette.whatsappGreen)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Vertical Timeline List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 52,
                        color: cs.onSurfaceVariant.withOpacity(0.45),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Free day on ${dayLabels[_selectedTimetableDay - 1]}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap + to schedule a class, workout, or reminder',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final catColor = AppPalette.categoryColor(item.category);
                    final isLast = index == filtered.length - 1;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Timeline Rail
                          SizedBox(
                            width: 54,
                            child: Column(
                              children: [
                                const SizedBox(height: 6),
                                Text(
                                  item.formattedTime24,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: catColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: catColor.withOpacity(0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      color:
                                          cs.outlineVariant.withOpacity(0.6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ReminderCard(
                              reminder: item,
                              compact: true,
                              defaultWhatsAppNumber:
                                  _settings.defaultWhatsAppNumber,
                              onToggleEnabled: (v) =>
                                  _toggleReminderEnabled(item, v),
                              onEdit: () => _openAddEditScreen(existing: item),
                              onDelete: () => _deleteReminder(item),
                              onTestWhatsApp: () =>
                                  _testSingleReminderWhatsApp(item),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFloatingBottomBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppPalette.darkCardElevated.withOpacity(0.96)
              : Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(isDark ? 0.9 : 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.42 : 0.1),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _DockTabItem(
              icon: Icons.grid_view_rounded,
              label: 'Home',
              selected: _currentTab == 0,
              onTap: () => setState(() => _currentTab = 0),
            ),
            _DockTabItem(
              icon: Icons.calendar_month_rounded,
              label: 'Timetable',
              selected: _currentTab == 1,
              onTap: () => setState(() => _currentTab = 1),
            ),
            _DockTabItem(
              icon: Icons.tune_rounded,
              label: 'Settings',
              selected: _currentTab == 2,
              onTap: () => setState(() => _currentTab = 2),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _openAddEditScreen(),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppPalette.whatsappGreen, Color(0xFF16A34A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.whatsappGreen.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF042611),
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Remindly', 'Timetable', 'Settings'];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: const LinearGradient(
                  colors: [AppPalette.whatsappGreen, AppPalette.cyanAccent],
                ),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 19,
                color: Color(0xFF042611),
              ),
            ),
            const SizedBox(width: 10),
            Text(titles[_currentTab]),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              size: 21,
            ),
          ),
          if (_currentTab != 2)
            IconButton(
              tooltip: 'Sync WhatsApp Server',
              icon: const Icon(Icons.cloud_sync_rounded, size: 22),
              onPressed: _syncAllSchedules,
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentTab,
              children: [
                _buildSchedulesTab(),
                _buildTimetableTab(),
                SettingsScreen(
                  settings: _settings,
                  backendStatus: _backendStatus,
                  onSaveSettings: _saveSettings,
                  onOpenConnectWhatsApp: _openConnectWhatsApp,
                  onDisconnectWhatsApp: _disconnectWhatsApp,
                  onRefreshConnection: _refreshBackendStatus,
                  onSyncAllSchedules: _syncAllSchedules,
                ),
              ],
            ),
      bottomNavigationBar: _buildFloatingBottomBar(),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _HeroStat({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent ?? Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.only(right: 14),
      color: Colors.white.withOpacity(0.14),
    );
  }
}

class _DockTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.whatsappGreen.withOpacity(0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppPalette.whatsappGreen : cs.onSurfaceVariant,
              ),
              if (selected) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.whatsappGreen,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
