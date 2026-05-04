import 'dart:async';
import '../app_constants.dart';
import '../models/automation_task.dart';
import 'app_settings_service.dart';
import 'connection_service.dart';

class AutomationService {
  static Timer? _timer;
  static final Set<String> _executed = {};

  static void start() {
    _timer?.cancel();
    _checkTasks();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkTasks());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _checkTasks() async {
    final now = DateTime.now();
    final tasks = AppSettingsService.settings.automationTasks;
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final task in tasks) {
      if (!task.enabled) continue;
      if (task.hour != now.hour || task.minute != now.minute) continue;

      final execKey = '${task.id}::$dateKey';
      if (_executed.contains(execKey)) continue;
      _executed.add(execKey);

      await _executeTask(task);

      if (task.repeat == RepeatMode.once) {
        final current = AppSettingsService.settings.automationTasks;
        final updated =
            current
                .map((t) => t.id == task.id ? t.copyWith(enabled: false) : t)
                .toList();
        await AppSettingsService.update(
          AppSettingsService.settings.copyWith(automationTasks: updated),
        );
      }
    }

    _executed.removeWhere((key) => !key.endsWith('::$dateKey'));
  }

  static Future<void> _executeTask(AutomationTask task) async {
    if (task.deviceKey == 'ecoMode') {
      await ConnectionService.sendControl(
        Map<String, dynamic>.from(kPowerSaveEco),
      );
    } else if (task.deviceKey == 'deepSave') {
      await ConnectionService.sendControl(
        Map<String, dynamic>.from(kPowerSaveDeep),
      );
    } else {
      await ConnectionService.sendControl({task.deviceKey: task.targetValue});
    }
  }
}
