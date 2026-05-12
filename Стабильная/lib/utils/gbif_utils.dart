import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Модель для хранения данных о местонахождении (occurrence) из GBIF
class GbifOccurrence {
  final double latitude;
  final double longitude;
  final String country;
  final String? locality;
  final String? habitat;
  final String? coordinateUncertainty;
  final String? year;
  final String? month;
  final String? day;

  GbifOccurrence({
    required this.latitude,
    required this.longitude,
    required this.country,
    this.locality,
    this.habitat,
    this.coordinateUncertainty,
    this.year,
    this.month,
    this.day,
  });

  factory GbifOccurrence.fromJson(Map<String, dynamic> json) {
    return GbifOccurrence(
      latitude: (json['decimalLatitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['decimalLongitude'] as num?)?.toDouble() ?? 0.0,
      country: json['country'] as String? ?? '',
      locality: json['locality'] as String?,
      habitat: json['habitat'] as String?,
      coordinateUncertainty: json['coordinateUncertaintyInMeters'] as String?,
      year: json['year'] as String?,
      month: json['month'] as String?,
      day: json['day'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'decimalLatitude': latitude,
      'decimalLongitude': longitude,
      'country': country,
      'locality': locality,
      'habitat': habitat,
      'coordinateUncertaintyInMeters': coordinateUncertainty,
      'year': year,
      'month': month,
      'day': day,
    };
  }

  bool get hasValidCoordinates => 
      latitude != 0.0 && longitude != 0.0 &&
      latitude >= -90 && latitude <= 90 &&
      longitude >= -180 && longitude <= 180;
}

/// Основная функция для получения данных из GBIF
/// Возвращает Map с обогащающими данными или null в случае ошибки
Future<Map<String, dynamic>?> fetchGbifData(String latinName) async {
  try {
    print('🌍 Запрос данных GBIF для: $latinName');
    
    // Проверяем кэш
    final cachedData = await getCachedGbifData(latinName);
    if (cachedData != null) {
      print('✅ Найдены кэшированные данные GBIF для $latinName');
      return cachedData;
    }

    // Выполняем запрос к GBIF API
    final gbifData = await _fetchFromGbifApi(latinName);
    if (gbifData != null) {
      // Кэшируем результаты
      await cacheGbifData(latinName, gbifData);
      print('✅ Данные GBIF успешно получены и закэшированы для $latinName');
      return gbifData;
    }

    print('⚠️ Не удалось получить данные из GBIF для $latinName');
    return null;
  } catch (e) {
    print('❌ Ошибка при получении данных GBIF для $latinName: $e');
    return null;
  }
}

/// Внутренняя функция для запроса к GBIF API
Future<Map<String, dynamic>?> _fetchFromGbifApi(String latinName) async {
  const maxRetries = 3;
  const retryDelay = Duration(seconds: 2);
  
  // Формируем научное название для запроса
  final scientificName = _formatScientificName(latinName);
  
  // GBIF API endpoint для поиска occurrences
  final baseUrl = 'https://api.gbif.org/v1/occurrence/search';
  final url = Uri.parse('$baseUrl?scientificName=$scientificName&limit=50&hasCoordinate=true');
  
  final headers = {
    'User-Agent': 'MyCactus-App/1.0 (https://github.com/pavel/mycactus)',
    'Accept': 'application/json',
  };

  int retries = 0;
  
  while (retries < maxRetries) {
    try {
      print('🔍 Запрос к GBIF API: $url');
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseGbifResponse(data);
      } else {
        print('⚠️ GBIF API вернул статус ${response.statusCode}');
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      retries++;
      print('❌ Ошибка запроса к GBIF API (попытка $retries/$maxRetries): $e');
      
      if (retries >= maxRetries) {
        return null;
      }
      
      await Future.delayed(retryDelay);
    }
  }
  
  return null;
}

/// Парсинг ответа от GBIF API
Map<String, dynamic>? _parseGbifResponse(Map<String, dynamic> data) {
  try {
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      print('⚠️ GBIF: нет результатов в ответе');
      return null;
    }

    // Извлекаем occurrence данные
    final occurrences = <GbifOccurrence>[];
    final photoUrls = <String>[];
    final countries = <String>[];
    
    for (final result in results) {
      if (result is! Map<String, dynamic>) continue;
      
      // Создаем occurrence объект
      final occurrence = GbifOccurrence.fromJson(result);
      if (occurrence.hasValidCoordinates) {
        occurrences.add(occurrence);
        
        // Собираем уникальные страны
        if (occurrence.country.isNotEmpty) {
          countries.add(occurrence.country);
        }
      }
      
      // Извлекаем фото если есть
      final media = result['media'] as List<dynamic>?;
      if (media != null) {
        for (final mediaItem in media) {
          if (mediaItem is Map<String, dynamic> && 
              mediaItem['type'] == 'StillImage' &&
              mediaItem['identifier'] != null) {
            final photoUrl = mediaItem['identifier'] as String;
            if (photoUrl.startsWith('http')) {
              photoUrls.add(photoUrl);
            }
          }
        }
      }
    }

    if (occurrences.isEmpty) {
      print('⚠️ GBIF: нет валидных occurrence с координатами');
      return null;
    }

    // Определяем наиболее частую страну
    final mostFrequentCountry = getMostFrequentCountry(countries);
    
    // Собираем синонимы из GBIF (если есть)
    final synonyms = _extractSynonyms(data);
    
    // Создаем habitat описание из occurrence данных
    final habitatDescription = _createHabitatDescription(occurrences);
    
    print('✅ GBIF обработан: ${occurrences.length} occurrence, ${photoUrls.length} фото, страна: $mostFrequentCountry');
    
    return {
      'gbifOccurrences': occurrences.map((o) => o.toJson()).toList(),
      'gbifPhotoUrls': photoUrls,
      'gbifCountry': mostFrequentCountry,
      'gbifSynonyms': synonyms,
      'gbifHabitat': habitatDescription,
      'gbifOccurrenceCount': occurrences.length,
      'gbifPhotoCount': photoUrls.length,
      'lastGbifUpdate': DateTime.now().toIso8601String(),
    };
  } catch (e) {
    print('❌ Ошибка парсинга ответа GBIF: $e');
    return null;
  }
}

/// Определяет наиболее часто встречающуюся страну
String getMostFrequentCountry(List<String> countries) {
  if (countries.isEmpty) return '';
  
  final countryCounts = <String, int>{};
  for (final country in countries) {
    final normalizedCountry = country.trim();
    if (normalizedCountry.isNotEmpty) {
      countryCounts[normalizedCountry] = (countryCounts[normalizedCountry] ?? 0) + 1;
    }
  }
  
  if (countryCounts.isEmpty) return '';
  
  // Находим страну с максимальным количеством
  var mostFrequent = countries.first;
  var maxCount = 0;
  
  for (final entry in countryCounts.entries) {
    if (entry.value > maxCount) {
      maxCount = entry.value;
      mostFrequent = entry.key;
    }
  }
  
  return mostFrequent;
}

/// Извлекает синонимы из данных GBIF
String _extractSynonyms(Map<String, dynamic> data) {
  try {
    // GBIF может возвращать синонимы в разных полях
    final synonyms = <String>[];
    
    // Проверяем различные поля где могут быть синонимы
    if (data.containsKey('synonyms')) {
      final synList = data['synonyms'] as List<dynamic>?;
      if (synList != null) {
        for (final syn in synList) {
          if (syn is String && syn.isNotEmpty) {
            synonyms.add(syn.trim());
          }
        }
      }
    }
    
    return synonyms.join(', ');
  } catch (e) {
    print('⚠️ Ошибка извлечения синонимов GBIF: $e');
    return '';
  }
}

/// Создает описание ареала на основе occurrence данных
String _createHabitatDescription(List<GbifOccurrence> occurrences) {
  if (occurrences.isEmpty) return '';
  
  final countries = <String>{};
  final localities = <String>{};
  
  for (final occ in occurrences) {
    if (occ.country.isNotEmpty) countries.add(occ.country);
    if (occ.locality != null && occ.locality!.isNotEmpty) {
      localities.add(occ.locality!);
    }
  }
  
  final description = StringBuffer();
  
  if (countries.isNotEmpty) {
    final countryList = countries.take(5).join(', ');
    description.write('Распространение: $countryList');
    if (countries.length > 5) {
      description.write(' и др.');
    }
  }
  
  if (localities.isNotEmpty) {
    if (description.isNotEmpty) description.write('. ');
    final localityList = localities.take(3).join(', ');
    description.write('Местонахождения: $localityList');
    if (localities.length > 3) {
      description.write(' и др.');
    }
  }
  
  description.write('. Основано на ${occurrences.length} точках наблюдения.');
  
  return description.toString();
}

/// Форматирует научное название для запроса к GBIF
String _formatScientificName(String latinName) {
  // Удаляем лишние символы и форматируем для API
  return latinName
      .replaceAll(RegExp(r'[^\w\s\-]'), '')
      .replaceAll(' ', '+')
      .trim();
}

/// Кэширование данных GBIF
Future<void> cacheGbifData(String latinName, Map<String, dynamic> data) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'gbif_data_${latinName.toLowerCase().trim()}';
    await prefs.setString(key, jsonEncode(data));
    print('💾 Данные GBIF закэшированы: $key');
  } catch (e) {
    print('❌ Ошибка кэширования данных GBIF: $e');
  }
}

