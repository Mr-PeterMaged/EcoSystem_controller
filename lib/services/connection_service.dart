import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ConnectionService {
  static String? espIp;
  static bool useWifi = true;
  static bool isConnected = false;

  // WiFi
  static Future<bool> connectWifi(String ip) async {
    try {
      espIp = ip;
      final res = await http
          .get(Uri.parse('http://$ip/status'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        isConnected = true;
        useWifi = true;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getStatus() async {
    if (!isConnected) return null;
    try {
      final res = await http
          .get(Uri.parse('http://$espIp:8080/status'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (_) {
      isConnected = false;
      return null;
    }
  }

  static Future<Map<String, dynamic>?> sendControl(
      Map<String, dynamic> data) async {
    if (!isConnected) return null;
    try {
      final res = await http
          .post(
        Uri.parse('http://$espIp:8080/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (_) {
      isConnected = false;
      return null;
    }
  }
}