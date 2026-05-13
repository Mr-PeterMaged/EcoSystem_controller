import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_models.dart';

class WeatherApiService {
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const _apiKey = 'b02af426a3fad0d92d3e0b32f9324cf0';

  static Future<WCurrentWeatherData?> getCurrentWeather(String city) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/weather?q=${Uri.encodeComponent(city)}&lang=en&appid=$_apiKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return WCurrentWeatherData.fromJson(jsonDecode(response.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<List<WFiveDayData>> getForecast(String city) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/forecast?q=${Uri.encodeComponent(city)}&lang=en&appid=$_apiKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['list'] as List)
            .map((t) => WFiveDayData.fromJson(t))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
