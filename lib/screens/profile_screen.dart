import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_constants.dart';
import '../services/user_storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameCtrl;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    final user = UserStorageService.currentUser;
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    _profileImagePath = user?.profileImagePath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (image == null || !mounted) return;
      setState(() => _profileImagePath = image.path);
      final user = UserStorageService.currentUser;
      if (user != null) {
        await UserStorageService.updateUser(
          username: user.username,
          profileImagePath: image.path,
        );
      }
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    final user = UserStorageService.currentUser;
    if (user == null) return;

    final newName = _nameCtrl.text.trim();
    final currentPass = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (newName.isEmpty) {
      _showSnack('Full name cannot be empty', isError: true);
      return;
    }

    String? newPasswordToSet;
    if (currentPass.isNotEmpty || newPass.isNotEmpty || confirmPass.isNotEmpty) {
      if (currentPass.isEmpty) {
        _showSnack('Enter your current password to change it', isError: true);
        return;
      }
      if (newPass.isEmpty) {
        _showSnack('Enter a new password', isError: true);
        return;
      }
      if (newPass != confirmPass) {
        _showSnack('New passwords do not match', isError: true);
        return;
      }
      if (newPass.length < 4) {
        _showSnack('New password must be at least 4 characters', isError: true);
        return;
      }
      final verified = await UserStorageService.login(user.username, currentPass);
      if (verified == null) {
        _showSnack('Current password is incorrect', isError: true);
        return;
      }
      newPasswordToSet = newPass;
    }

    setState(() => _loading = true);

    final error = await UserStorageService.updateUser(
      username: user.username,
      newFullName: newName,
      newPassword: newPasswordToSet,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _showSnack('Profile updated successfully');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final cardBg = isDark ? kCardDark : kCardLight;
    final inputBg = isDark ? kBgDarkSurface : Colors.white;
    final accent = Theme.of(context).colorScheme.primary;
    final user = UserStorageService.currentUser;

    return Scaffold(
      backgroundColor: isDark ? kBgDark : Colors.white,
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
          'My Profile',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          child: Column(
            children: [
              // ── Profile picture ──────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: accent.withValues(alpha: 0.15),
                        backgroundImage: _profileImagePath != null
                            ? FileImage(File(_profileImagePath!))
                            : null,
                        child: _profileImagePath == null
                            ? Text(
                                (user?.displayName.isNotEmpty ?? false)
                                    ? user!.displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? kBgDark : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (user != null) ...[
                Text(
                  user.displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: TextStyle(color: hintColor, fontSize: 14),
                ),
              ],
              const SizedBox(height: 28),

              // ── Personal info card ───────────────────────────────────────
              _card(
                isDark: isDark,
                cardBg: cardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Personal Info', textColor),
                    const SizedBox(height: 14),
                    _label('Full Name', hintColor),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _nameCtrl,
                      hint: 'Enter your full name',
                      icon: Icons.person_outline,
                      isDark: isDark,
                      inputBg: inputBg,
                      hintColor: hintColor,
                      textColor: textColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Change password card ─────────────────────────────────────
              _card(
                isDark: isDark,
                cardBg: cardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Change Password', textColor),
                    const SizedBox(height: 2),
                    Text(
                      'Leave empty to keep current password',
                      style: TextStyle(fontSize: 12, color: hintColor),
                    ),
                    const SizedBox(height: 14),
                    _label('Current Password', hintColor),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _currentPassCtrl,
                      hint: 'Enter current password',
                      icon: Icons.lock_outline,
                      isDark: isDark,
                      inputBg: inputBg,
                      hintColor: hintColor,
                      textColor: textColor,
                      obscure: _obscureCurrent,
                      suffix: _visibilityToggle(
                        _obscureCurrent,
                        () => setState(() => _obscureCurrent = !_obscureCurrent),
                        hintColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('New Password', hintColor),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _newPassCtrl,
                      hint: 'Enter new password',
                      icon: Icons.lock_outline,
                      isDark: isDark,
                      inputBg: inputBg,
                      hintColor: hintColor,
                      textColor: textColor,
                      obscure: _obscureNew,
                      suffix: _visibilityToggle(
                        _obscureNew,
                        () => setState(() => _obscureNew = !_obscureNew),
                        hintColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Confirm New Password', hintColor),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _confirmPassCtrl,
                      hint: 'Confirm new password',
                      icon: Icons.lock_outline,
                      isDark: isDark,
                      inputBg: inputBg,
                      hintColor: hintColor,
                      textColor: textColor,
                      obscure: _obscureConfirm,
                      suffix: _visibilityToggle(
                        _obscureConfirm,
                        () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Save button ──────────────────────────────────────────────
              _loading
                  ? CircularProgressIndicator(color: accent)
                  : SizedBox(
                      width: 220,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _saveProfile,
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({
    required bool isDark,
    required Color cardBg,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text, Color color) => Text(
    text,
    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
  );

  Widget _label(String text, Color color) => Text(
    text,
    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
  );

  Widget _visibilityToggle(bool obscure, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  Widget _inputField({
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
}
