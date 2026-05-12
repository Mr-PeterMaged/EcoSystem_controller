import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../services/connection_service.dart';
import '../services/user_storage_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), _openNextScreen);
  }

  Future<void> _openNextScreen() async {
    // Try to restore a saved login session first
    final savedUser = await UserStorageService.restoreSession();
    if (savedUser != null && mounted) {
      final ip = AppSettingsService.settings.controllerIp;
      final connected = await ConnectionService.connectWifi(ip);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            username: savedUser.displayName,
            isAdmin: savedUser.isAdmin,
            connectedViaWifi: connected,
          ),
        ),
      );
      return;
    }

    final hasUsers = await UserStorageService.hasRegisteredUsers();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => hasUsers ? const LoginScreen() : const SignupScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Image(
                  image: AssetImage('Logo/dark_mode.png'),
                  width: 280,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    color: accent,
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
