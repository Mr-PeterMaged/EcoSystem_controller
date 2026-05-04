import 'package:flutter/material.dart' hide RepeatMode;
import '../app_constants.dart';
import '../models/automation_task.dart';
import '../services/app_settings_service.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  List<AutomationTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _tasks = AppSettingsService.settings.automationTasks;
    AppSettingsService.settingsNotifier.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    AppSettingsService.settingsNotifier.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() => _tasks = AppSettingsService.settings.automationTasks);
  }

  Future<void> _saveTasks(List<AutomationTask> tasks) async {
    await AppSettingsService.update(
      AppSettingsService.settings.copyWith(automationTasks: tasks),
    );
  }

  Future<void> _deleteTask(String id) async {
    await _saveTasks(_tasks.where((t) => t.id != id).toList());
  }

  Future<void> _toggleEnabled(AutomationTask task) async {
    await _saveTasks(
      _tasks
          .map((t) => t.id == task.id ? t.copyWith(enabled: !t.enabled) : t)
          .toList(),
    );
  }

  Future<void> _showTaskDialog({AutomationTask? existing}) async {
    final result = await showDialog<AutomationTask>(
      context: context,
      builder: (_) => _TaskDialog(task: existing),
    );
    if (result != null && mounted) {
      final updated = existing == null
          ? [..._tasks, result]
          : _tasks.map((t) => t.id == existing.id ? result : t).toList();
      await _saveTasks(updated);
    }
  }

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
          'Automation',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _tasks.isEmpty
          ? _emptyState(isDark, textColor, accent)
          : _tasksList(isDark, textColor, accent),
    );
  }

  Widget _emptyState(bool isDark, Color textColor, Color accent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: accent.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No automation tasks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to schedule a device action',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tasksList(bool isDark, Color textColor, Color accent) {
    final cardBg = isDark ? kCardDark : kCardLight;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final task = _tasks[i];
        return Dismissible(
          key: ValueKey(task.id),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _deleteTask(task.id),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: task.enabled
                      ? accent.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule,
                  color: task.enabled ? accent : Colors.grey,
                  size: 22,
                ),
              ),
              title: Text(
                task.name,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _taskSubtitle(task),
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch.adaptive(
                    value: task.enabled,
                    activeThumbColor: accent,
                    onChanged: (_) => _toggleEnabled(task),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: isDark ? Colors.white54 : Colors.black45,
                    onPressed: () => _showTaskDialog(existing: task),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _taskSubtitle(AutomationTask task) {
    final time =
        '${task.hour.toString().padLeft(2, '0')}:${task.minute.toString().padLeft(2, '0')}';
    final repeatStr = task.repeat == RepeatMode.daily ? 'Daily' : 'Once';
    final String action;
    if (task.deviceKey == 'ecoMode') {
      action = 'Apply Eco Mode';
    } else if (task.deviceKey == 'deepSave') {
      action = 'Apply Deep Save';
    } else {
      action = '${task.deviceLabel}: ${task.targetValue ? 'ON' : 'OFF'}';
    }
    return '$action at $time · $repeatStr';
  }
}

class _TaskDialog extends StatefulWidget {
  final AutomationTask? task;

  const _TaskDialog({this.task});

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _nameCtrl;
  late String _deviceKey;
  late bool _targetValue;
  late int _hour;
  late int _minute;
  late RepeatMode _repeat;

  static const _deviceOptions = <String, String>{
    'system': 'System',
    'gasSensor': 'Gas Sensor',
    'tempSensor': 'Temperature',
    'ledSensor': 'LEDs',
    'pirSensor': 'PIR',
    'ldrSensor': 'LDR',
    'buzzer': 'Buzzer',
    'autoLight': 'Auto Light',
    'ecoMode': 'Eco Mode',
    'deepSave': 'Deep Save',
  };

  bool get _isPowerSave =>
      _deviceKey == 'ecoMode' || _deviceKey == 'deepSave';

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _deviceKey = t?.deviceKey ?? 'ledSensor';
    _targetValue = t?.targetValue ?? false;
    _hour = t?.hour ?? 22;
    _minute = t?.minute ?? 0;
    _repeat = t?.repeat ?? RepeatMode.daily;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final task = AutomationTask(
      id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      deviceKey: _deviceKey,
      deviceLabel: _deviceOptions[_deviceKey] ?? _deviceKey,
      targetValue: _isPowerSave ? true : _targetValue,
      hour: _hour,
      minute: _minute,
      enabled: widget.task?.enabled ?? true,
      repeat: _repeat,
    );
    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final timeStr =
        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Task Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Device / Mode',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _deviceKey,
                  isDense: true,
                  items: _deviceOptions.entries
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.key, child: Text(e.value)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _deviceKey = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (!_isPowerSave) ...[
              const Text(
                'Action',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Turn ON'),
                    icon: Icon(Icons.power, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Turn OFF'),
                    icon: Icon(Icons.power_off, size: 16),
                  ),
                ],
                selected: {_targetValue},
                onSelectionChanged: (v) =>
                    setState(() => _targetValue = v.first),
                style: ButtonStyle(
                  iconColor: WidgetStatePropertyAll(accent),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text('Time', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: accent),
                    const SizedBox(width: 10),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Repeat',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<RepeatMode>(
              segments: const [
                ButtonSegment(
                  value: RepeatMode.daily,
                  label: Text('Daily'),
                  icon: Icon(Icons.repeat, size: 16),
                ),
                ButtonSegment(
                  value: RepeatMode.once,
                  label: Text('Once'),
                  icon: Icon(Icons.looks_one_outlined, size: 16),
                ),
              ],
              selected: {_repeat},
              onSelectionChanged: (v) => setState(() => _repeat = v.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: Text(widget.task == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
