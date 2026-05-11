import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger/app_logger.dart';
import '../../models/gbif_occurrence.dart';

/// Сервис для работы с GBIF API (Global Biodiversity Information Facility).

/// Сервис для работы с GBIF API (Global Biodiversity Information Facility).
///
/// Отвечает за:
/// - Поиск occurrence данных по латинскому названию
/// - Кэширование результатов (7 дней)
/// - Парсинг ответа и извлечение фото, стран, синонимов
class GbifService {
  static const String _tag = 'GBIF';
  static const String _baseUrl = 'https://api.gbif.org/v1/occurrence/search';
  static const String _cachePrefix = 'gbif_data_';
  static const Duration _cacheTtl = Duration(days: 7);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // ==================== ПУБЛИЧНЫЙ API ====================

  /// Получить данные из GBIF по латинскому названию.
  ///
  /// Сначала проверяет кэш, затем делает HTTP-запрос.
  /// Возвращает Map с обогащающими данными или null.
  Future<Map<String, dynamic>?> fetchGbifData(String latinName) async {
    try {
      AppLogger.api('Запрос данных GBIF для: $latinName', tag: _tag);

      // Проверяем кэш
      final cachedData = await getCachedGbifData(latinName);
      if (cachedData != null) {
        AppLogger.api('Найдены кэшированные данные GBIF для $latinName',
            tag: _tag);
        return cachedData;
      }

      // Выполняем запрос к GBIF API
      final gbifData = await _fetchFromGbifApi(latinName);
      if (gbifData != null) {
        await cacheGbifData(latinName, gbifData);
        AppLogger.api('Данные GBIF получены и закэшированы для $latinName',
            tag: _tag);
        return gbifData;
      }

      AppLogger.warning('Не удалось получить данные из GBIF для $latinName',
          tag: _tag);
      return null;
    } catch (e, stack) {
      AppLogger.error('Ошибка при получении данных GBIF для $latinName',
          error: e, stackTrace: stack, tag: _tag);
      return null;
    }
  }

  // ==================== КЭШИРОВАНИЕ ====================

