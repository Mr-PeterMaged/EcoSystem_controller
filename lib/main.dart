import 'package:flutter/material.dart';
import 'screens/loading_screen.dart';
import 'services/app_settings_service.dart';
import 'services/notification_service.dart';
import 'theme_notifier.dart';
import 'app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsService.init();
  themeNotifier.value = AppSettingsService.settings.themeMode;
  await NotificationService.init();
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) => MaterialApp(
        title: 'Smart Home',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(primary: kGreen),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBgDark,
          colorScheme: const ColorScheme.dark(
            primary: kGreen,
            surface: kBgDarkSurface,
          ),
          useMaterial3: true,
        ),
        home: const LoadingScreen(),
      ),
    );
  }
}