/// Получение кэшированных данных GBIF
Future<Map<String, dynamic>?> getCachedGbifData(String latinName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'gbif_data_${latinName.toLowerCase().trim()}';
    final cached = prefs.getString(key);
    
    if (cached != null) {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      
      // Проверяем "срок годности" кэша (7 дней)
      final lastUpdate = data['lastGbifUpdate'] as String?;
      if (lastUpdate != null) {
        final lastUpdateDate = DateTime.parse(lastUpdate);
        final now = DateTime.now();
        if (now.difference(lastUpdateDate).inDays > 7) {
          print('⏰ Кэш GBIF устарел для $latinName');
          await prefs.remove(key);
          return null;
        }
      }
      
      return data;
    }
    
    return null;
  } catch (e) {
    print('❌ Ошибка получения кэша GBIF: $e');
    return null;
  }
}

/// Очистка кэша GBIF для конкретного растения
Future<void> clearGbifCache(String latinName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'gbif_data_${latinName.toLowerCase().trim()}';
    await prefs.remove(key);
    print('🗑️ Кэш GBIF очищен для $latinName');
  } catch (e) {
    print('❌ Ошибка очистки кэша GBIF: $e');
  }
}

/// Полная очистка кэша GBIF
Future<void> clearAllGbifCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith('gbif_data_')) {
        await prefs.remove(key);
      }
    }
    
    print('🗑️ Весь кэш GBIF очищен');
  } catch (e) {
    print('❌ Ошибка полной очистки кэша GBIF: $e');
  }
}
