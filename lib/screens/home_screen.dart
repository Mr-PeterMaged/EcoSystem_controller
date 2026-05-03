import 'package:flutter/material.dart';
import 'dart:async';
import '../services/connection_service.dart';
import '../services/notification_service.dart';
import '../widgets/control_button.dart';
import 'control_screen.dart';
import 'stats_screen.dart';
import 'login_screen.dart';

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
        // Gas notification
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
    if (!_status['system'] && key != 'system') return;
    final newVal = !(_status[key] as bool);
    final result = await ConnectionService.sendControl({key: newVal});
    if (result != null && mounted) {
      setState(() => _status = result);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF4CAF50)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.home, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Menu',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Color(0xFF4CAF50)),
            title: const Text('Home Page'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(
              Icons.display_settings,
              color: Color(0xFF4CAF50),
            ),
            title: const Text('Display 🌞🌙'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.switch_account, color: Color(0xFF4CAF50)),
            title: const Text('Switch Acc.'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF4CAF50)),
            title: const Text('Log out'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemOn = _status['system'] as bool;

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                if (_status['gasDetected'] == true)
                  Positioned(
                    right: 0,
                    top: 0,
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
            onPressed: () {},
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? 'Connected' : 'No Connection',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              'Welcome ${widget.username}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('System : ', style: TextStyle(fontSize: 16)),
                Text(
                  systemOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: systemOn ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Control Grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2,
              children: [
                ControlButton(
                  label: 'System',
                  isOn: _status['system'],
                  onTap: () => _toggle('system'),
                ),
                ControlButton(
                  label: 'Gas Sensor',
                  isOn: _status['gasSensor'],
                  enabled: systemOn,
                  onTap: () => _toggle('gasSensor'),
                ),
                ControlButton(
                  label: 'Temperature',
                  isOn: _status['tempSensor'],
                  enabled: systemOn,
                  onTap: () => _toggle('tempSensor'),
                ),
                ControlButton(
                  label: 'LED s',
                  isOn: _status['ledSensor'],
                  enabled: systemOn,
                  onTap: () => _toggle('ledSensor'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Buttons
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ControlScreen(status: _status, onToggle: _toggle),
                  ),
                ),
                child: const Text('Show full control'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatsScreen(status: _status),
                  ),
                ),
                child: const Text('Show Stats'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
