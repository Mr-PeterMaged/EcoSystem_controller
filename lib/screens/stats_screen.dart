import 'dart:async';

import 'package:flutter/material.dart';

import '../app_constants.dart';
import '../services/app_settings_service.dart';
import '../services/connection_service.dart';
import '../widgets/green_button.dart';
import 'about_screen.dart';
import 'notifications_screen.dart';

class StatsScreen extends StatefulWidget {
  final Map<String, dynamic> status;

  const StatsScreen({super.key, required this.status});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Map<String, dynamic> _status;
  Timer? _timer;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _status = Map.from(widget.status);
    AppSettingsService.settingsNotifier.addListener(_startPolling);
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _refresh();
    final seconds = AppSettingsService.settings.refreshIntervalSeconds;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => _refresh());
  }

  Future<void> _refresh() async {
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
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final cardBg = isDark ? kCardDark : kCardLight;
    final accent = Theme.of(context).colorScheme.primary;
    final gasDetected = _status['gasDetected'] == true;
    final temperature = (_status['temperature'] as num?) ?? 0;
    final temperatureWarning =
        temperature >= AppSettingsService.settings.temperatureWarningThreshold;
    final motionDetected = _motionDetected(_status);

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
          'System Stats',
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
        child: SingleChildScrollView(
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
                      color: _isConnected ? accent : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? 'Live data' : 'No Connection',
                    style: TextStyle(
                      color: _isConnected ? accent : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'System Stats',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Column(
                  children: [
                    _row(
                      'System',
                      _status['system'] == true ? 'Active' : 'Inactive',
                      subColor,
                      _status['system'] == true ? accent : Colors.red,
                      isDark,
                      last: false,
                    ),
                    _row(
                      'Gas Status',
                      gasDetected ? 'Gas Detected' : 'Normal',
                      subColor,
                      gasDetected ? Colors.red : accent,
                      isDark,
                      last: false,
                    ),
                    _row(
                      'Gas Level',
                      '${_status['gasPercent']}%',
                      subColor,
                      textColor,
                      isDark,
                      last: false,
                    ),
                    _row(
                      'Temperature',
                      '$temperature C',
                      subColor,
                      temperatureWarning ? Colors.orange : textColor,
                      isDark,
                      last: false,
                    ),
                    _row(
                      'Humidity',
                      '${_status['humidity']}%',
                      subColor,
                      textColor,
                      isDark,
                      last: false,
                    ),
                    _row(
                      'Motion',
                      motionDetected ? 'Detected' : 'Clear',
                      subColor,
                      motionDetected ? Colors.orange : accent,
                      isDark,
                      last: false,
                    ),
                    _row(
                      'LEDs',
                      _status['led2'] == true ? 'ON' : 'OFF',
                      subColor,
                      _status['led2'] == true ? accent : textColor,
                      isDark,
                      last: false,
                    ),
                    _row(
                      'Door',
                      _status['door'] == true ? 'Open' : 'Locked',
                      subColor,
                      _status['door'] == true ? Colors.orange : accent,
                      isDark,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: GreenButton(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  width: 160,
                  onTap: _refresh,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _motionDetected(Map<String, dynamic> data) {
    return data['motionDetected'] == true ||
        data['pirDetected'] == true ||
        data['motion'] == true;
  }

  Widget _row(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
    bool isDark, {
    required bool last,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: labelColor, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      ],
    );
  }
}
