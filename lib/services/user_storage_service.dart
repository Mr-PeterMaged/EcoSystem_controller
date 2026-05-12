import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class UserStorageService {
  static const _usersKey = 'registeredUsers';
  static const _projectUsersPath = 'data/users.json';
  static const _loggedInUserKey = 'loggedInUser';

  static SharedPreferences? _prefs;
  static List<AppUser> _users = [];
  static AppUser? _currentUser;

  static List<AppUser> get users => List.unmodifiable(_users);
  static AppUser? get currentUser => _currentUser;

  static Future<void> init() async {
    if (_prefs != null) return;

    _prefs = await SharedPreferences.getInstance();
    _users = _readStoredUsers();

    if (_users.isEmpty) {
      final projectUsers = await _readProjectUsers();
      if (projectUsers.isNotEmpty) {
        _users = projectUsers;
        await _saveUsers();
      }
    } else {
      await _writeProjectUsers();
    }
  }

  static Future<bool> hasRegisteredUsers() async {
    await init();
    return _users.isNotEmpty;
  }

  // ── Session management ──────────────────────────────────────────────────────

  static Future<void> saveSession(AppUser user) async {
    await init();
    _currentUser = user;
    await _prefs?.setString(_loggedInUserKey, user.username);
  }

  static Future<void> clearSession() async {
    await init();
    _currentUser = null;
    await _prefs?.remove(_loggedInUserKey);
  }

  /// Returns the previously logged-in user if the session is still valid.
  static Future<AppUser?> restoreSession() async {
    await init();
    final username = _prefs?.getString(_loggedInUserKey);
    if (username == null || username.isEmpty) return null;
    final matches = _users.where((u) => u.username == username);
    if (matches.isEmpty) return null;
    _currentUser = matches.first;
    return _currentUser;
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  static Future<AppUser?> login(String username, String password) async {
    await init();
    final normalized = _normalize(username);
    final passwordHash = _hashPassword(normalized, password);

    for (final user in _users) {
      if (_normalize(user.username) == normalized &&
          user.passwordHash == passwordHash) {
        return user;
      }
    }
    return null;
  }

  static Future<String?> createUser({
    required String username,
    required String fullName,
    required String password,
  }) async {
    await init();
    final cleanUsername = username.trim();
    final normalized = _normalize(cleanUsername);

    if (normalized.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (password.length < 4) {
      return 'Password must be at least 4 characters';
    }
    if (_users.any((user) => _normalize(user.username) == normalized)) {
      return 'Username already exists';
    }

    final user = AppUser(
      username: cleanUsername,
      fullName: fullName.trim(),
      passwordHash: _hashPassword(normalized, password),
      role: _users.isEmpty ? 'admin' : 'user',
      createdAt: DateTime.now(),
    );
    _users = [..._users, user];
    await _saveUsers();
    return null;
  }

  // ── Profile update ──────────────────────────────────────────────────────────

  static Future<String?> updateUser({
    required String username,
    String? newFullName,
    String? newPassword,
    String? profileImagePath,
  }) async {
    await init();
    final index = _users.indexWhere((u) => u.username == username);
    if (index < 0) return 'User not found';

    final existing = _users[index];

    String? newPasswordHash;
    if (newPassword != null && newPassword.isNotEmpty) {
      if (newPassword.length < 4) {
        return 'Password must be at least 4 characters';
      }
      newPasswordHash = _hashPassword(_normalize(username), newPassword);
    }

    final updated = existing.copyWith(
      fullName: newFullName,
      passwordHash: newPasswordHash,
      profileImagePath: profileImagePath,
    );

    final newList = List<AppUser>.from(_users);
    newList[index] = updated;
    _users = newList;

    if (_currentUser?.username == username) {
      _currentUser = updated;
    }

    await _saveUsers();
    return null;
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  static List<AppUser> _readStoredUsers() {
    final source = _prefs?.getString(_usersKey) ?? '';
    try {
      return AppUser.listFromJson(source);
    } catch (_) {
      return [];
    }
  }

  static Future<List<AppUser>> _readProjectUsers() async {
    try {
      final file = File(_projectUsersPath);
      if (!await file.exists()) return [];
      return AppUser.listFromJson(await file.readAsString());
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveUsers() async {
    final source = AppUser.listToJson(_users);
    await _prefs?.setString(_usersKey, source);
    await _writeProjectUsers();
  }

  static Future<void> _writeProjectUsers() async {
    try {
      final file = File(_projectUsersPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(AppUser.listToJson(_users));
    } catch (_) {
      // Mobile builds cannot write to the source project folder.
      // SharedPreferences remains the primary runtime storage.
    }
  }

  static String _normalize(String username) {
    return username.trim().toLowerCase();
  }

  static String _hashPassword(String normalizedUsername, String password) {
    final input = utf8.encode('$normalizedUsername::$password');
    var hash = 0x811c9dc5;
    for (final byte in input) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
