import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ConnectionService {
  static String? espIp;
  static bool isConnected = false;
  static const int _port = 8080;

  static Future<bool> connectWifi(String ip) async {
    try {
      espIp = ip;
      final res = await http
          .get(Uri.parse('http://$ip:$_port/status'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        isConnected = true;
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
          .get(Uri.parse('http://$espIp:$_port/status'))
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
    Map<String, dynamic> data,
  ) async {
    if (!isConnected) return null;
    try {
      final res = await http
          .post(
            Uri.parse('http://$espIp:$_port/control'),
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
