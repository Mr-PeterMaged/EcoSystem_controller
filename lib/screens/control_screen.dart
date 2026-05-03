import 'package:flutter/material.dart';
import '../widgets/control_button.dart';

class ControlScreen extends StatelessWidget {
  final Map<String, dynamic> status;
  final Function(String) onToggle;

  const ControlScreen({
    super.key,
    required this.status,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final systemOn = status['system'] as bool;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Full Control',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            ControlButton(
              label: 'System',
              isOn: status['system'],
              onTap: () => onToggle('system'),
            ),
            ControlButton(
              label: 'Gas Sensor',
              isOn: status['gasSensor'],
              enabled: systemOn,
              onTap: () => onToggle('gasSensor'),
            ),
            ControlButton(
              label: 'Temperature',
              isOn: status['tempSensor'],
              enabled: systemOn,
              onTap: () => onToggle('tempSensor'),
            ),
            ControlButton(
              label: 'LED s',
              isOn: status['ledSensor'],
              enabled: systemOn,
              onTap: () => onToggle('ledSensor'),
            ),
            ControlButton(
              label: 'PIR',
              isOn: status['pirSensor'],
              enabled: systemOn,
              onTap: () => onToggle('pirSensor'),
            ),
            ControlButton(
              label: 'LDR',
              isOn: status['ldrSensor'],
              enabled: systemOn,
              onTap: () => onToggle('ldrSensor'),
            ),
            ControlButton(
              label: 'BUZZER',
              isOn: status['buzzer'],
              enabled: systemOn,
              onTap: () => onToggle('buzzer'),
            ),
            ControlButton(
              label: 'Auto Light',
              isOn: status['autoLight'],
              enabled: systemOn,
              onTap: () => onToggle('autoLight'),
            ),
          ],
          ),
      ),
    );
  }
}
