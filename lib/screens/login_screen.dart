import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../services/connection_service.dart';
import '../widgets/green_button.dart';
import '../app_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ipCtrl = TextEditingController(text: '10.234.227.18');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String _error = '';

  final Map<String, String> _users = {
    'Admin': '1234',
    'User': '0000',
  };

  @override
  void dispose() {
    _ipCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final ip = _ipCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Username and Password are required');
      return;
    }
    if (!_users.containsKey(user) || _users[user] != pass) {
      setState(() => _error = 'Invalid username or password');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final connected = await ConnectionService.connectWifi(ip);
    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          username: user,
          isAdmin: user == 'Admin',
          connectedViaWifi: connected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final inputBg = isDark ? kCardDark : kCardLight;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Login to continue',
                style: TextStyle(fontSize: 14, color: hintColor),
              ),
              const SizedBox(height: 40),

              _label('ESP32 IP Address:', textColor),
              const SizedBox(height: 8),
              _field(
                controller: _ipCtrl,
                hint: 'e.g. 192.168.1.100',
                icon: Icons.wifi,
                isDark: isDark,
                inputBg: inputBg,
                hintColor: hintColor,
                textColor: textColor,
              ),
              const SizedBox(height: 20),

              _label('Username:', textColor),
              const SizedBox(height: 8),
              _field(
                controller: _userCtrl,
                hint: 'Enter your username',
                icon: Icons.person_outline,
                isDark: isDark,
                inputBg: inputBg,
                hintColor: hintColor,
                textColor: textColor,
              ),
              const SizedBox(height: 20),

              _label('Password:', textColor),
              const SizedBox(height: 8),
              _field(
                controller: _passCtrl,
                hint: 'Enter your password',
                icon: Icons.lock_outline,
                isDark: isDark,
                inputBg: inputBg,
                hintColor: hintColor,
                textColor: textColor,
                obscure: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: hintColor,
                      size: 20,
                    ),
                  ),
                ),
              ),

              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
              Center(
                child: _loading
                    ? const CircularProgressIndicator(color: kGreen)
                    : GreenButton(
                        label: 'Login',
                        width: 200,
                        onTap: _login,
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color color) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color inputBg,
    required Color hintColor,
    required Color textColor,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintColor, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: hintColor, size: 20),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
