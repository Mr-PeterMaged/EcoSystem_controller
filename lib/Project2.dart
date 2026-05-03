


import 'package:flutter/material.dart';

void main() {
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatefulWidget {
  const SmartHomeApp({super.key});

  @override
  State<SmartHomeApp> createState() => _SmartHomeAppState();
}

class _SmartHomeAppState extends State<SmartHomeApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4CAF50),
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4CAF50),
          surface: Color(0xFF1E1E1E),
        ),
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const LoginScreen(),
        '/home': (ctx) => HomeScreen(isDark: _themeMode == ThemeMode.dark),
        '/full-control': (ctx) => FullControlScreen(isDark: _themeMode == ThemeMode.dark),
        '/stats': (ctx) => SystemStatsScreen(isDark: _themeMode == ThemeMode.dark),
        '/display': (ctx) => DisplayScreen(
          isDark: _themeMode == ThemeMode.dark,
          onThemeChanged: toggleTheme,
        ),
        '/notifications': (ctx) => NotificationsScreen(isDark: _themeMode == ThemeMode.dark),
      },
    );
  }
}

// ─── COLORS ───────────────────────────────────────────────────────────────────
const kGreen = Color(0xFF4CAF50);
const kCardLight = Color(0xFFF5F5F5);
const kCardDark = Color(0xFF2A2A2A);
const kTextDark = Color(0xFF212121);

// ─── REUSABLE WIDGETS (التصميم الأصلي بتاعك) ───────────────────────────────────

Widget _greenButton({
  required String label,
  required VoidCallback onTap,
  IconData? icon,
  double? width,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF56C85A), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: kGreen.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, color: Colors.white, size: 18),
          ],
        ],
      ),
    ),
  );
}

// كارت الحالة الأصلي بعد إضافة خاصية الضغط واللون التفاعلي
Widget _statusCard({
  required String label,
  required String value,
  required bool isDark,
  required bool isOn,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isOn ? kGreen.withOpacity(0.1) : (isDark ? kCardDark : kCardLight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOn ? kGreen : (isDark ? Colors.white12 : Colors.black12),
          width: isOn ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isOn ? kGreen : (isDark ? Colors.white : kTextDark),
              )),
        ],
      ),
    ),
  );
}

AppBar _appBar({
  required BuildContext context,
  required bool isDark,
  bool showBack = true,
  String? title,
}) {
  return AppBar(
    backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
    elevation: 0,
    leading: showBack
        ? GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
      ),
    )
        : null,
    title: title != null
        ? Text(title, style: TextStyle(color: isDark ? Colors.white : kTextDark, fontWeight: FontWeight.bold))
        : null,
    actions: [
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/notifications'),
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.notifications_none, color: isDark ? Colors.white70 : Colors.black54),
        ),
      ),
      Builder(
        builder: (ctx) => GestureDetector(
          onTap: () => Scaffold.of(ctx).openEndDrawer(),
          child: Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.menu, color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    ],
  );
}

Drawer _sideMenu(BuildContext context, bool isDark) {
  return Drawer(
    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Menu',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
            const SizedBox(height: 30),
            _menuItem(context, Icons.home, 'Home Page', () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
            }),
            const SizedBox(height: 16),
            _menuItem(context, Icons.display_settings, 'Display 🌞🌙', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/display');
            }),
            const SizedBox(height: 16),
            _menuItem(context, Icons.swap_horiz, 'Switch Acc.', () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            }),
            const SizedBox(height: 16),
            _menuItem(context, Icons.logout, 'Log out', () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            }),
          ],
        ),
      ),
    ),
  );
}

Widget _menuItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF56C85A), Color(0xFF388E3C)]),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    ),
  );
}

// ─── LOGIN SCREEN (التصميم بتاعك بالكامل) ───────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextDark;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final inputBg = isDark ? kCardDark : const Color(0xFFF0F0F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Text('Welcome', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 6),
              Text('Login to continue', style: TextStyle(fontSize: 14, color: hintColor)),
              const SizedBox(height: 50),
              _label('Username:', textColor),
              const SizedBox(height: 8),
              _inputField(controller: _userCtrl, hint: 'Enter username', isDark: isDark, inputBg: inputBg, hintColor: hintColor, textColor: textColor),
              const SizedBox(height: 20),
              _label('Password:', textColor),
              const SizedBox(height: 8),
              _inputField(
                controller: _passCtrl,
                hint: 'Enter password',
                isDark: isDark,
                inputBg: inputBg,
                hintColor: hintColor,
                textColor: textColor,
                obscure: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: hintColor, size: 20),
                ),
              ),
              const SizedBox(height: 40),
              Center(child: _greenButton(label: 'Login', width: 180, onTap: () => Navigator.pushReplacementNamed(context, '/home'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color color) => Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color));

  Widget _inputField({required TextEditingController controller, required String hint, required bool isDark, required Color inputBg, required Color hintColor, required Color textColor, bool obscure = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white12 : Colors.black12)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: hintColor, fontSize: 14), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: InputBorder.none, suffixIcon: suffix),
      ),
    );
  }
}

