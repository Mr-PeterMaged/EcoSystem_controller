import 'package:flutter_tts/flutter_tts.dart';

class WeatherVoiceService {
  static FlutterTts? _tts;

  static Future<void> _init() async {
    _tts ??= FlutterTts();
    await _tts!.setLanguage('en-US');
    await _tts!.setSpeechRate(0.45);
    await _tts!.setVolume(1.0);
    await _tts!.setPitch(1.0);
  }

  static Future<void> speak(String text) async {
    try {
      await _init();
      await _tts!.stop();
      await _tts!.speak(text);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }
}
