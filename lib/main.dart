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
  try {
    await AppSettingsService.init();
    await UserStorageService.init();
    final settings = AppSettingsService.settings;
    themeNotifier.value = ThemeState(
      mode: settings.themeMode,
      accentColor: Color(settings.accentColorValue),
    );
    await NotificationService.init();
    AutomationService.start();
  } catch (_) {
    // Ensure runApp() is always reached even if initialization partially fails.
  }
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  ThemeData _buildTheme({
    required Brightness brightness,
    required Color accent,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          secondary: accent,
          tertiary: accent,
          surface: isDark ? kBgDarkSurface : Colors.white,
        );
    final scaffoldBg = isDark ? kBgDark : Colors.white;
    final appBarBg = isDark ? kAppBarDark : Colors.white;
    final onSurface = isDark ? Colors.white : kTextPrimary;

    WidgetStateProperty<Color?> selectedColor(Color color) =>
        WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? color : null,
        );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        circularTrackColor: accent.withValues(alpha: 0.16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: selectedColor(accent),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.42)
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: selectedColor(accent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      radioTheme: RadioThemeData(fillColor: selectedColor(accent)),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.14),
      ),
      chipTheme: ChipThemeData(
        selectedColor: accent.withValues(alpha: 0.18),
        checkmarkColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? kBgDarkSurface : kTextPrimary,
        actionTextColor: accent,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        floatingLabelStyle: TextStyle(color: accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeState>(
      valueListenable: themeNotifier,
      builder: (_, state, _) => MaterialApp(
        title: 'Smart Home',
        debugShowCheckedModeBanner: false,
        themeMode: state.mode,
        theme: _buildTheme(
          brightness: Brightness.light,
          accent: state.accentColor,
        ),
        darkTheme: _buildTheme(
          brightness: Brightness.dark,
          accent: state.accentColor,
        ),
        home: const LoadingScreen(),
      ),
    );
  }
}