  Future<void> cacheGbifData(String latinName, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(latinName);
      await prefs.setString(key, jsonEncode(data));
      AppLogger.db('Данные GBIF закэшированы: $key', tag: _tag);
    } catch (e, stack) {
      AppLogger.error('Ошибка кэширования данных GBIF',
          error: e, stackTrace: stack, tag: _tag);
    }
  }

  Future<Map<String, dynamic>?> getCachedGbifData(String latinName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(latinName);
      final cached = prefs.getString(key);

      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;

        // Проверяем "срок годности" кэша
        final lastUpdate = data['lastGbifUpdate'] as String?;
        if (lastUpdate != null) {
          final lastUpdateDate = DateTime.parse(lastUpdate);
          if (DateTime.now().difference(lastUpdateDate) > _cacheTtl) {
            AppLogger.api('Кэш GBIF устарел для $latinName', tag: _tag);
            await prefs.remove(key);
            return null;
          }
        }
        return data;
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Ошибка получения кэша GBIF',
          error: e, stackTrace: stack, tag: _tag);
      return null;
    }
  }

  Future<void> clearGbifCache(String latinName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey(latinName));
      AppLogger.db('Кэш GBIF очищен для $latinName', tag: _tag);
    } catch (e, stack) {
      AppLogger.error('Ошибка очистки кэша GBIF',
          error: e, stackTrace: stack, tag: _tag);
    }
  }

  Future<void> clearAllGbifCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          await prefs.remove(key);
        }
      }
      AppLogger.db('Весь кэш GBIF очищен', tag: _tag);
    } catch (e, stack) {
      AppLogger.error('Ошибка полной очистки кэша GBIF',
          error: e, stackTrace: stack, tag: _tag);
    }
  }

  // ==================== ВНУТРЕННИЕ МЕТОДЫ ====================

  Future<Map<String, dynamic>?> _fetchFromGbifApi(String latinName) async {
    final scientificName = _formatScientificName(latinName);
    final url = Uri.parse(
        '$_baseUrl?scientificName=$scientificName&limit=50&hasCoordinate=true');

    final headers = {
      'User-Agent': 'MyCactus-App/1.0 (https://github.com/pavel/mycactus)',
      'Accept': 'application/json',
    };

    int retries = 0;
    while (retries < _maxRetries) {
      try {
        AppLogger.api('Запрос к GBIF API: $url', tag: _tag);
        final response = await http.get(url, headers: headers);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return _parseGbifResponse(data);
        } else {
          AppLogger.warning('GBIF API вернул статус ${response.statusCode}',
              tag: _tag);
          throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (e) {
        retries++;
        AppLogger.warning(
            'Ошибка запроса к GBIF API (попытка $retries/$_maxRetries): $e',
            tag: _tag);
        if (retries >= _maxRetries) return null;
        await Future.delayed(_retryDelay);
      }
    }
    return null;
  }

  Map<String, dynamic>? _parseGbifResponse(Map<String, dynamic> data) {
    try {
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        AppLogger.warning('GBIF: нет результатов в ответе', tag: _tag);
        return null;
      }

      final occurrences = <GbifOccurrence>[];
      final photoUrls = <String>[];
      final countries = <String>[];

      for (final result in results) {
        if (result is! Map<String, dynamic>) continue;

        final occurrence = GbifOccurrence.fromJson(result);
        if (occurrence.hasValidCoordinates) {
          occurrences.add(occurrence);
          if (occurrence.country.isNotEmpty) {
            countries.add(occurrence.country);
          }
        }

        // Извлекаем фото
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
        AppLogger.warning('GBIF: нет валидных occurrence с координатами',
            tag: _tag);
        return null;
      }

      final mostFrequentCountry = _getMostFrequentCountry(countries);
      final synonyms = _extractSynonyms(data);
      final habitatDescription = _createHabitatDescription(occurrences);

      AppLogger.api(
          'GBIF обработан: ${occurrences.length} occurrence, '
          '${photoUrls.length} фото, страна: $mostFrequentCountry',
          tag: _tag);

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
    } catch (e, stack) {
      AppLogger.error('Ошибка парсинга ответа GBIF',
          error: e, stackTrace: stack, tag: _tag);
      return null;
    }
  }

  // ==================== УТИЛИТЫ ====================

  /// Определяет наиболее часто встречающуюся страну.
  String getMostFrequentCountry(List<String> countries) {
    return _getMostFrequentCountry(countries);
  }

  static String _getMostFrequentCountry(List<String> countries) {
    if (countries.isEmpty) return '';

    final countryCounts = <String, int>{};
    for (final country in countries) {
      final normalized = country.trim();
      if (normalized.isNotEmpty) {
        countryCounts[normalized] = (countryCounts[normalized] ?? 0) + 1;
      }
    }

    if (countryCounts.isEmpty) return '';

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

  static String _extractSynonyms(Map<String, dynamic> data) {
    try {
      final synonyms = <String>[];
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
      AppLogger.warning('Ошибка извлечения синонимов GBIF: $e', tag: _tag);
      return '';
    }
  }

  static String _createHabitatDescription(List<GbifOccurrence> occurrences) {
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
      if (countries.length > 5) description.write(' и др.');
    }
    if (localities.isNotEmpty) {
      if (description.isNotEmpty) description.write('. ');
      final localityList = localities.take(3).join(', ');
      description.write('Местонахождения: $localityList');
      if (localities.length > 3) description.write(' и др.');
    }
    description.write('. Основано на ${occurrences.length} точках наблюдения.');
    return description.toString();
  }

  static String _formatScientificName(String latinName) {
    return latinName
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(' ', '+')
        .trim();
  }

  static String _cacheKey(String latinName) =>
      '$_cachePrefix${latinName.toLowerCase().trim()}';
}
