import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_constants.dart';

/// Talks to the ESP32 controller through Firebase Realtime Database instead
/// of a direct local-network HTTP call — this is what lets the phone stay in
/// sync with the website (and any other client) from anywhere, not just the
/// home Wi-Fi. Both sides read/write the same "shadow":
///   /devices/{id}/state/reported  (device -> clients)
///   /devices/{id}/state/desired   (clients -> device)
///
/// The public API here (isConnected / connectWifi / getStatus / sendControl)
/// is kept identical to the old local-HTTP version so no screen needs to
/// change.
class ConnectionService {
  static const _staleAfter = Duration(seconds: 8);

  static String? espIp;
  static bool isConnected = false;

  static Map<String, dynamic>? _reportedCache;
  static DateTime? _lastSeen;
  static bool _listening = false;
  static Timer? _staleTimer;

  static bool get _computedConnected =>
      _reportedCache != null &&
      _lastSeen != null &&
      DateTime.now().difference(_lastSeen!) < _staleAfter;

  static void _startListening() {
    if (_listening) return;
    _listening = true;

    final ref = FirebaseDatabase.instance.ref(
      'devices/$kFirebaseDeviceId/state/reported',
    );
    ref.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        _reportedCache = value.map((k, v) => MapEntry(k.toString(), v));
        _lastSeen = DateTime.now();
      }
      isConnected = _computedConnected;
    });

    _staleTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      isConnected = _computedConnected;
    });
  }

  // `ip` is unused now (kept for API compatibility with existing callers) —
  // the app reaches the device through Firebase, not a local address.
  static Future<bool> connectWifi(String ip) async {
    espIp = ip;
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      isConnected = false;
      return false;
    }
    _startListening();
    await Future.delayed(const Duration(milliseconds: 800));
    isConnected = _computedConnected;
    return isConnected;
  }

  static Future<Map<String, dynamic>?> getStatus() async {
    if (!_computedConnected) return null;
    return _reportedCache;
  }

  static Future<Map<String, dynamic>?> sendControl(
    Map<String, dynamic> data,
  ) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final ref = FirebaseDatabase.instance.ref(
        'devices/$kFirebaseDeviceId/state/desired',
      );
      await ref.update(data);
    } catch (_) {
      // Fall through — caller keeps its optimistic local update either way.
    }
    // Don't return the just-written "desired" value as confirmed truth —
    // the device applies it and reflects the real result back through
    // `reported` moments later, same as the website's ConnectionService.
    return null;
  }
}
