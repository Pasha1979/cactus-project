import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/plant.dart';
import '../../utils/weather_service.dart';

/// Провайдер для погодных данных и рекомендаций
///
/// Отвечает за:
/// - Получение локации
/// - Загрузку погоды
/// - Советы по поливу на основе погоды
class WeatherProvider with ChangeNotifier {
  String? _city;
  bool _isLoading = false;

  String? get city => _city;
  bool get isLoading => _isLoading;

  // ==================== ЛОКАЦИЯ ====================
  Future<void> initLocation() async {
    final service = WeatherService();
    final position = await service.getCurrentLocation();
    if (position != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('lat', position.latitude);
      await prefs.setDouble('lon', position.longitude);
      notifyListeners();
    }
  }

  // ==================== ГОРОД ====================
  Future<String?> getCity() async {
    final prefs = await SharedPreferences.getInstance();
    _city = prefs.getString('city');
    return _city;
  }

  Future<void> setCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', city);
    _city = city;
    notifyListeners();
  }

  // ==================== ПОГОДА ====================
  Future<String> getWeatherAdvice(Plant plant) async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('lat');
    final lon = prefs.getDouble('lon');
    final service = WeatherService();

    Map<String, dynamic>? weather;
    if (lat != null && lon != null) {
      weather = await service.getCurrentWeather(lat, lon);
    } else {
      final cityName = _city ?? await getCity();
      if (cityName != null && cityName.isNotEmpty) {
        weather = await service.getWeatherByCity(cityName);
      }
    }
    return service.getWateringAdvice(weather, plant);
  }
}
