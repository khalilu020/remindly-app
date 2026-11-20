import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Sleek interactive channel card for toggling Alarm, Push Notification,
/// or Automated WhatsApp Message dynamically.
class AlertOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color accentColor;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const AlertOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.accentColor,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(isDark ? 0.22 : 0.14),
                    accentColor.withOpacity(isDark ? 0.08 : 0.04),
                  ],
                )
              : null,
          color: selected
              ? null
              : (isDark ? AppPalette.darkCard : AppPalette.lightCard),
          border: Border.all(
            color: selected
                ? accentColor.withOpacity(0.85)
                : cs.outlineVariant.withOpacity(0.75),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? accentColor
                    : (isDark
                        ? AppPalette.darkCardElevated
                        : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: selected ? accentColor : cs.onSurfaceVariant.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
