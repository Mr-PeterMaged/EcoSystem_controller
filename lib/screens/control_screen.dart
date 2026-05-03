import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../services/connection_service.dart';
import '../widgets/control_button.dart';
import '../app_constants.dart';
import 'about_screen.dart';
import 'notifications_screen.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  Map<String, dynamic> _status = {
    'system': true,
    'gasSensor': true,
    'tempSensor': true,
    'ledSensor': true,
    'pirSensor': true,
    'ldrSensor': true,
    'buzzer': true,
    'autoLight': true,
    'temperature': 0,
    'humidity': 0,
    'gasDetected': false,
    'led2': false,
    'locked': true,
    'gasPercent': 0,
  };

  Timer? _timer;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    AppSettingsService.settingsNotifier.addListener(_startPolling);
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _fetchStatus();
    final seconds = AppSettingsService.settings.refreshIntervalSeconds;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => _fetchStatus());
  }

  Future<void> _fetchStatus() async {
    final data = await ConnectionService.getStatus();
    if (data != null && mounted) {
      setState(() {
        _status = data;
        _isConnected = true;
      });
    } else if (mounted) {
      setState(() => _isConnected = false);
    }
  }

  Future<void> _toggle(String key) async {
    if (!(_status['system'] as bool) && key != 'system') return;
    final newVal = !(_status[key] as bool);
    final result = await ConnectionService.sendControl({key: newVal});
    if (result != null && mounted) setState(() => _status = result);
  }

  @override
  void dispose() {
    AppSettingsService.settingsNotifier.removeListener(_startPolling);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final systemOn = _status['system'] as bool;
    final gasDetected = _status['gasDetected'] as bool;

    final List<(String, String, bool)> devices = [
      ('system', 'System', true),
      ('gasSensor', 'Gas Sensor', systemOn),
      ('tempSensor', 'Temperature', systemOn),
      ('ledSensor', 'LEDs', systemOn),
      ('pirSensor', 'PIR', systemOn),
      ('ldrSensor', 'LDR', systemOn),
      ('buzzer', 'Buzzer', systemOn),
      ('autoLight', 'Auto Light', systemOn),
    ];

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
          'Full Control',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  if (gasDetected)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'About Us',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
            icon: Icon(
              Icons.info_outline,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? 'Connected' : 'No Connection',
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: devices.length,
                  itemBuilder: (_, i) {
                    final (key, label, enabled) = devices[i];
                    return ControlButton(
                      label: label,
                      isOn: _status[key] as bool,
                      enabled: enabled,
                      onTap: () => _toggle(key),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
