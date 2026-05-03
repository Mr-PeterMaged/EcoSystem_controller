import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String controllerIp;
  final bool autoConnect;
  final int refreshIntervalSeconds;
  final bool notificationsEnabled;
  final bool gasAlertsEnabled;
  final bool temperatureAlertsEnabled;
  final bool motionAlertsEnabled;
  final double temperatureWarningThreshold;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.controllerIp = '10.234.227.18',
    this.autoConnect = true,
    this.refreshIntervalSeconds = 2,
    this.notificationsEnabled = true,
    this.gasAlertsEnabled = true,
    this.temperatureAlertsEnabled = true,
    this.motionAlertsEnabled = true,
    this.temperatureWarningThreshold = 35,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? controllerIp,
    bool? autoConnect,
    int? refreshIntervalSeconds,
    bool? notificationsEnabled,
    bool? gasAlertsEnabled,
    bool? temperatureAlertsEnabled,
    bool? motionAlertsEnabled,
    double? temperatureWarningThreshold,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      controllerIp: controllerIp ?? this.controllerIp,
      autoConnect: autoConnect ?? this.autoConnect,
      refreshIntervalSeconds:
          refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      gasAlertsEnabled: gasAlertsEnabled ?? this.gasAlertsEnabled,
      temperatureAlertsEnabled:
          temperatureAlertsEnabled ?? this.temperatureAlertsEnabled,
      motionAlertsEnabled: motionAlertsEnabled ?? this.motionAlertsEnabled,
      temperatureWarningThreshold:
          temperatureWarningThreshold ?? this.temperatureWarningThreshold,
    );
  }
}

class AppSettingsService {
  static const _themeModeKey = 'themeMode';
  static const _controllerIpKey = 'controllerIp';
  static const _autoConnectKey = 'autoConnect';
  static const _refreshIntervalKey = 'refreshIntervalSeconds';
  static const _notificationsEnabledKey = 'notificationsEnabled';
  static const _gasAlertsEnabledKey = 'gasAlertsEnabled';
  static const _temperatureAlertsEnabledKey = 'temperatureAlertsEnabled';
  static const _motionAlertsEnabledKey = 'motionAlertsEnabled';
  static const _temperatureThresholdKey = 'temperatureWarningThreshold';

  static SharedPreferences? _prefs;
  static final ValueNotifier<AppSettings> settingsNotifier =
      ValueNotifier<AppSettings>(const AppSettings());

  static AppSettings get settings => settingsNotifier.value;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    settingsNotifier.value = _readSettings();
  }

  static Future<void> update(AppSettings settings) async {
    settingsNotifier.value = settings;
    await _save(settings);
  }

  static Future<void> reset() async {
    const settings = AppSettings();
    settingsNotifier.value = settings;
    await _save(settings);
  }

  static AppSettings _readSettings() {
    final prefs = _prefs;
    if (prefs == null) return const AppSettings();

    return AppSettings(
      themeMode: _themeModeFromName(prefs.getString(_themeModeKey)),
      controllerIp:
          prefs.getString(_controllerIpKey) ?? const AppSettings().controllerIp,
      autoConnect:
          prefs.getBool(_autoConnectKey) ?? const AppSettings().autoConnect,
      refreshIntervalSeconds:
          prefs.getInt(_refreshIntervalKey) ??
          const AppSettings().refreshIntervalSeconds,
      notificationsEnabled:
          prefs.getBool(_notificationsEnabledKey) ??
          const AppSettings().notificationsEnabled,
      gasAlertsEnabled:
          prefs.getBool(_gasAlertsEnabledKey) ??
          const AppSettings().gasAlertsEnabled,
      temperatureAlertsEnabled:
          prefs.getBool(_temperatureAlertsEnabledKey) ??
          const AppSettings().temperatureAlertsEnabled,
      motionAlertsEnabled:
          prefs.getBool(_motionAlertsEnabledKey) ??
          const AppSettings().motionAlertsEnabled,
      temperatureWarningThreshold:
          prefs.getDouble(_temperatureThresholdKey) ??
          const AppSettings().temperatureWarningThreshold,
    );
  }

  static Future<void> _save(AppSettings settings) async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.setString(_themeModeKey, settings.themeMode.name);
    await prefs.setString(_controllerIpKey, settings.controllerIp);
    await prefs.setBool(_autoConnectKey, settings.autoConnect);
    await prefs.setInt(_refreshIntervalKey, settings.refreshIntervalSeconds);
    await prefs.setBool(
      _notificationsEnabledKey,
      settings.notificationsEnabled,
    );
    await prefs.setBool(_gasAlertsEnabledKey, settings.gasAlertsEnabled);
    await prefs.setBool(
      _temperatureAlertsEnabledKey,
      settings.temperatureAlertsEnabled,
    );
    await prefs.setBool(_motionAlertsEnabledKey, settings.motionAlertsEnabled);
    await prefs.setDouble(
      _temperatureThresholdKey,
      settings.temperatureWarningThreshold,
    );
  }

  static ThemeMode _themeModeFromName(String? name) {
    return switch (name) {
      'system' => ThemeMode.system,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }
}
