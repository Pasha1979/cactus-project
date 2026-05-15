import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../core/logger/app_logger.dart';
import '../isolates/http_isolate.dart';
import 'gbif_service.dart';

/// Сервис для получения данных о растениях с Llifle.com.
///
/// Отвечает за:
/// - Поиск растения по латинскому названию
/// - Парсинг HTML страницы вида
/// - Извлечение фото, описания, ареала, синонимов, советов по уходу
/// - Интеграция с GBIF для обогащения данных
class LlifleService {

  LlifleService({GbifService? gbifService})
      : _gbifService = gbifService ?? GbifService();
  static const String _tag = 'LLIFLE';
  static const String _cachePrefix = 'plant_data_';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  final GbifService _gbifService;

  // ==================== ПУБЛИЧНЫЙ API ====================

  /// Получить данные о растении с Llifle + обогащение GBIF.
  ///
  /// Сначала проверяет кэш, затем делает HTTP-запрос к Llifle,
  /// парсит HTML и обогащает данными из GBIF.
  Future<Map<String, dynamic>?> fetchPlantData(String latinName) async {
    final prefs = await SharedPreferences.getInstance();
    final searchName = latinName.toLowerCase().trim();
    final cachedData = prefs.getString('$_cachePrefix$searchName');

    // Проверяем кэш
    if (cachedData != null) {
      AppLogger.api('Найдены кэшированные данные для $searchName', tag: _tag);
      final data = jsonDecode(cachedData);
      // Поддержка старого формата с photoUrl
      if (data['photoUrl'] != null && data['photoUrls'] == null) {
        data['photoUrls'] = [data['photoUrl']];
      }
      if (data['photoUrls'] is List && (data['photoUrls'] as List).isNotEmpty) {
        AppLogger.api('Кэшированные photoUrls: ${data['photoUrls']}', tag: _tag);
        return data;
      }
      // Если уже проверяли Llifle и фото там нет — не перезапрашиваем
      if (data['lliflePhotosChecked'] == true) {
        AppLogger.api(
            'Llifle не имеет фото для $searchName (проверено ранее), используем кэш',
            tag: _tag,);
        return data;
      }
      AppLogger.api(
          'Кэшированные данные не содержат валидных photoUrls, запрашиваем заново',
          tag: _tag,);
    }

    // Заголовки для HTTP-запросов
    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Referer': ApiConstants.llifleReferer,
      'Accept-Language': 'en-US,en;q=0.9',
    };

    final filterUrl = '${ApiConstants.llifleSearchUrl}$searchName';
    AppLogger.api('Поиск данных с фильтром: $filterUrl', tag: _tag);

    int retries = 0;
    bool fetched = false;
    String? responseBody;

    // Попытка загрузки страницы с фильтром
    while (retries < _maxRetries && !fetched) {
      try {
        final response = await http.get(Uri.parse(filterUrl), headers: headers);
        AppLogger.api('HTTP статус: ${response.statusCode}', tag: _tag);
        if (response.statusCode != 200 || response.body.isEmpty) {
          AppLogger.warning(
              'Страница не загружена: статус ${response.statusCode}, '
              'причина: ${response.reasonPhrase}',
              tag: _tag,);
          throw Exception('Не удалось загрузить страницу');
        }
        responseBody = response.body;
        fetched = true;
        AppLogger.api(
            'Страница успешно загружена, длина ответа: ${responseBody.length}',
            tag: _tag,);
      } catch (e) {
        retries++;
        AppLogger.warning(
            'Ошибка загрузки страницы с фильтром, '
            'попытка $retries/$_maxRetries: $e',
            tag: _tag,);
        if (retries == _maxRetries) {
          AppLogger.error(
              'Достигнуто максимальное количество попыток для страницы',
              tag: _tag,);
          return null;
        }
        await Future.delayed(_retryDelay);
      }
    }

    if (!fetched || responseBody == null) {
      AppLogger.error('Не удалось загрузить страницу с фильтром', tag: _tag);
      return null;
    }

    // Парсинг страницы с фильтром
    final document = html_parser.parse(responseBody);
    final speciesLinks = document
        .querySelectorAll('a[href*="/Encyclopedia/CACTI/Family/Cactaceae/"]');
    AppLogger.api('Найдено ссылок на виды: ${speciesLinks.length}', tag: _tag);

    for (var link in speciesLinks) {
      final href = link.attributes['href'];
      if (href == null) continue;

      final name = link.text.trim().toLowerCase();
      AppLogger.api('Проверка ссылки: $name (href: $href)', tag: _tag);
      if (name == searchName || name.contains(searchName)) {
        final idMatch = RegExp(r'/Cactaceae/(\d+)/').firstMatch(href);
        final speciesId = idMatch?.group(1);
        if (speciesId != null) {
          return await _fetchSpeciesPage(
            speciesId: speciesId,
            latinName: latinName,
            searchName: searchName,
            filterUrl: filterUrl,
            prefs: prefs,
          );
        }
      }
    }

