import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _websiteUrl = 'https://smart-home-self-powered.vercel.app/';

  Future<void> _launchWebsite() async {
    try {
      final uri = Uri.parse(_websiteUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final cardBg = isDark ? kCardDark : kCardLight;
    final pageBg = isDark ? kBgDark : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: pageBg,
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
          'About Us',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(isDark: isDark),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProjectPanel(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    subColor: subColor,
                    accent: accent,
                  ),
                  const SizedBox(height: 22),
                  _SectionTitle('Team', color: textColor),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Peter Maged',
                    subtitle: 'Team Leader',
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    subColor: subColor,
                    accent: accent,
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.support_agent_outlined,
                    title: 'Recardo Raafat',
                    subtitle: 'Assistant Leader',
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    subColor: subColor,
                    accent: accent,
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.code_outlined,
                    title: 'Hassan Shehata',
                    subtitle: 'Application Development',
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    subColor: subColor,
                    accent: accent,
                  ),
                  const SizedBox(height: 22),
                  _SectionTitle('Links', color: textColor),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _launchWebsite,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('smart-home-self-powered.vercel.app'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
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

class _Header extends StatelessWidget {
  final bool isDark;

  const _Header({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
        child: Center(
          child: Image.asset(
            isDark ? 'Logo/dark_mode.png' : 'Logo/light_mode.png',
            width: 220,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _ProjectPanel extends StatelessWidget {
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color subColor;
  final Color accent;

  const _ProjectPanel({
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.subColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.home_work_outlined, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project',
                      style: TextStyle(
                        color: subColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Smart Home Self Powered',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailLine(
            icon: Icons.school_outlined,
            label: 'University',
            value: 'ElSewedy University of Technology',
            textColor: textColor,
            subColor: subColor,
            accent: accent,
          ),
          const SizedBox(height: 12),
          _DetailLine(
            icon: Icons.supervisor_account_outlined,
            label: 'Supervision',
            value: 'Dr. Dalia El Sheikh',
            textColor: textColor,
            subColor: subColor,
            accent: accent,
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color subColor;
  final Color accent;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.subColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: subColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle(this.title, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color subColor;
  final Color accent;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.subColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
