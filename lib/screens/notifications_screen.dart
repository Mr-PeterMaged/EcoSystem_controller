import 'package:flutter/material.dart';

import '../app_constants.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? kBgDark : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? kAppBarDark : Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear notifications',
            onPressed: NotificationService.clearHistory,
            icon: Icon(
              Icons.delete_outline,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<SmartHomeNotification>>(
          valueListenable: NotificationService.alertsNotifier,
          builder: (_, alerts, _) {
            if (alerts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 80,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              itemCount: alerts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) =>
                  _NotificationTile(alert: alerts[index], isDark: isDark),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final SmartHomeNotification alert;
  final bool isDark;

  const _NotificationTile({required this.alert, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : kTextPrimary;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final cardBg = isDark ? kCardDark : kCardLight;
    final iconData = switch (alert.category) {
      'Gas' => Icons.warning_amber_rounded,
      'Temperature' => Icons.thermostat,
      'Motion' => Icons.directions_run,
      'Sensor' => Icons.sensors_off,
      _ => Icons.notifications_active_outlined,
    };
    final iconColor = switch (alert.category) {
      'Gas' => Colors.red,
      'Temperature' => Colors.orange,
      'Motion' => Theme.of(context).colorScheme.primary,
      'Sensor' => Colors.red,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      _time(alert.createdAt),
                      style: TextStyle(color: subColor, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  alert.body,
                  style: TextStyle(color: subColor, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  alert.category,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
