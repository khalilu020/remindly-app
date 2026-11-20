import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Full-screen alarm alert shown when an alarm notification is opened.
class AlarmRingScreen extends StatefulWidget {
  final String title;
  final String note;
  final String scheduledTime;

  const AlarmRingScreen({
    super.key,
    required this.title,
    required this.note,
    required this.scheduledTime,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _snooze() async {
    await NotificationService.instance.snoozeAlarm(
      title: widget.title,
      note: widget.note,
      minutes: 5,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarm snoozed for 5 minutes.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.08)
                    .animate(_pulseController),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepOrange.withOpacity(0.2),
                    border: Border.all(color: Colors.deepOrange, width: 3),
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    color: Colors.deepOrangeAccent,
                    size: 62,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                widget.scheduledTime,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  widget.note,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _snooze,
                      icon: const Icon(Icons.snooze_rounded),
                      label: const Text('Snooze 5m'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Dismiss'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