// ─── HOME SCREEN ──────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final bool isDark;
  const HomeScreen({super.key, required this.isDark});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // حالات الأزرار في الشاشة الرئيسية
  bool systemOn = true;
  bool gasOn = true;
  bool tempOn = true;
  bool ledsOn = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : kTextDark;
    final subColor = widget.isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF121212) : Colors.white,
      endDrawer: _sideMenu(context, widget.isDark),
      appBar: _appBar(context: context, isDark: widget.isDark, showBack: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome Admin', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 6),
              Row(children: [
                Text('System : ', style: TextStyle(fontSize: 14, color: subColor)),
                Text(systemOn ? 'ON' : 'OFF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: systemOn ? kGreen : Colors.red)),
              ]),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: _statusCard(label: 'System', value: systemOn ? 'ON' : 'OFF', isDark: widget.isDark, isOn: systemOn, onTap: () => setState(() => systemOn = !systemOn))),
                const SizedBox(width: 12),
                Expanded(child: _statusCard(label: 'Gas Sensor', value: gasOn ? 'ON' : 'OFF', isDark: widget.isDark, isOn: gasOn, onTap: () => setState(() => gasOn = !gasOn))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _statusCard(label: 'Temperature', value: tempOn ? 'ON' : 'OFF', isDark: widget.isDark, isOn: tempOn, onTap: () => setState(() => tempOn = !tempOn))),
                const SizedBox(width: 12),
                Expanded(child: _statusCard(label: 'LED s', value: ledsOn ? 'ON' : 'OFF', isDark: widget.isDark, isOn: ledsOn, onTap: () => setState(() => ledsOn = !ledsOn))),
              ]),
              const SizedBox(height: 32),
              Center(child: _greenButton(label: 'Show full control', width: 220, onTap: () => Navigator.pushNamed(context, '/full-control'))),
              const SizedBox(height: 16),
              Center(child: _greenButton(label: 'Show Stats', width: 220, onTap: () => Navigator.pushNamed(context, '/stats'))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── FULL CONTROL SCREEN (التفاعلي بلمستك الأصلية) ──────────────────────────────
class FullControlScreen extends StatefulWidget {
  final bool isDark;
  const FullControlScreen({super.key, required this.isDark});

  @override
  State<FullControlScreen> createState() => _FullControlScreenState();
}

class _FullControlScreenState extends State<FullControlScreen> {
  final Map<String, bool> _deviceStates = {
    'System': true, 'Gas Sensor': true, 'Temperature': true, 'LED s': false,
    'PIR': true, 'LDR': true, 'BUZZER': true, 'Auto Light': false,
  };

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : kTextDark;

    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF121212) : Colors.white,
      endDrawer: _sideMenu(context, widget.isDark),
      appBar: _appBar(context: context, isDark: widget.isDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Full Control', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2),
                  itemCount: _deviceStates.length,
                  itemBuilder: (context, index) {
                    String key = _deviceStates.keys.elementAt(index);
                    bool isOn = _deviceStates[key]!;
                    return _statusCard(
                      label: key,
                      value: isOn ? 'ON' : 'OFF',
                      isDark: widget.isDark,
                      isOn: isOn,
                      onTap: () => setState(() => _deviceStates[key] = !isOn),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SYSTEM STATS SCREEN ──────────────────────────────────────────────────────
class SystemStatsScreen extends StatelessWidget {
  final bool isDark;
  const SystemStatsScreen({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : kTextDark;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final stats = [
      ('System :', 'Active'), ('Gas Status :', 'Gas detected'), ('Temperature :', '25 C'),
      ('Motion :', 'Motion Detected'), ('LED s :', 'OFF'), ('Humidity :', '50%'),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      endDrawer: _sideMenu(context, isDark),
      appBar: _appBar(context: context, isDark: isDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Stats', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(color: isDark ? kCardDark : kCardLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white12 : Colors.black12)),
                child: Column(
                  children: stats.map((s) {
                    return Column(children: [
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(s.$1, style: TextStyle(color: subColor, fontSize: 14)),
                        Text(s.$2, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                      ])),
                      if (s != stats.last) Divider(height: 1, color: isDark ? Colors.white10 : Colors.black),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 30),
              Center(child: _greenButton(label: 'Refresh', icon: Icons.refresh, width: 160, onTap: () {})),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DISPLAY SCREEN ───────────────────────────────────────────────────────────
class DisplayScreen extends StatefulWidget {
  final bool isDark;
  final void Function(bool) onThemeChanged;
  const DisplayScreen({super.key, required this.isDark, required this.onThemeChanged});
  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  late bool _selectedDark;
  @override
  void initState() { super.initState(); _selectedDark = widget.isDark; }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF121212) : Colors.white,
      endDrawer: _sideMenu(context, widget.isDark),
      appBar: _appBar(context: context, isDark: widget.isDark, title: 'Display 🌞🌙'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(children: [
          Expanded(child: _modeCard(label: 'Light Mode', isSelected: !_selectedDark, isDarkCard: false, isDark: widget.isDark, onTap: () { setState(() => _selectedDark = false); widget.onThemeChanged(false); })),
          const SizedBox(width: 16),
          Expanded(child: _modeCard(label: 'Dark Mode', isSelected: _selectedDark, isDarkCard: true, isDark: widget.isDark, onTap: () { setState(() => _selectedDark = true); widget.onThemeChanged(true); })),
        ]),
      ),
    );
  }

  Widget _modeCard({required String label, required bool isSelected, required bool isDarkCard, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(height: 140, decoration: BoxDecoration(color: isDarkCard ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(14), border: Border.all(color: isSelected ? kGreen : Colors.transparent, width: 2)), child: Center(child: Icon(isDarkCard ? Icons.dark_mode : Icons.light_mode, color: isSelected ? kGreen : Colors.grey))),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: isDark ? Colors.white : kTextDark, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─── NOTIFICATIONS SCREEN (المطلوب: بدون أزرار قائمة مكررة) ────────────────────
class NotificationsScreen extends StatelessWidget {
  final bool isDark;
  const NotificationsScreen({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : kTextDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      // الـ AppBar هنا فيه الرجوع بس، مفيش Menu عشان نمنع التكرار
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
        ),
        title: Text('Notifications', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 80, color: isDark ? Colors.white10 : Colors.black),
            const SizedBox(height: 16),
            Text('No notifications yet', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}