import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Uses notification IDs 100–101 to avoid conflict with EcoSystem alerts.
class WeatherNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channelId = 'weather_daily';
  static const _channelName = 'Daily Weather';

  static Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<void> showNow({
    required String city,
    required String condition,
    required double tempC,
  }) async {
    if (!_ready) await init();
    await _plugin.show(
      100,
      '🌤 Today\'s Weather — $city',
      '$condition  •  ${tempC.round()}°C',
      _details(),
    );
  }

  static Future<void> scheduleDailyMorning({
    required String city,
    required String condition,
    required double tempC,
  }) async {
    if (!_ready) await init();
    await _plugin.cancel(101);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      101,
      '☀ Good Morning! Daily Weather',
      '$city: $condition  •  ${tempC.round()}°C',
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAll() async => _plugin.cancelAll();

  static NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Daily weather updates from EcoSystem',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      );
}
