import 'package:flutter/material.dart';

import '../app_constants.dart';
import '../services/app_settings_service.dart';
import '../services/notification_service.dart';
import '../theme_notifier.dart';

class DisplayScreen extends StatefulWidget {
  const DisplayScreen({super.key});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  late final TextEditingController _ipCtrl;
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = AppSettingsService.settings;
    _ipCtrl = TextEditingController(text: _settings.controllerIp);
    AppSettingsService.settingsNotifier.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    AppSettingsService.settingsNotifier.removeListener(_onSettingsChanged);
    _ipCtrl.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    final settings = AppSettingsService.settings;
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _update(AppSettings settings) async {
    await AppSettingsService.update(settings);
  }

  Future<void> _setTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    await _update(_settings.copyWith(themeMode: mode));
  }

  Future<void> _saveConnection() async {
    await _update(_settings.copyWith(controllerIp: _ipCtrl.text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Connection settings saved')));
  }

  Future<void> _resetSettings() async {
    await AppSettingsService.reset();
    themeNotifier.value = AppSettingsService.settings.themeMode;
    _ipCtrl.text = AppSettingsService.settings.controllerIp;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings reset to default')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final cardBg = isDark ? kCardDark : kCardLight;

    return Scaffold(
      backgroundColor: isDark ? kBgDark : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? kAppBarDark : Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: kGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: Text(
          'App Settings',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            _sectionTitle('Display', textColor),
            _panel(
              isDark: isDark,
              cardBg: cardBg,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _themeOption(
                          label: 'System',
                          icon: Icons.phone_android,
                          mode: ThemeMode.system,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _themeOption(
                          label: 'Light',
                          icon: Icons.light_mode,
                          mode: ThemeMode.light,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _themeOption(
                          label: 'Dark',
                          icon: Icons.dark_mode,
                          mode: ThemeMode.dark,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle('Connection', textColor),
            _panel(
              isDark: isDark,
              cardBg: cardBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Controller IP Address',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ipField(isDark, textColor),
                  const SizedBox(height: 12),
                  _settingsSwitch(
                    title: 'Auto connect',
                    subtitle: 'Use the saved controller address on login',
                    value: _settings.autoConnect,
                    isDark: isDark,
                    onChanged: (value) =>
                        _update(_settings.copyWith(autoConnect: value)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Refresh interval',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [2, 5, 10, 30]
                        .map(
                          (seconds) =>
                              _intervalOption(seconds, isDark, textColor),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saveConnection,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle('Alerts', textColor),
            _panel(
              isDark: isDark,
              cardBg: cardBg,
              child: Column(
                children: [
                  _settingsSwitch(
                    title: 'Notifications',
                    subtitle: 'Enable smart home alerts',
                    value: _settings.notificationsEnabled,
                    isDark: isDark,
                    onChanged: (value) => _update(
                      _settings.copyWith(notificationsEnabled: value),
                    ),
                  ),
                  _settingsSwitch(
                    title: 'Gas alerts',
                    subtitle: 'Warn when gas is detected',
                    value: _settings.gasAlertsEnabled,
                    isDark: isDark,
                    onChanged: _settings.notificationsEnabled
                        ? (value) => _update(
                            _settings.copyWith(gasAlertsEnabled: value),
                          )
                        : null,
                  ),
                  _settingsSwitch(
                    title: 'Temperature alerts',
                    subtitle: 'Warn above the selected threshold',
                    value: _settings.temperatureAlertsEnabled,
                    isDark: isDark,
                    onChanged: _settings.notificationsEnabled
                        ? (value) => _update(
                            _settings.copyWith(temperatureAlertsEnabled: value),
                          )
                        : null,
                  ),
                  _settingsSwitch(
                    title: 'Motion alerts',
                    subtitle: 'Warn when PIR motion is detected',
                    value: _settings.motionAlertsEnabled,
                    isDark: isDark,
                    onChanged: _settings.notificationsEnabled
                        ? (value) => _update(
                            _settings.copyWith(motionAlertsEnabled: value),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Temperature threshold',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${_settings.temperatureWarningThreshold.round()} C',
                        style: const TextStyle(
                          color: kGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _settings.temperatureWarningThreshold,
                    min: 20,
                    max: 60,
                    divisions: 40,
                    activeColor: kGreen,
                    label: '${_settings.temperatureWarningThreshold.round()} C',
                    onChanged: _settings.notificationsEnabled
                        ? (value) => _update(
                            _settings.copyWith(
                              temperatureWarningThreshold: value,
                            ),
                          )
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => NotificationService.show(
                        'Smart Home Test',
                        'Notifications are working correctly.',
                        force: true,
                      ),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Test alert'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _panel(
              isDark: isDark,
              cardBg: cardBg,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: subColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Settings are saved on this device and applied automatically.',
                      style: TextStyle(color: subColor, height: 1.4),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetSettings,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _panel({
    required bool isDark,
    required Color cardBg,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: child,
    );
  }

  Widget _themeOption({
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required bool isDark,
  }) {
    final selected = _settings.themeMode == mode;
    return GestureDetector(
      onTap: () => _setTheme(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 86,
        decoration: BoxDecoration(
          color: selected
              ? kGreen.withValues(alpha: 0.14)
              : (isDark ? kBgDarkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? kGreen
                : (isDark ? Colors.white12 : Colors.black12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? kGreen : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? kGreen
                    : (isDark ? Colors.white70 : kTextPrimary),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ipField(bool isDark, Color textColor) {
    return TextField(
      controller: _ipCtrl,
      keyboardType: TextInputType.url,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: '192.168.1.100',
        prefixIcon: const Icon(Icons.wifi),
        filled: true,
        fillColor: isDark ? kBgDarkSurface : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _intervalOption(int seconds, bool isDark, Color textColor) {
    final selected = _settings.refreshIntervalSeconds == seconds;
    return ChoiceChip(
      label: Text('${seconds}s'),
      selected: selected,
      selectedColor: kGreen.withValues(alpha: 0.18),
      checkmarkColor: kGreen,
      labelStyle: TextStyle(
        color: selected ? kGreen : textColor,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: isDark ? kBgDarkSurface : Colors.white,
      side: BorderSide(color: selected ? kGreen : Colors.transparent),
      onSelected: (_) =>
          _update(_settings.copyWith(refreshIntervalSeconds: seconds)),
    );
  }

  Widget _settingsSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : kTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
      ),
      value: value,
      activeThumbColor: kGreen,
      onChanged: onChanged,
    );
  }
}
