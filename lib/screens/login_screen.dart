import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../services/connection_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String _error = '';
  String _ipAddress = '10.234.227.18';

  // Credentials
  final Map<String, String> _users = {
    'Admin': '1234',
    'User': '0000',
  };

  void _login() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Username and Password are required');
      return;
    }

    if (!_users.containsKey(user) || _users[user] != pass) {
      setState(() => _error = 'Invalid username or password');
      return;
    }

    setState(() { _loading = true; _error = ''; });

    // Try WiFi
    bool connected = await ConnectionService.connectWifi(_ipAddress);

    setState(() => _loading = false);

    if (!mounted) return;

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text('Welcome',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Text('Login to continue',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // IP Address
              TextField(
                decoration: const InputDecoration(
                  labelText: 'ESP32 IP Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                onChanged: (v) => _ipAddress = v,
                controller: TextEditingController(text: _ipAddress),
              ),
              const SizedBox(height: 16),

              // Username
              TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 24),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


