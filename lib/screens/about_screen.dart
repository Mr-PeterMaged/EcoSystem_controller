import 'package:flutter/material.dart';

import '../app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final cardBg = isDark ? kCardDark : kCardLight;

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
          'About Us',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Center(
              child: Image.asset(
                'Logo/dark_mode.png',
                width: 180,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eco Smart System',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We are Team Eco Smart System.',
                    style: TextStyle(color: subColor, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    icon: Icons.home_work_outlined,
                    title: 'Project',
                    value: 'Smart Home Self Powered',
                    isDark: isDark,
                  ),
                  _InfoRow(
                    icon: Icons.school_outlined,
                    title: 'University',
                    value: 'ElSewedy University of Technology',
                    isDark: isDark,
                  ),
                  _InfoRow(
                    icon: Icons.supervisor_account_outlined,
                    title: 'Supervision',
                    value: 'Dr. Dalia El Sheikh',
                    isDark: isDark,
                  ),
                  _InfoRow(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Team Leader',
                    value: 'Peter Maged',
                    isDark: isDark,
                  ),
                  _InfoRow(
                    icon: Icons.code_outlined,
                    title: 'Application Development',
                    value: 'Hassan Shehata',
                    isDark: isDark,
                    last: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isDark;
  final bool last;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.isDark,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : kTextPrimary;
    final subColor = isDark ? Colors.white60 : Colors.black54;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kGreen, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!last)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
      ],
    );
  }
}
