import 'package:flutter/material.dart';
import 'screens/loading_screen.dart';
import 'services/app_settings_service.dart';
import 'services/automation_service.dart';
import 'services/notification_service.dart';
import 'services/user_storage_service.dart';
import 'theme_notifier.dart';
import 'app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsService.init();
  await UserStorageService.init();
  final settings = AppSettingsService.settings;
  themeNotifier.value = ThemeState(
    mode: settings.themeMode,
    accentColor: Color(settings.accentColorValue),
  );
  await NotificationService.init();
  AutomationService.start();
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeState>(
      valueListenable: themeNotifier,
      builder: (_, state, _) => MaterialApp(
        title: 'Smart Home',
        debugShowCheckedModeBanner: false,
        themeMode: state.mode,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.light(primary: state.accentColor),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBgDark,
          colorScheme: ColorScheme.dark(
            primary: state.accentColor,
            surface: kBgDarkSurface,
          ),
          useMaterial3: true,
        ),
        home: const LoadingScreen(),
      ),
    );
  }
}
