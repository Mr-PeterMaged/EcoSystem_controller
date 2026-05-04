import 'dart:convert';

enum RepeatMode { once, daily }

class AutomationTask {
  final String id;
  final String name;
  final String deviceKey;
  final String deviceLabel;
  final bool targetValue;
  final int hour;
  final int minute;
  final bool enabled;
  final RepeatMode repeat;

  const AutomationTask({
    required this.id,
    required this.name,
    required this.deviceKey,
    required this.deviceLabel,
    required this.targetValue,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.repeat = RepeatMode.daily,
  });

  AutomationTask copyWith({
    String? id,
    String? name,
    String? deviceKey,
    String? deviceLabel,
    bool? targetValue,
    int? hour,
    int? minute,
    bool? enabled,
    RepeatMode? repeat,
  }) => AutomationTask(
    id: id ?? this.id,
    name: name ?? this.name,
    deviceKey: deviceKey ?? this.deviceKey,
    deviceLabel: deviceLabel ?? this.deviceLabel,
    targetValue: targetValue ?? this.targetValue,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    enabled: enabled ?? this.enabled,
    repeat: repeat ?? this.repeat,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'deviceKey': deviceKey,
    'deviceLabel': deviceLabel,
    'targetValue': targetValue,
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
    'repeat': repeat.name,
  };

  factory AutomationTask.fromJson(Map<String, dynamic> json) => AutomationTask(
    id: json['id'] as String,
    name: json['name'] as String,
    deviceKey: json['deviceKey'] as String,
    deviceLabel: (json['deviceLabel'] as String?) ?? (json['deviceKey'] as String),
    targetValue: json['targetValue'] as bool,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    enabled: (json['enabled'] as bool?) ?? true,
    repeat: RepeatMode.values.firstWhere(
      (e) => e.name == json['repeat'],
      orElse: () => RepeatMode.daily,
    ),
  );

  static List<AutomationTask> listFromJson(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      final list = jsonDecode(jsonString) as List;
      return list
          .map((e) => AutomationTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<AutomationTask> tasks) =>
      jsonEncode(tasks.map((e) => e.toJson()).toList());
}
