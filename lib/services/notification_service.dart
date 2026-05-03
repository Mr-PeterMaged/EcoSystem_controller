import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_settings_service.dart';

class SmartHomeNotification {
  final String title;
  final String body;
  final String category;
  final DateTime createdAt;

  const SmartHomeNotification({
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final ValueNotifier<List<SmartHomeNotification>> alertsNotifier =
      ValueNotifier<List<SmartHomeNotification>>([]);

  static Future<void> init() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
    );
    await _plugin.initialize(settings);
  }

  static Future<void> show(
    String title,
    String body, {
    String category = 'System',
    bool force = false,
  }) async {
    final settings = AppSettingsService.settings;
    if (!force && !settings.notificationsEnabled) return;

    _addToHistory(
      SmartHomeNotification(
        title: title,
        body: body,
        category: category,
        createdAt: DateTime.now(),
      ),
    );

    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'smart_home_channel',
      'Smart Home Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: android);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _plugin.show(id, title, body, details);
  }

  static Future<void> gasAlert() async {
    final settings = AppSettingsService.settings;
    if (!settings.gasAlertsEnabled) return;
    await show('Gas Alert', 'Gas detected in your home.', category: 'Gas');
  }

  static Future<void> temperatureAlert(num temperature) async {
    final settings = AppSettingsService.settings;
    if (!settings.temperatureAlertsEnabled) return;
    await show(
      'Temperature Warning',
      'Temperature reached ${temperature.round()} C.',
      category: 'Temperature',
    );
  }

  static Future<void> motionAlert() async {
    final settings = AppSettingsService.settings;
    if (!settings.motionAlertsEnabled) return;
    await show(
      'Motion Detected',
      'PIR sensor detected motion.',
      category: 'Motion',
    );
  }

  static Future<void> mq2Error() async {
    await show('MQ2 Error', 'Gas sensor is disconnected.', category: 'Sensor');
  }

  static void clearHistory() {
    alertsNotifier.value = [];
  }

  static void _addToHistory(SmartHomeNotification notification) {
    final next = [notification, ...alertsNotifier.value];
    alertsNotifier.value = next.take(30).toList();
  }
}
