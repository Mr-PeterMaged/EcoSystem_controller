import 'package:flutter/material.dart';
import '../app_constants.dart';

class GreenButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double? width;
  final IconData? icon;

  const GreenButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kGreenLight, kGreenDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: kGreen.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 6),
              Icon(icon!, color: Colors.white, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
