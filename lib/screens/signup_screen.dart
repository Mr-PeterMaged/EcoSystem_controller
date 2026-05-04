import 'package:flutter/material.dart';

import '../app_constants.dart';
import '../services/user_storage_service.dart';
import '../widgets/green_button.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _firstUser = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadAccountState();
  }

  Future<void> _loadAccountState() async {
    final hasUsers = await UserStorageService.hasRegisteredUsers();
    if (!mounted) return;
    setState(() => _firstUser = !hasUsers);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (username.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Username and password are required');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final error = await UserStorageService.createUser(
      username: username,
      fullName: _nameCtrl.text,
      password: password,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created. Please login.')),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(initialUsername: username)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final inputBg = isDark ? kCardDark : kCardLight;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                _firstUser ? 'Create Admin Account' : 'Create Account',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _firstUser
                    ? 'Set up the first user for this app'
                    : 'Add a new local user',
                style: TextStyle(fontSize: 14, color: hintColor),
              ),
              const SizedBox(height: 34),
              _label('Full Name:', textColor),
              const SizedBox(height: 8),
              _field(
                controller: _nameCtrl,
                hint: 'Enter your full name',
                icon: Icons.badge_outlined,
                isDark: isDark,
                inputBg: inputBg,
                hintColor: hintColor,
                textColor: textColor,
              ),
              const SizedBox(height: 18),
              _label('Username:', textColor),
              const SizedBox(height: 8),
              _field(
                controller: _userCtrl,
                hint: 'Choose a username',
                icon: Icons.person_outline,
                isDark: isDark,
                inputBg: inputBg,
                hintColor: hintColor,
                textColor: textColor,
              ),
              const SizedBox(height: 18),
              _label('Password:', textColor),
              const SizedBox(height: 8),
              _field(
                controller: _passCtrl,
                hint: 'Create a password',
                icon: Icons.lock_outline,
                isDark: isDark,
                inputBg: inputBg,
                hintColor: hintColor,
                textColor: textColor,
                obscure: _obscurePassword,
                suffix: _visibilityButton(
                  value: _obscurePassword,
                  color: hintColor,
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 18),
              _label('Confirm Password:', textColor),
              const SizedBox(height: 8),
              _field(
                controller: _confirmCtrl,
                hint: 'Repeat password',
                icon: Icons.verified_user_outlined,
                isDark: isDark,
                inputBg: inputBg,
                hintColor: hintColor,
                textColor: textColor,
                obscure: _obscureConfirm,
                suffix: _visibilityButton(
                  value: _obscureConfirm,
                  color: hintColor,
                  onTap: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                _errorBox(_error),
              ],
              const SizedBox(height: 34),
              Center(
                child: _loading
                    ? CircularProgressIndicator(color: accent)
                    : GreenButton(
                        label: 'Create Account',
                        width: 220,
                        onTap: _signup,
                      ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Already have an account? Login'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visibilityButton({
    required bool value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          value ? Icons.visibility_off : Icons.visibility,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  Widget _label(String text, Color color) => Text(
    text,
    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
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
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
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

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
