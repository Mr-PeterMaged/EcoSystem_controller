import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connection_service.dart';
import '../services/notification_service.dart';
import '../widgets/control_button.dart';
import '../widgets/green_button.dart';
import '../app_constants.dart';
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
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.connectedViaWifi;
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final data = await ConnectionService.getStatus();
      if (data != null && mounted) {
        if (data['gasDetected'] == true && _prevGasDetected == false) {
          await NotificationService.gasAlert();
        }
        _prevGasDetected = data['gasDetected'] ?? false;
        setState(() {
          _status = data;
          _isConnected = true;
        });
      } else if (mounted) {
        setState(() => _isConnected = false);
      }
    });
  }

  Future<void> _toggle(String key) async {
    if (!(_status['system'] as bool) && key != 'system') return;
    final newVal = !(_status[key] as bool);
    final result = await ConnectionService.sendControl({key: newVal});
    if (result != null && mounted) setState(() => _status = result);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final systemOn = _status['system'] as bool;
    final gasDetected = _status['gasDetected'] as bool;

    return Scaffold(
      backgroundColor: isDark ? kBgDark : Colors.white,
      endDrawer: _buildDrawer(isDark),
      appBar: _buildAppBar(isDark, gasDetected),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection indicator
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
                      color: systemOn ? kGreen : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2×2 control grid
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
                      enabled: systemOn,
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
                      enabled: systemOn,
                      onTap: () => _toggle('tempSensor'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ControlButton(
                      label: 'LED s',
                      isOn: _status['ledSensor'] as bool,
                      enabled: systemOn,
                      onTap: () => _toggle('ledSensor'),
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
    );
  }

  AppBar _buildAppBar(bool isDark, bool gasDetected) {
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

  Drawer _buildDrawer(bool isDark) {
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
              _drawerItem(Icons.home, 'Home Page', () {
                Navigator.pop(context);
              }),
              const SizedBox(height: 16),
              _drawerItem(Icons.display_settings, 'Display 🌞🌙', () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DisplayScreen()),
                );
              }),
              const SizedBox(height: 16),
              _drawerItem(Icons.swap_horiz, 'Switch Acc.', () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }),
              const SizedBox(height: 16),
              _drawerItem(Icons.logout, 'Log out', () {
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

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kGreenLight, kGreenDark],
          ),
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
