import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../services/connection_service.dart';
import '../services/notification_service.dart';
import '../widgets/control_button.dart';
import '../widgets/green_button.dart';
import '../app_constants.dart';
import 'about_screen.dart';
import 'automation_screen.dart';
import 'control_screen.dart';
import 'stats_screen.dart';
import 'login_screen.dart';
import 'display_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final bool isAdmin;
  final bool connectedViaWifi;

  const HomeScreen({
    super.key,
    required this.username,
    required this.isAdmin,
    required this.connectedViaWifi,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
  bool _prevGasDetected = false;
  bool _prevTemperatureWarning = false;
  bool _prevMotionDetected = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.connectedViaWifi;
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
      await _handleAlerts(data);
      setState(() {
        _status = data;
        _isConnected = true;
      });
    } else if (mounted) {
      setState(() => _isConnected = false);
    }
  }

  Future<void> _handleAlerts(Map<String, dynamic> data) async {
    final gasDetected = data['gasDetected'] == true;
    if (gasDetected && !_prevGasDetected) {
      await NotificationService.gasAlert();
    }
    _prevGasDetected = gasDetected;

    final temperature = (data['temperature'] as num?) ?? 0;
    final threshold = AppSettingsService.settings.temperatureWarningThreshold;
    final temperatureWarning = temperature >= threshold;
    if (temperatureWarning && !_prevTemperatureWarning) {
      await NotificationService.temperatureAlert(temperature);
    }
    _prevTemperatureWarning = temperatureWarning;

    final motionDetected = isMotionDetected(data);
    if (motionDetected && !_prevMotionDetected) {
      await NotificationService.motionAlert();
    }
    _prevMotionDetected = motionDetected;
  }

  Future<void> _toggle(String key) async {
    if (!_hasDeviceConnection) {
      _showNoConnectionMessage();
      return;
    }

    if (!(_status['system'] as bool) && key != 'system') return;
    final newVal = !(_status[key] as bool);

    final Map<String, dynamic> command;
    if (key == 'system' && !newVal) {
      command = {for (final k in kAllDeviceKeys) k: false};
    } else {
      command = {key: newVal};
    }

    final result = await ConnectionService.sendControl(command);
    if (result != null && mounted) {
      setState(() => _status = result);
    } else if (mounted) {
      setState(() => _isConnected = false);
      _showNoConnectionMessage();
    }
  }

  Future<void> _applyPowerSave(Map<String, bool> preset) async {
    if (!_hasDeviceConnection) {
      _showNoConnectionMessage();
      return;
    }

    final result = await ConnectionService.sendControl(
      Map<String, dynamic>.from(preset),
    );
    if (result != null && mounted) {
      setState(() => _status = result);
    } else if (mounted) {
      setState(() => _isConnected = false);
      _showNoConnectionMessage();
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
    final accent = Theme.of(context).colorScheme.primary;
    final systemOn = _status['system'] as bool;
    final gasDetected = _status['gasDetected'] as bool;

    return Scaffold(
      backgroundColor: isDark ? kBgDark : Colors.white,
      endDrawer: _buildDrawer(context, isDark, accent),
      appBar: _buildAppBar(isDark, gasDetected, accent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
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
                      _isConnected ? 'Connected to ESP32' : 'No Connection',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  'Welcome ${widget.username}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'System : ',
                      style: TextStyle(fontSize: 14, color: subColor),
                    ),
                    Text(
                      systemOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: systemOn ? accent : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _quickStats(isDark, textColor, subColor, accent),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: ControlButton(
                        label: 'System',
                        isOn: _status['system'] as bool,
                        onTap: () => _toggle('system'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ControlButton(
                        label: 'Gas Sensor',
                        isOn: _status['gasSensor'] as bool,
                        enabled: systemOn || !_isConnected,
                        onTap: () => _toggle('gasSensor'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ControlButton(
                        label: 'Temperature',
                        isOn: _status['tempSensor'] as bool,
                        enabled: systemOn || !_isConnected,
                        onTap: () => _toggle('tempSensor'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ControlButton(
                        label: 'LEDs',
                        isOn: _status['ledSensor'] as bool,
                        enabled: systemOn || !_isConnected,
                        onTap: () => _toggle('ledSensor'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _powerSaveButton(
                        'Eco Mode',
                        Icons.eco,
                        kPowerSaveEco,
                        Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _powerSaveButton(
                        'Deep Save',
                        Icons.power_settings_new,
                        kPowerSaveDeep,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                Center(
                  child: GreenButton(
                    label: 'Show full control',
                    width: 220,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ControlScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GreenButton(
                    label: 'Show Stats',
                    width: 220,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatsScreen(status: _status),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasDeviceConnection => ConnectionService.isConnected;

  void _showNoConnectionMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'No action was taken because the system is not connected to the devices.',
          ),
        ),
      );
  }

  Widget _powerSaveButton(
    String label,
    IconData icon,
    Map<String, bool> preset,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => _applyPowerSave(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickStats(
    bool isDark,
    Color textColor,
    Color subColor,
    Color accent,
  ) {
    final temperature = _status['temperature'] ?? 0;
    final humidity = _status['humidity'] ?? 0;
    final gasDetected = _status['gasDetected'] == true;
    final motionDetected = isMotionDetected(_status);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Temp',
                '$temperature C',
                Icons.thermostat,
                Colors.orange,
                isDark,
                textColor,
                subColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Humidity',
                '$humidity%',
                Icons.water_drop_outlined,
                Colors.blue,
                isDark,
                textColor,
                subColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Gas',
                gasDetected ? 'Alert' : 'Normal',
                Icons.local_fire_department_outlined,
                gasDetected ? Colors.red : accent,
                isDark,
                textColor,
                subColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Motion',
                motionDetected ? 'Detected' : 'Clear',
                Icons.directions_run,
                motionDetected ? Colors.orange : accent,
                isDark,
                textColor,
                subColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    return Container(
      height: 78,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? kCardDark : kCardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subColor, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, bool gasDetected, Color accent) {
    return AppBar(
      backgroundColor: isDark ? kAppBarDark : Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
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
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openEndDrawer(),
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.menu,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Drawer _buildDrawer(BuildContext context, bool isDark, Color accent) {
    final textColor = isDark ? Colors.white : kTextPrimary;
    return Drawer(
      backgroundColor: isDark ? kBgDarkSurface : Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 30),
              _drawerItem(Icons.home, 'Home Page', accent, () {
                Navigator.pop(context);
              }),
              const SizedBox(height: 16),
              _drawerItem(Icons.settings_outlined, 'Settings', accent, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DisplayScreen()),
                );
              }),
              const SizedBox(height: 16),
              _drawerItem(Icons.schedule, 'Automation', accent, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AutomationScreen()),
                );
              }),
              const SizedBox(height: 16),
              _drawerItem(Icons.swap_horiz, 'Switch Acc.', accent, () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }),
              const SizedBox(height: 16),
              _drawerItem(Icons.logout, 'Log out', accent, () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label,
    Color accent,
    VoidCallback onTap,
  ) {
    final hsl = HSLColor.fromColor(accent);
    final light = hsl
        .withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0))
        .toColor();
    final dark = hsl
        .withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0))
        .toColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [light, dark]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
