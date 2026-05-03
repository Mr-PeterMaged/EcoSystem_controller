import 'package:flutter/material.dart';

class ControlButton extends StatelessWidget {
  final String label;
  final bool isOn;
  final bool enabled;
  final VoidCallback onTap;

  const ControlButton({
    super.key,
    required this.label,
    required this.isOn,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: enabled
              ? (isOn ? Colors.green[50] : Colors.grey[100])
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? (isOn ? Colors.green : Colors.grey)
                : Colors.grey[300]!,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: enabled ? Colors.black : Colors.grey,
                )),
            Text(
              isOn ? 'ON' : 'OFF',
              style: TextStyle(
                color: enabled
                    ? (isOn ? Colors.green : Colors.grey)
                    : Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}