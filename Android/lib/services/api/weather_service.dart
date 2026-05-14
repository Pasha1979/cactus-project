import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger/app_logger.dart';
import '../../models/plant.dart';

/// Сервис для получения погодных данных через OpenWeatherMap API.
///
/// Отвечает за:
/// - Определение геолокации
/// - Запрос текущей погоды по координатам или городу
/// - Кэширование на 1 час
/// - Формирование рекомендаций по поливу
import '../../../core/config/api_config.dart';

class WeatherService {
  static const String _tag = 'WEATHER';
  static const String _apiKey = ApiConstants.openWeatherApiKey;
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';
  static const String _cacheKey = 'weather_cache';
  static const Duration _cacheDuration = Duration(hours: 1);

  final Dio _dio = Dio();

  // ==================== ГЕОЛОКАЦИЯ ====================

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,);
  }

  // ==================== ПОГОДА ====================

  Future<Map<String, dynamic>?> getCurrentWeather(
      double? lat, double? lon,) async {
    if (lat == null || lon == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final cacheTime = prefs.getInt('${_cacheKey}_time') ?? 0;

    if (cached != null &&
        DateTime.now().millisecondsSinceEpoch - cacheTime <
            _cacheDuration.inMilliseconds) {
      return jsonDecode(cached);
    }

    try {
      final response = await _dio.get(
        '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        await prefs.setString(_cacheKey, jsonEncode(data));
        await prefs.setInt(
            '${_cacheKey}_time', DateTime.now().millisecondsSinceEpoch,);
        return data;
      }
    } catch (e, stack) {
      AppLogger.error('Ошибка погоды', error: e, stackTrace: stack, tag: _tag);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getWeatherByCity(String city) async {
    if (city.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('${_cacheKey}_city_$city');
    final cacheTime = prefs.getInt('${_cacheKey}_time_city_$city') ?? 0;

    if (cached != null &&
        DateTime.now().millisecondsSinceEpoch - cacheTime <
            _cacheDuration.inMilliseconds) {
      return jsonDecode(cached);
    }

    try {
      final response = await _dio.get(
        '$_baseUrl?q=$city&appid=$_apiKey&units=metric',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        await prefs.setString('${_cacheKey}_city_$city', jsonEncode(data));
        await prefs.setInt('${_cacheKey}_time_city_$city',
            DateTime.now().millisecondsSinceEpoch,);
        return data;
      }
    } catch (e, stack) {
      AppLogger.error('Ошибка погоды по городу "$city"',
          error: e, stackTrace: stack, tag: _tag,);
    }
    return null;
  }

  // ==================== РЕКОМЕНДАЦИИ ====================

  String getWateringAdvice(Map<String, dynamic>? weather, Plant plant) {
    if (weather == null) return 'Проверьте погоду вручную.';

    final temp = (weather['main']['temp'] as num?)?.toDouble() ?? 20.0;
    final humidity = (weather['main']['humidity'] as num?)?.toDouble() ?? 50.0;
    final rain = weather['weather'][0]['main'] == 'Rain';
    final isSensitive = plant.category == 'purchased';

    if (rain || humidity > (isSensitive ? 70 : 60)) {
      return 'Влажная погода — отложите полив на 1–2 дня, чтобы избежать гнили.';
    } else if (temp > 25 && humidity < 40) {
      return 'Жарко и сухо — проверьте почву и полейте сегодня.';
    } else if (temp < 10) {
      return 'Холодно — сократите поливы, кактусы в спячке.';
    }
    return 'Погода нормальная — следуйте графику.';
  }

  String formatWeather(Map<String, dynamic>? weather) {
    if (weather == null) return 'Нет данных о погоде.';
    final temp = weather['main']['temp'].toStringAsFixed(0);
    final humidity = weather['main']['humidity'].toStringAsFixed(0);
    final condition = weather['weather'][0]['main'];
    return '+$temp°C, влажность $humidity%, $condition';
  }
}
