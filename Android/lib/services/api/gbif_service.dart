import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../core/logger/app_logger.dart';
import '../../core/config/feature_flags.dart';
import '../../models/gbif_occurrence.dart';
import '../isolates/http_isolate.dart';

/// Сервис для работы с GBIF API (Global Biodiversity Information Facility).

/// Сервис для работы с GBIF API (Global Biodiversity Information Facility).
///
/// Отвечает за:
/// - Поиск occurrence данных по латинскому названию
/// - Кэширование результатов (7 дней)
/// - Парсинг ответа и извлечение фото, стран, синонимов
class GbifService {
  static const String _tag = 'GBIF';
  static const String _baseUrl = ApiConstants.gbifOccurrenceSearchUrl;
  static const String _cachePrefix = 'gbif_data_';
  static const Duration _cacheTtl = Duration(days: 7);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // ==================== ПУБЛИЧНЫЙ API ====================

  /// Получить данные из GBIF по латинскому названию.
  ///
  /// Сначала проверяет кэш, затем делает HTTP-запрос.
  /// Возвращает Map с обогащающими данными или null.
  ///
  /// Проверяет FeatureFlag [enableGbifParsing] - если выключен, возвращает null.
  Future<Map<String, dynamic>?> fetchGbifData(String latinName) async {
    // Проверяем Feature Flag
    if (!FeatureFlags.isEnabled(FeatureFlag.enableGbifParsing)) {
      AppLogger.api('GBIF parsing отключен через Feature Flag', tag: _tag);
      return null;
    }

    try {
      AppLogger.api('Запрос данных GBIF для: $latinName', tag: _tag);

      // Проверяем кэш
      final cachedData = await getCachedGbifData(latinName);
      if (cachedData != null) {
        AppLogger.api('Найдены кэшированные данные GBIF для $latinName',
            tag: _tag,);
        return cachedData;
      }

      // Выполняем запрос к GBIF API
      final gbifData = await _fetchFromGbifApi(latinName);
      if (gbifData != null) {
        await cacheGbifData(latinName, gbifData);
        AppLogger.api('Данные GBIF получены и закэшированы для $latinName',
            tag: _tag,);
        return gbifData;
      }

      AppLogger.warning('Не удалось получить данные из GBIF для $latinName',
          tag: _tag,);
      return null;
    } catch (e, stack) {
      AppLogger.error('Ошибка при получении данных GBIF для $latinName',
          error: e, stackTrace: stack, tag: _tag,);
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
          error: e, stackTrace: stack, tag: _tag,);
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
          final lastUpdateDate = DateTime.tryParse(lastUpdate);
          if (lastUpdateDate != null && DateTime.now().difference(lastUpdateDate) > _cacheTtl) {
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
          error: e, stackTrace: stack, tag: _tag,);
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
          error: e, stackTrace: stack, tag: _tag,);
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
          error: e, stackTrace: stack, tag: _tag,);
    }
  }

  // ==================== ВНУТРЕННИЕ МЕТОДЫ ====================

  Future<Map<String, dynamic>?> _fetchFromGbifApi(String latinName) async {
    final scientificName = _formatScientificName(latinName);
    final url =
        '$_baseUrl?scientificName=$scientificName&limit=50&hasCoordinate=true';

    int retries = 0;
    while (retries < _maxRetries) {
      try {
        AppLogger.api('Запрос к GBIF API (isolate): $url', tag: _tag);

        // Вариант Б: HTTP + парсинг + jsonEncode — всё в isolate
        final serialized = await HttpIsolate.fetchAndParseGbif(url);
        if (serialized == null) {
          throw Exception('HttpIsolate вернул null');
        }

        final rawData = jsonDecode(serialized) as Map<String, dynamic>;
        return _buildGbifResult(rawData);
      } catch (e) {
        retries++;
        AppLogger.warning(
            'Ошибка запроса к GBIF API (попытка $retries/$_maxRetries): $e',
            tag: _tag,);
        if (retries >= _maxRetries) return null;
        await Future.delayed(_retryDelay);
      }
    }
    return null;
  }

  Map<String, dynamic>? _buildGbifResult(Map<String, dynamic> rawData) {
    try {
      final occurrenceMaps = rawData['occurrences'] as List<dynamic>? ?? [];
      if (occurrenceMaps.isEmpty) {
        AppLogger.warning('GBIF: нет валидных occurrence',
            tag: _tag,);
        return null;
      }

      final occurrences = occurrenceMaps
          .map((m) => GbifOccurrence.fromJson(m as Map<String, dynamic>))
          .toList();

      final photoUrls = (rawData['photoUrls'] as List<dynamic>? ?? [])
          .map((u) => u.toString())
          .toList();
      final countries = (rawData['countries'] as List<dynamic>? ?? [])
          .map((c) => c.toString())
          .toList();
      final mostFrequentCountry = _getMostFrequentCountry(countries);
      final synonyms = rawData['synonyms'] as String? ?? '';
      final habitatDescription = _createHabitatDescription(occurrences);

      AppLogger.api(
          'GBIF обработан: ${occurrences.length} occurrence, '
          '${photoUrls.length} фото, страна: $mostFrequentCountry',
          tag: _tag,);

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
      AppLogger.error('Ошибка сборки результата GBIF',
          error: e, stackTrace: stack, tag: _tag,);
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
