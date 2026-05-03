import 'package:flutter/material.dart';
import '../app_constants.dart';
import '../theme_notifier.dart';

class DisplayScreen extends StatelessWidget {
  const DisplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;

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
          'Display 🌞🌙',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Theme',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    label: 'Light Mode',
                    icon: Icons.light_mode,
                    isSelected: !isDark,
                    isDarkCard: false,
                    isDark: isDark,
                    onTap: () => themeNotifier.value = ThemeMode.light,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ModeCard(
                    label: 'Dark Mode',
                    icon: Icons.dark_mode,
                    isSelected: isDark,
                    isDarkCard: true,
                    isDark: isDark,
                    onTap: () => themeNotifier.value = ThemeMode.dark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDarkCard;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDarkCard,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 140,
            decoration: BoxDecoration(
              color: isDarkCard
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? kGreen : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 48,
                color: isSelected ? kGreen : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : kTextPrimary,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
