import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/app_settings.dart';
import '../models/reminder_model.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_option_tile.dart';

class AddEditReminderScreen extends StatefulWidget {
  final ReminderItem? existing;
  final AppSettings settings;

  const AddEditReminderScreen({
    super.key,
    this.existing,
    required this.settings,
  });

  @override
  State<AddEditReminderScreen> createState() => _AddEditReminderScreenState();
}

class _AddEditReminderScreenState extends State<AddEditReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _customPhoneController;
  late final TextEditingController _customMessageController;

  late String _category;
  late TimeOfDay _selectedTime;
  late bool _isRecurring;
  late DateTime _selectedDate;
  late Set<int> _selectedDays;

  late bool _alarmEnabled;
  late bool _notificationEnabled;
  late bool _whatsappEnabled;
  late bool _useDefaultWhatsAppNumber;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();

    _titleController = TextEditingController(text: e?.title ?? '');
    _noteController = TextEditingController(text: e?.note ?? '');
    _customPhoneController =
        TextEditingController(text: e?.customWhatsAppNumber ?? '');
    _customMessageController =
        TextEditingController(text: e?.customWhatsAppMessage ?? '');

    _category = e?.category ?? ReminderCategories.all.first;
    _selectedTime = e != null
        ? TimeOfDay(hour: e.hour, minute: e.minute)
        : TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));

    _isRecurring = e != null ? e.isRecurring : true;
    _selectedDate = e?.oneTimeDate ?? now;
    _selectedDays = e != null && e.daysOfWeek.isNotEmpty
        ? e.daysOfWeek.toSet()
        : {now.weekday};

    _alarmEnabled = e?.alarmEnabled ?? widget.settings.defaultAlarm;
    _notificationEnabled =
        e?.notificationEnabled ?? widget.settings.defaultNotification;
    _whatsappEnabled = e?.whatsappEnabled ??
        (widget.settings.hasDefaultNumber ? widget.settings.defaultWhatsApp : false);
    _useDefaultWhatsAppNumber = e?.useDefaultWhatsAppNumber ??
        widget.settings.defaultWhatsAppNumber.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _customPhoneController.dispose();
    _customMessageController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() {
    final enteredTitle = _titleController.text.trim();
    final h12 = _selectedTime.hour % 12 == 0 ? 12 : _selectedTime.hour % 12;
    final period = _selectedTime.hour >= 12 ? 'PM' : 'AM';
    final timeStr =
        '${h12.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} $period';
    final effectiveTitle =
        enteredTitle.isNotEmpty ? enteredTitle : 'Reminder at $timeStr';

    if (!_alarmEnabled && !_notificationEnabled && !_whatsappEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select at least one alert option (Alarm, Notification, or WhatsApp).',
          ),
          backgroundColor: AppPalette.roseAccent,
        ),
      );
      return;
    }

    if (_isRecurring && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one weekday for your timetable.'),
          backgroundColor: AppPalette.roseAccent,
        ),
      );
      return;
    }

    final sortedDays =
        _isRecurring ? (_selectedDays.toList()..sort()) : <int>[];

    if (_whatsappEnabled) {
      final phone = _useDefaultWhatsAppNumber
          ? widget.settings.defaultWhatsAppNumber.trim()
          : _customPhoneController.text.trim();
      if (phone.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('WhatsApp Recipient Needed'),
            content: const Text(
              'WhatsApp Alert is toggled ON, but no recipient phone number was entered.\n\nWould you like to save as Alarm & Notification only, or enter a WhatsApp number?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _completeSave(
                    effectiveTitle: effectiveTitle,
                    sortedDays: sortedDays,
                    saveWhatsApp: false,
                  );
                },
                child: const Text('Save without WhatsApp'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _useDefaultWhatsAppNumber = false;
                  });
                },
                child: const Text('Enter Number'),
              ),
            ],
          ),
        );
        return;
      }
    }

    _completeSave(
      effectiveTitle: effectiveTitle,
      sortedDays: sortedDays,
      saveWhatsApp: _whatsappEnabled,
    );
  }

  void _completeSave({
    required String effectiveTitle,
    required List<int> sortedDays,
    required bool saveWhatsApp,
  }) {
    final reminder = ReminderItem(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: effectiveTitle,
      note: _noteController.text.trim(),
      category: _category,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      oneTimeDate: _isRecurring ? null : _selectedDate,
      daysOfWeek: sortedDays,
      alarmEnabled: _alarmEnabled,
      notificationEnabled: _notificationEnabled,
      whatsappEnabled: saveWhatsApp,
      useDefaultWhatsAppNumber: _useDefaultWhatsAppNumber,
      customWhatsAppNumber: _customPhoneController.text.trim(),
      customWhatsAppMessage: _customMessageController.text.trim(),
      isEnabled: widget.existing?.isEnabled ?? true,
      syncedToBackend: false,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(reminder);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final catColor = AppPalette.categoryColor(_category);
    final hasDefaultPhone =
        widget.settings.defaultWhatsAppNumber.trim().isNotEmpty;

    final h12 = _selectedTime.hour % 12 == 0 ? 12 : _selectedTime.hour % 12;
    final timeStr =
        '${h12.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final period = _selectedTime.hour >= 12 ? 'PM' : 'AM';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Activity' : 'Edit Activity'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.whatsappGreen,
                foregroundColor: const Color(0xFF042611),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
          children: [
            // Hero Interactive Digital Clock Time Picker
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            catColor.withOpacity(0.28),
                            AppPalette.darkCard,
                          ]
                        : [
                            catColor.withOpacity(0.16),
                            Colors.white,
                          ],
                  ),
                  border: Border.all(
                    color: catColor.withOpacity(0.45),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCHEDULED TIME',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: catColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.8,
                                color: cs.onSurface,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              period,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: catColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Change',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Activity Title & Note
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Activity Title (optional)',
                hintText: 'e.g. Morning Gym, CS Lecture, Medicine',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Room 204, bring assignment',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 18),

            // Category Horizontal Icon Pills
            _SectionLabel(title: 'Category'),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ReminderCategories.all.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final c = ReminderCategories.all[index];
                  final selected = _category == c;
                  final color = AppPalette.categoryColor(c);
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? color
                            : (isDark
                                ? AppPalette.darkCard
                                : AppPalette.lightCard),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? color : cs.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            ReminderCategories.iconFor(c),
                            size: 16,
                            color: selected ? Colors.white : color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            c.split(' / ').first,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Frequency: Weekly Timetable vs One-Time
            _SectionLabel(title: 'Repeat Schedule'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppPalette.darkCard : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _SegmentPill(
                    label: 'Weekly Timetable',
                    icon: Icons.repeat_rounded,
                    selected: _isRecurring,
                    onTap: () => setState(() => _isRecurring = true),
                  ),
                  _SegmentPill(
                    label: 'One-Time Date',
                    icon: Icons.event_rounded,
                    selected: !_isRecurring,
                    onTap: () => setState(() => _isRecurring = false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_isRecurring) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final dayNum = index + 1;
                  const short = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final isSelected = _selectedDays.contains(dayNum);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDays.remove(dayNum);
                        } else {
                          _selectedDays.add(dayNum);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppPalette.whatsappGreen
                            : (isDark ? AppPalette.darkCard : Colors.white),
                        border: Border.all(
                          color: isSelected
                              ? AppPalette.whatsappGreen
                              : cs.outlineVariant,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppPalette.whatsappGreen
                                      .withOpacity(0.32),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        short[index],
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFF042611)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _QuickPresetChip(
                    label: 'Daily',
                    onTap: () =>
                        setState(() => _selectedDays = {1, 2, 3, 4, 5, 6, 7}),
                  ),
                  const SizedBox(width: 8),
                  _QuickPresetChip(
                    label: 'Weekdays',
                    onTap: () =>
                        setState(() => _selectedDays = {1, 2, 3, 4, 5}),
                  ),
                  const SizedBox(width: 8),
                  _QuickPresetChip(
                    label: 'Weekends',
                    onTap: () => setState(() => _selectedDays = {6, 7}),
                  ),
                ],
              ),
            ] else ...[
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppPalette.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppPalette.whatsappGreen,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Change',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Dynamic Alert Channels
            _SectionLabel(
              title: 'Alert Channels',
              subtitle: 'Pick any combination dynamically for this activity',
            ),
            const SizedBox(height: 10),

            AlertOptionTile(
              icon: Icons.alarm_rounded,
              title: 'Loud Alarm',
              subtitle: 'Rings continuously with Snooze & Dismiss screen',
              badgeText: 'OFFLINE',
              accentColor: AppPalette.alarmCoral,
              selected: _alarmEnabled,
              onChanged: (v) => setState(() => _alarmEnabled = v),
            ),
            const SizedBox(height: 10),

            AlertOptionTile(
              icon: Icons.notifications_active_rounded,
              title: 'Push Notification',
              subtitle: 'Clean banner alert in your notification tray',
              badgeText: 'OFFLINE',
              accentColor: AppPalette.notifIndigo,
              selected: _notificationEnabled,
              onChanged: (v) => setState(() => _notificationEnabled = v),
            ),
            const SizedBox(height: 10),

            AlertOptionTile(
              icon: Icons.chat_bubble_rounded,
              title: 'Automated WhatsApp',
              subtitle: 'Sends a WhatsApp message automatically on time',
              badgeText: 'AUTO-SEND',
              accentColor: AppPalette.whatsappGreen,
              selected: _whatsappEnabled,
              onChanged: (v) => setState(() => _whatsappEnabled = v),
            ),

            // Collapsible WhatsApp Recipient Selector
            if (_whatsappEnabled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPalette.whatsappGreen
                      .withOpacity(isDark ? 0.1 : 0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppPalette.whatsappGreen.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.person_pin_circle_rounded,
                          size: 18,
                          color: AppPalette.whatsappGreen,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'WhatsApp Recipient',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _RecipientChoicePill(
                            title: 'My Number',
                            subtitle: hasDefaultPhone
                                ? widget.settings.defaultWhatsAppNumber
                                : 'Not set',
                            selected: _useDefaultWhatsAppNumber,
                            enabled: hasDefaultPhone,
                            onTap: () => setState(
                              () => _useDefaultWhatsAppNumber = true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RecipientChoicePill(
                            title: 'Other Contact',
                            subtitle: 'Enter number',
                            selected: !_useDefaultWhatsAppNumber,
                            enabled: true,
                            onTap: () => setState(
                              () => _useDefaultWhatsAppNumber = false,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_useDefaultWhatsAppNumber) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _customPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact WhatsApp Number',
                          hintText: 'Country code + number, e.g. 923001234567',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _customMessageController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Custom WhatsApp Message (optional)',
                        hintText: 'Auto-formatted from title & time if empty',
                        prefixIcon: Icon(Icons.message_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.whatsappGreen,
                  foregroundColor: const Color(0xFF042611),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'Save Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionLabel({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: cs.onSurface,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _SegmentPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentPill({
    required this.label,
    required this.icon,
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
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
                  fontSize: 12.5,
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

class _QuickPresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickPresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _RecipientChoicePill extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RecipientChoicePill({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.whatsappGreen.withOpacity(isDark ? 0.25 : 0.16)
                : (isDark ? AppPalette.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppPalette.whatsappGreen : cs.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppPalette.whatsappGreen : cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