    AppLogger.warning('Данные для $searchName не найдены', tag: _tag);
    return null;
  }

  // ==================== ПАРСИНГ ====================

  /// Парсит данные вида из HTML документа Llifle.
  Map<String, String> parseLlifleData(Document document) {
    // Habitat и country из "Origin and Habitat"
    final originElement = document
        .querySelector('p.expandable.Description_Sheet_Origin_and_Habitat');
    String habitat = '';
    String country = '';
    if (originElement != null) {
      habitat = originElement.text.trim();

      final countries = <String>{
        'Mexico', 'United States', 'Argentina', 'Bolivia', 'Chile', 'Peru',
        'Brazil', 'Paraguay', 'Uruguay', 'Colombia', 'Ecuador', 'Venezuela',
        'Spain', 'South Africa', 'Namibia', 'Madagascar', 'Australia',
        'Guatemala', 'Honduras', 'Costa Rica',
      };
      for (final c in countries) {
        if (habitat.toLowerCase().contains(c.toLowerCase())) {
          country = c;
          break;
        }
      }
    }

    // CareTips из "Cultivation and Propagation"
    final careElement = document.querySelector(
        'p.expandable.Description_Sheet_Cultivation_and_Propagation',);
    final careTips = careElement?.text.trim() ?? '';

    // Description
    final descElement = document
        .querySelector('p.expandable.Description_Sheet_Description');
    final description =
        descElement?.text.trim() ?? _parseDescription(document);

    // Synonyms
    final synonymsElement = document.querySelector('#short_synonyms_list ul');
    String synonyms = '';
    if (synonymsElement != null) {
      synonyms =
          synonymsElement.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    }

    return {
      'country': country,
      'habitat': habitat,
      'careTips': careTips,
      'description': description,
      'synonyms': synonyms,
    };
  }

  // ==================== ВНУТРЕННИЕ МЕТОДЫ ====================

  Future<Map<String, dynamic>?> _fetchSpeciesPage({
    required String speciesId,
    required String latinName,
    required String searchName,
    required String filterUrl,
    required SharedPreferences prefs,
  }) async {
    final speciesUrl = '${ApiConstants.llifleSpeciesUrl}$speciesId/';
    AppLogger.api('Загрузка страницы вида через HttpIsolate (Вариант Б): $speciesUrl', tag: _tag);

    // Вариант Б: HTTP + парсинг + jsonEncode — всё в isolate
    final serialized = await HttpIsolate.fetchAndParseLlifle(
      speciesUrl,
      filterUrl,
    );

    if (serialized == null) {
      AppLogger.error('Не удалось парсить страницу вида через HttpIsolate', tag: _tag);
      return null;
    }

    final rawData = jsonDecode(serialized) as Map<String, dynamic>;
    final rawPhotoUrls = rawData['photoUrls'] as List<dynamic>? ?? [];

    // URL processing — в main thread (лёгкая операция)
    final photoUrls = <String>{};
    for (final rawUrl in rawPhotoUrls) {
      var photoUrl = rawUrl.toString();
      if (!photoUrl.startsWith('http')) {
        photoUrl = '${ApiConstants.llifleBaseUrl}$photoUrl';
      }
      photoUrl = photoUrl.replaceAll(
          '${ApiConstants.llifleBaseUrl}photos/', ApiConstants.lliflePhotosUrl,);
      photoUrl = photoUrl.replaceAll('+', '_');
      photoUrl = photoUrl.replaceAll('_m.jpg', '_l.jpg');

      // Thumbnails: дополнительная замена
      if (rawUrl.toString().contains('/thumbnails/')) {
        photoUrl = photoUrl.replaceAll('/thumbnails/', '/photos/');
      }

      if (photoUrl.contains('llifle.com') && photoUrl.endsWith('.jpg')) {
        AppLogger.api('Добавлен URL: $photoUrl', tag: _tag);
        photoUrls.add(Uri.encodeFull(photoUrl));
      } else {
        AppLogger.warning('Пропущен некорректный URL: $photoUrl', tag: _tag);
      }
    }

    final photoUrlList = photoUrls.toList();
    AppLogger.api('Найдено фото: $photoUrlList', tag: _tag);

    // Данные вида — уже извлечены в isolate
    final habitat = rawData['habitat'] as String? ?? '';
    final description = rawData['description'] as String? ?? '';
    final careTips = rawData['careTips'] as String? ?? '';
    final synonyms = rawData['synonyms'] as String? ?? '';
    final country = rawData['country'] as String? ?? '';

    AppLogger.api(
        'Описание: ${description.length > 50 ? description.substring(0, 50) : description}...',
        tag: _tag,);
    AppLogger.api('Естественный ареал: $habitat', tag: _tag);
    AppLogger.api('Страна: $country', tag: _tag);
    AppLogger.api(
        'Особенности ухода: ${careTips.length > 50 ? careTips.substring(0, 50) : careTips}...',
        tag: _tag,);
    AppLogger.api('Синонимы: $synonyms', tag: _tag);

    final plantData = {
      'speciesId': speciesId,
      'photoUrls': photoUrlList,
      'lliflePhotosChecked': true,
      'habitat': habitat,
      'description': description,
      'synonyms': synonyms,
      'careTips': careTips,
      'country': country,
    };

    // === ИНТЕГРАЦИЯ GBIF ===
    AppLogger.api('Запрос обогащения данных из GBIF для $latinName',
        tag: _tag,);
    final gbifData = await _gbifService.fetchGbifData(latinName);

    if (gbifData != null) {
      AppLogger.api('Данные GBIF получены, обогащаем Llifle данные',
          tag: _tag,);
      final enrichedData = Map<String, dynamic>.from(plantData);

      // Country: GBIF приоритетнее
      if (gbifData['gbifCountry'] != null &&
          gbifData['gbifCountry'].toString().isNotEmpty) {
        enrichedData['country'] = gbifData['gbifCountry'];
        AppLogger.api('Страна обновлена из GBIF: ${gbifData['gbifCountry']}',
            tag: _tag,);
      }

      // Habitat: объединяем
      final llifleHabitat = plantData['habitat'] as String? ?? '';
      final gbifHabitat = gbifData['gbifHabitat'] as String? ?? '';
      if (gbifHabitat.isNotEmpty) {
        enrichedData['habitat'] = llifleHabitat.isNotEmpty
            ? '$llifleHabitat\n\n$gbifHabitat'
            : gbifHabitat;
        AppLogger.api('Ареал обогащен данными GBIF', tag: _tag);
      }

      // Synonyms: объединяем уникальные
      final llifleSynonyms = plantData['synonyms'] as String? ?? '';
      final gbifSynonyms = gbifData['gbifSynonyms'] as String? ?? '';
      final allSynonyms = <String>{};
      if (llifleSynonyms.isNotEmpty) {
        allSynonyms.addAll(llifleSynonyms.split(', ').map((s) => s.trim()));
      }
      if (gbifSynonyms.isNotEmpty) {
        allSynonyms.addAll(gbifSynonyms.split(', ').map((s) => s.trim()));
        AppLogger.api('Синонимы обогащены из GBIF', tag: _tag);
      }
      enrichedData['synonyms'] = allSynonyms.join(', ');
      if (allSynonyms.isNotEmpty) {
        AppLogger.api('Всего синонимов: ${allSynonyms.length}', tag: _tag);
      }

      // GBIF специфические поля
      enrichedData['gbifPhotoUrls'] = gbifData['gbifPhotoUrls'] ?? [];
      enrichedData['gbifOccurrences'] = gbifData['gbifOccurrences'] ?? [];
      enrichedData['gbifOccurrenceCount'] = gbifData['gbifOccurrenceCount'] ?? 0;
      enrichedData['gbifPhotoCount'] = gbifData['gbifPhotoCount'] ?? 0;
      enrichedData['lastGbifUpdate'] = gbifData['lastGbifUpdate'];

      AppLogger.api(
          'Данные успешно обогащены GBIF: '
          '${gbifData['gbifOccurrenceCount']} occurrence, '
          '${gbifData['gbifPhotoCount']} фото',
          tag: _tag,);

      await prefs.setString(
          '$_cachePrefix$searchName', jsonEncode(enrichedData),);
      AppLogger.db('Сохранены обогащенные данные для $searchName', tag: _tag);
      return enrichedData;
    } else {
      AppLogger.warning(
          'Не удалось получить данные из GBIF, используем только Llifle',
          tag: _tag,);
      await prefs.setString('$_cachePrefix$searchName', jsonEncode(plantData));
      AppLogger.db('Сохранены данные Llifle для $searchName', tag: _tag);
      return plantData;
    }
  }

  String _parseDescription(Document document) {
    try {
      final element =
          document.querySelector('p.Description_Sheet_Description');
      if (element != null) {
        return element.text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      }
      return '';
    } catch (e) {
      AppLogger.warning('Ошибка парсинга описания: $e', tag: _tag);
      return '';
    }
  }
}
