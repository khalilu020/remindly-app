import 'package:flutter/material.dart';
import '../models/reminder_model.dart';
import '../theme/app_theme.dart';

class ReminderCard extends StatelessWidget {
  final ReminderItem reminder;
  final String defaultWhatsAppNumber;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTestWhatsApp;
  final bool compact;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.defaultWhatsAppNumber,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
    this.onTestWhatsApp,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final catColor = AppPalette.categoryColor(reminder.category);
    final resolvedPhone = reminder.resolvePhoneNumber(defaultWhatsAppNumber);

    final period = reminder.hour >= 12 ? 'PM' : 'AM';
    final h12 = reminder.hour % 12 == 0 ? 12 : reminder.hour % 12;
    final timeMain =
        '${h12.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: reminder.isEnabled
              ? cs.outlineVariant.withOpacity(isDark ? 0.9 : 0.7)
              : cs.outlineVariant.withOpacity(0.35),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: reminder.isEnabled ? 1.0 : 0.48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Glowing vertical category accent stripe
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [catColor, catColor.withOpacity(0.45)],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 12 : 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: Time + Category badge + Switch + Menu
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (!compact) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        timeMain,
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        period,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: catColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        ReminderCategories.iconFor(
                                          reminder.category,
                                        ),
                                        size: 13,
                                        color: catColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        reminder.category.split(' / ').first,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: catColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Transform.scale(
                                  scale: 0.84,
                                  child: Switch(
                                    value: reminder.isEnabled,
                                    activeColor: Colors.white,
                                    activeTrackColor: AppPalette.whatsappGreen,
                                    onChanged: onToggleEnabled,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    size: 20,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  onSelected: (action) {
                                    if (action == 'edit') onEdit();
                                    if (action == 'test') onTestWhatsApp?.call();
                                    if (action == 'delete') onDelete();
                                  },
                                  itemBuilder: (_) => [
                                    if (reminder.whatsappEnabled &&
                                        onTestWhatsApp != null)
                                      const PopupMenuItem(
                                        value: 'test',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.send_rounded,
                                              size: 18,
                                              color: AppPalette.whatsappGreen,
                                            ),
                                            SizedBox(width: 10),
                                            Text('Send WhatsApp Now'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 10),
                                          Text('Edit Activity'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: AppPalette.roseAccent,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: AppPalette.roseAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Activity title & optional note
                            Text(
                              reminder.title,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (reminder.note.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                reminder.note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],

                            const SizedBox(height: 10),

                            // Repeat & Active Channels pills
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _ChannelPill(
                                  icon: reminder.isRecurring
                                      ? Icons.repeat_rounded
                                      : Icons.event_rounded,
                                  label: reminder.scheduleSummary,
                                  color: cs.onSurfaceVariant,
                                  neutral: true,
                                ),
                                if (reminder.alarmEnabled)
                                  const _ChannelPill(
                                    icon: Icons.alarm_rounded,
                                    label: 'Alarm',
                                    color: AppPalette.alarmCoral,
                                  ),
                                if (reminder.notificationEnabled)
                                  const _ChannelPill(
                                    icon: Icons.notifications_rounded,
                                    label: 'Alert',
                                    color: AppPalette.notifIndigo,
                                  ),
                                if (reminder.whatsappEnabled)
                                  _ChannelPill(
                                    icon: Icons.chat_bubble_rounded,
                                    label: resolvedPhone.isNotEmpty
                                        ? resolvedPhone
                                        : 'WhatsApp',
                                    color: AppPalette.whatsappGreen,
                                    trailingIcon: reminder.syncedToBackend
                                        ? Icons.cloud_done_rounded
                                        : Icons.cloud_off_rounded,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool neutral;
  final IconData? trailingIcon;

  const _ChannelPill({
    required this.icon,
    required this.label,
    required this.color,
    this.neutral = false,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4.5),
      decoration: BoxDecoration(
        color: neutral
            ? (isDark ? AppPalette.darkCardElevated : const Color(0xFFF1F5F9))
            : color.withOpacity(isDark ? 0.17 : 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: color),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 12, color: color),
          ],
        ],
      ),
    );
  }
}
