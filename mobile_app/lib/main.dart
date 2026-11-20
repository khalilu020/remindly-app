import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const WhatsAppReminderApp());
}

class WhatsAppReminderApp extends StatefulWidget {
  const WhatsAppReminderApp({super.key});

  @override
  State<WhatsAppReminderApp> createState() => _WhatsAppReminderAppState();
}

class _WhatsAppReminderAppState extends State<WhatsAppReminderApp> {
  bool _isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remindly — WhatsApp Reminder',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            // Full-screen edge-to-edge on actual mobile phones
            if (constraints.maxWidth <= 520) {
              return child;
            }

            // Sleek realistic smartphone bezel preview on wide desktop screens
            const double phoneWidth = 406;
            final double phoneHeight =
                (constraints.maxHeight - 28).clamp(360.0, 852.0);
            final mq = MediaQuery.of(context);

            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.1,
                  colors: _isDarkMode
                      ? const [Color(0xFF132238), Color(0xFF050811)]
                      : const [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: phoneWidth,
                height: phoneHeight,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(
                    color: const Color(0xFF334155),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 44,
                      offset: Offset(0, 22),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(9),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: Stack(
                    children: [
                      MediaQuery(
                        data: mq.copyWith(
                          size: Size(phoneWidth - 24, phoneHeight - 24),
                          padding: const EdgeInsets.only(top: 18, bottom: 10),
                        ),
                        child: child,
                      ),
                      // Subtle top dynamic speaker pill
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 84,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      // Bottom home indicator bar
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: IgnorePointer(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            width: 112,
                            height: 4,
                            decoration: BoxDecoration(
                              color: (_isDarkMode ? Colors.white : Colors.black)
                                  .withOpacity(0.28),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      home: HomeScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: () => setState(() => _isDarkMode = !_isDarkMode),
      ),
    );
  }
}
