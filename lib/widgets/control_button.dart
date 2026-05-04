import 'package:flutter/material.dart';
import '../app_constants.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: !enabled
              ? (isDark ? Colors.grey[800] : Colors.grey[200])
              : isOn
              ? accent.withValues(alpha: 0.12)
              : (isDark ? kCardDark : kCardLight),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !enabled
                ? Colors.grey.withValues(alpha: 0.3)
                : isOn
                ? accent
                : (isDark ? Colors.white12 : Colors.black12),
            width: (isOn && enabled) ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: !enabled
                    ? Colors.grey
                    : (isDark ? Colors.white70 : kTextPrimary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isOn ? 'ON' : 'OFF',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: !enabled
                    ? Colors.grey[400]
                    : isOn
                    ? accent
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
