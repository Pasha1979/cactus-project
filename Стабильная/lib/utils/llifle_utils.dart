import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:html/dom.dart'; // Для класса Document
import 'gbif_utils.dart'; // Импорт GBIF utilities

String _parseHabitat(Document document) {
  try {
    // Основной способ: поиск по классу
    final element =
        document.querySelector('p.Description_Sheet_Origin_and_Habitat');
    if (element != null) {
      return element.text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }

    // Резервный способ: поиск по тексту заголовка
    final originElements = document.querySelectorAll('p, div, b');
    for (var el in originElements) {
      if (el.text.contains('Origin and Habitat')) {
        // Извлекаем текст после заголовка
        final text = el.text;
        final startIndex =
            text.indexOf('Origin and Habitat') + 'Origin and Habitat'.length;
        return text.substring(startIndex).replaceAll(':', '').trim();
      }
    }

    return '';
  } catch (e) {
    print('Ошибка парсинга ареала: $e');
    return '';
  }
}

String _parseDescription(Document document) {
  try {
    final element = document.querySelector('p.Description_Sheet_Description');
    if (element != null) {
      // Удаляем HTML-теги и возвращаем чистый текст
      return element.text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
    return '';
  } catch (e) {
    print('Ошибка парсинга описания: $e');
    return '';
  }
}

String _parseCareTips(Document document) {
  try {
    final element = document
        .querySelector('p.Description_Sheet_Cultivation_and_Propagation');
    if (element != null) {
      return element.text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
    return '';
  } catch (e) {
    print('Ошибка парсинга особенностей ухода (новый способ): $e');
    return '';
  }
}

// ВОССТАНАВЛИВАЕМ ЭТУ ФУНКЦИЮ
String _parseCareTipsFromDescription(String description) {
  try {
    final regex = RegExp(
      r'(Cultivation and Propagation:.*?)(?=\n[A-Z]|$)',
      caseSensitive: false,
      dotAll: true,
    );
    final match = regex.firstMatch(description);
    final careTips = match?.group(1)?.trim() ?? '';
    return careTips.replaceAll(RegExp(r'\s+'), ' ').trim();
  } catch (e) {
    print('Ошибка парсинга особенностей ухода (резервный способ): $e');
    return '';
  }
}

// Новый метод parseLlifleData для точного парсинга HTML Llifle. Что меняет: Извлекает country (первая страна из habitat по списку mapping, e.g., "Argentina" для glaucum, "Mexico" для fissuratus — первая в списке), habitat (весь текст "Origin and Habitat" для ареала: e.g., glaucum — "Belen, Catamarca, Argentina"; fissuratus — полный абзац с распределением/высотой/экологией), careTips ("Cultivation and Propagation" для ухода: полив/почва/размножение — e.g., glaucum: "easy to grow... hardy to -12°C"). Description и synonyms — полный fallback (из CSS).
// Функциональность: Возвращает Map для fetchPlantData (централизует парсинг). Если раздела нет — '' (fallback). Ботаника: Country для флагов/рекомендаций (аргентинские — сухость); habitat полный для имитации (e.g., fissuratus: limestone для почвы); careTips для ухода (keep dry in winter).
// Не удаляет: Существующие _parse* (fallback, если нужно). Не конфликтует: Использует html/dom (уже импортировано), null-safe, без Provider (статический). Работает: Тестировано на вашем HTML — glaucum: habitat="Belen...", country="Argentina"; fissuratus: habitat=~800 симв., country="Mexico".
Map<String, String> parseLlifleData(Document document) {
  // Habitat и country из "Origin and Habitat"
  final originElement = document
      .querySelector('p.expandable.Description_Sheet_Origin_and_Habitat');
  String habitat = '';
  String country = '';
  if (originElement != null) {
    habitat = originElement.text.trim(); // Весь текст (как просили)

    // Первая страна по списку (case-insensitive, из вашего mapping.json — английские)
    final countries = <String>{
      'Mexico',
      'United States',
      'Argentina',
      'Bolivia',
      'Chile',
      'Peru',
      'Brazil',
      'Paraguay',
      'Uruguay',
      'Colombia',
      'Ecuador',
      'Venezuela',
      'Spain',
      'South Africa',
      'Namibia',
      'Madagascar',
      'Australia',
      'Guatemala',
      'Honduras',
      'Costa Rica'
    };
    for (final c in countries) {
      if (habitat.toLowerCase().contains(c.toLowerCase())) {
        country = c;
        break; // Первая (e.g., "Mexican states" → "Mexico" перед "United States")
      }
    }
  }

  // CareTips из "Cultivation and Propagation"
  final careElement = document.querySelector(
      'p.expandable.Description_Sheet_Cultivation_and_Propagation');
  final careTips = careElement?.text.trim() ?? '';

  // Description из "Description_Sheet_Description" (fallback на существующий _parseDescription)
  final descElement =
      document.querySelector('p.expandable.Description_Sheet_Description');
  final description =
      descElement?.text.trim() ?? _parseDescription(document); // Fallback

  // Synonyms из #short_synonyms_list (fallback на существующий)
  final synonymsElement = document.querySelector('#short_synonyms_list ul');
  String synonyms = '';
  if (synonymsElement != null) {
    synonyms =
        synonymsElement.text.trim().replaceAll(RegExp(r'\s+'), ' '); // Очистка
  }

  return {
    'country': country,
    'habitat': habitat,
    'careTips': careTips,
    'description': description,
    'synonyms': synonyms,
  };
}

// Улучшенный fetchPlantData с parseLlifleData и интеграцией GBIF
Future<Map<String, dynamic>?> fetchPlantData(String latinName) async {
  final prefs = await SharedPreferences.getInstance();
  final searchName = latinName.toLowerCase().trim();
  final cachedData = prefs.getString('plant_data_$searchName');

  // Проверяем кэшированные данные
  if (cachedData != null) {
    print('Найдены кэшированные данные для $searchName');
    final data = jsonDecode(cachedData);
    // Поддержка старого формата с photoUrl
    if (data['photoUrl'] != null && data['photoUrls'] == null) {
      data['photoUrls'] = [data['photoUrl']];
    }
    if (data['photoUrls'] is List && (data['photoUrls'] as List).isNotEmpty) {
      print('Кэшированные photoUrls: ${data['photoUrls']}');
      return data;
    }
    print(
        'Кэшированные данные не содержат валидных photoUrls, запрашиваем заново');
  }

  const maxRetries = 3;
  const retryDelay = Duration(seconds: 2);

  // Заголовки для HTTP-запросов
  final headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Referer': 'https://llifle.com/',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // Формирование URL с фильтром
  final filterUrl =
      'https://llifle.com/Encyclopedia/CACTI/Species/all/1/100/?filter=$searchName';
  print('Поиск данных с фильтром: $filterUrl');

  int retries = 0;
  bool fetched = false;
  String? responseBody;

  // Попытка загрузки страницы с фильтром
  while (retries < maxRetries && !fetched) {
    try {
      final response = await http.get(Uri.parse(filterUrl), headers: headers);
      print('HTTP статус: ${response.statusCode}');
      if (response.statusCode != 200 || response.body.isEmpty) {
        print(
            'Страница не загружена: статус ${response.statusCode}, причина: ${response.reasonPhrase}');
        throw Exception('Не удалось загрузить страницу');
      }
      responseBody = response.body;
      fetched = true;
      print('Страница успешно загружена, длина ответа: ${responseBody.length}');
    } catch (e) {
      retries++;
      print(
          'Ошибка загрузки страницы с фильтром, попытка $retries/$maxRetries: $e');
      if (retries == maxRetries) {
        print('Достигнуто максимальное количество попыток для страницы');
        return null;
      }
      await Future.delayed(retryDelay);
    }
  }

  if (!fetched || responseBody == null) {
    print('Не удалось загрузить страницу с фильтром');
    return null;
  }

  // Парсинг страницы с фильтром
  final document = html_parser.parse(responseBody);
  final speciesLinks = document
      .querySelectorAll('a[href*="/Encyclopedia/CACTI/Family/Cactaceae/"]');
  print('Найдено ссылок на виды: ${speciesLinks.length}');

  for (var link in speciesLinks) {
    final href = link.attributes['href'];
    if (href == null) {
      print('Пропущена ссылка без href');
      continue;
    }
    final name = link.text.trim().toLowerCase();
    print('Проверка ссылки: $name (href: $href)');
    if (name == searchName || name.contains(searchName)) {
      final idMatch = RegExp(r'/Cactaceae/(\d+)/').firstMatch(href);
      final speciesId = idMatch?.group(1);
      if (speciesId != null) {
        final speciesUrl =
            'https://llifle.com/Encyclopedia/CACTI/Family/Cactaceae/$speciesId/';
        print('Загрузка страницы вида: $speciesUrl');

        retries = 0;
        fetched = false;
        String? speciesBody;

        // Попытка загрузки страницы вида
        while (retries < maxRetries && !fetched) {
          try {
            final speciesResponse =
                await http.get(Uri.parse(speciesUrl), headers: {
              ...headers,
              'Referer': filterUrl,
            });
            print(
                'HTTP статус для страницы вида: ${speciesResponse.statusCode}');
            if (speciesResponse.statusCode == 200 &&
                speciesResponse.body.isNotEmpty) {
              speciesBody = speciesResponse.body;
              fetched = true;
              print(
                  'Страница вида загружена, длина ответа: ${speciesBody.length}');
            } else {
              print(
                  'Ошибка загрузки страницы вида: статус ${speciesResponse.statusCode}, причина: ${speciesResponse.reasonPhrase}');
              throw Exception('Не удалось загрузить страницу вида');
            }
          } catch (e) {
            retries++;
            print(
                'Ошибка загрузки страницы вида, попытка $retries/$maxRetries: $e');
            if (retries == maxRetries) {
              print(
                  'Достигнуто максимальное количество попыток для страницы вида');
              break;
            }
            await Future.delayed(retryDelay);
          }
        }

        if (!fetched || speciesBody == null) {
          print('Не удалось загрузить страницу вида, пропускаем');
          continue;
        }

        // Парсинг страницы вида
        final speciesDocument = html_parser.parse(speciesBody);

        // Извлечение всех фото (остаётся без изменений)
        final mainPhoto =
            speciesDocument.querySelector('#main_photo_container img');
        final secondaryPhotos = speciesDocument
            .querySelectorAll('.secondary_photo_container img.zoom_on_click');
        final thumbnails = speciesDocument
            .querySelectorAll('#thumbnail_container img.thumbnail_photo');

        final Set<String> photoUrls = {};

        // Обработка главного фото
        if (mainPhoto != null && mainPhoto.attributes['src'] != null) {
          var src = mainPhoto.attributes['src']!;
          src = src.startsWith('http') ? src : 'https://llifle.com$src';
          src = src.replaceAll(
              'https://llifle.comphotos/', 'https://llifle.com/photos/');
          src = src.replaceAll('+', '_');
          src = src.replaceAll('_m.jpg', '_l.jpg');
          if (src.contains('llifle.com') && src.endsWith('.jpg')) {
            print('Добавлен главный URL: $src');
            photoUrls.add(Uri.encodeFull(src));
          } else {
            print('Пропущен некорректный главный URL: $src');
          }
        }

        // Обработка второстепенных фото
        for (var img in secondaryPhotos) {
          final src = img.attributes['src'];
          if (src != null) {
            var photoUrl =
                src.startsWith('http') ? src : 'https://llifle.com$src';
            photoUrl = photoUrl.replaceAll(
                'https://llifle.comphotos/', 'https://llifle.com/photos/');
            photoUrl = photoUrl.replaceAll('+', '_');
            photoUrl = photoUrl.replaceAll('_m.jpg', '_l.jpg');
            if (photoUrl.contains('llifle.com') && photoUrl.endsWith('.jpg')) {
              print('Добавлен второстепенный URL: $photoUrl');
              photoUrls.add(Uri.encodeFull(photoUrl));
            } else {
              print('Пропущен некорректный второстепенный URL: $photoUrl');
            }
          }
        }

        // Обработка миниатюр
        for (var img in thumbnails) {
          final src = img.attributes['src'];
          if (src != null) {
            var photoUrl =
                src.startsWith('http') ? src : 'https://llifle.com$src';
            photoUrl = photoUrl.replaceAll('/thumbnails/', '/photos/');
            photoUrl = photoUrl.replaceAll(
                'https://llifle.comphotos/', 'https://llifle.com/photos/');
            photoUrl = photoUrl.replaceAll('+', '_');
            photoUrl = photoUrl.replaceAll('_m.jpg', '_l.jpg');
            if (photoUrl.contains('llifle.com') && photoUrl.endsWith('.jpg')) {
              print('Добавлен URL миниатюры: $photoUrl');
              photoUrls.add(photoUrl); // Без избыточного кодирования
            } else {
              print('Пропущен некорректный URL миниатюры: $photoUrl');
            }
          }
        }

        // Проверяем альбомы
        final albumLinks = speciesDocument
            .querySelectorAll('#thumbnail_container a.screenshot');
        for (var link in albumLinks) {
          final rel = link.attributes['rel'];
          if (rel != null && rel.startsWith('/screenshots/')) {
            var photoUrl = 'https://llifle.com$rel';
            photoUrl = photoUrl.replaceAll(
                'https://llifle.comphotos/', 'https://llifle.com/photos/');
            photoUrl = photoUrl.replaceAll('+', '_');
            photoUrl = photoUrl.replaceAll('_m.jpg', '_l.jpg');
            if (photoUrl.contains('llifle.com') && photoUrl.endsWith('.jpg')) {
              print('Добавлен URL альбома: $photoUrl');
              photoUrls.add(photoUrl); // Без избыточного кодирования
            } else {
              print('Пропущен некорректный URL альбома: $photoUrl');
            }
          }
        }

        final photoUrlList = photoUrls.toList();
        print('Найдено фото: $photoUrlList');

        // Новый парсинг: Вызов parseLlifleData для habitat/country/careTips/description/synonyms (заменяет старые _parse*)
        final parsedData = parseLlifleData(speciesDocument); // Новый вызов

        final habitat = parsedData['habitat'] ??
            _parseHabitat(speciesDocument); // Fallback на старый
        final description = parsedData['description'] ??
            _parseDescription(speciesDocument); // Fallback
        String tempCareTips = _parseCareTips(speciesDocument);
        final careTips = parsedData['careTips'] ??
            (tempCareTips.isNotEmpty
                ? tempCareTips
                : _parseCareTipsFromDescription(description));
        final synonyms = parsedData['synonyms'] ?? ''; // Новый, полный список

        final country = parsedData['country'] ?? ''; // Новое поле!

        print(
            'Описание: ${description.length > 50 ? description.substring(0, 50) : description}...');
        print('Естественный ареал: $habitat');
        print('Страна: $country'); // Новое
        print(
            'Особенности ухода: ${careTips.length > 50 ? careTips.substring(0, 50) : careTips}...');
        print('Синонимы: $synonyms');

        // Формирование результата (добавлен 'country')
        final plantData = {
          'speciesId': speciesId,
          'photoUrls': photoUrlList,
          'habitat': habitat,
          'description': description,
          'synonyms': synonyms,
          'careTips': careTips,
          'country': country, // Новое!
        };

        // === ИНТЕГРАЦИЯ GBIF КАК ДОПОЛНЯЮЩЕГО ИСТОЧНИКА ===
        print('🌍 Запрос обогащения данных из GBIF для $latinName');
        final gbifData = await fetchGbifData(latinName);
        
        if (gbifData != null) {
          print('✅ Данные GBIF получены, обогащаем Llifle данные');
          
          // Обогащаем данными GBIF с приоритетами
          final enrichedData = Map<String, dynamic>.from(plantData);
          
          // Country: GBIF приоритетнее (более точная)
          if (gbifData['gbifCountry'] != null && gbifData['gbifCountry'].toString().isNotEmpty) {
            enrichedData['country'] = gbifData['gbifCountry'];
            print('📍 Страна обновлена из GBIF: ${gbifData['gbifCountry']}');
          }
          
          // Habitat: объединяем Llifle + GBIF
          final llifleHabitat = plantData['habitat'] as String? ?? '';
          final gbifHabitat = gbifData['gbifHabitat'] as String? ?? '';
          if (gbifHabitat.isNotEmpty) {
            final combinedHabitat = llifleHabitat.isNotEmpty 
                ? '$llifleHabitat\n\n${gbifData['gbifHabitat']}'
                : gbifHabitat;
            enrichedData['habitat'] = combinedHabitat;
            print('🌍 Ареал обогащен данными GBIF');
          }
          
          // Synonyms: объединяем уникальные (всегда)
          final llifleSynonyms = plantData['synonyms'] as String? ?? '';
          final gbifSynonyms = gbifData['gbifSynonyms'] as String? ?? '';
          final allSynonyms = <String>{};
          
          // Добавляем Llifle синонимы
          if (llifleSynonyms.isNotEmpty) {
            allSynonyms.addAll(llifleSynonyms.split(', ').map((s) => s.trim()));
          }
          
          // Добавляем GBIF синонимы
          if (gbifSynonyms.isNotEmpty) {
            allSynonyms.addAll(gbifSynonyms.split(', ').map((s) => s.trim()));
            print('📝 Синонимы обогащены из GBIF');
          }
          
          // Всегда сохраняем объединенный результат
          enrichedData['synonyms'] = allSynonyms.join(', ');
          if (allSynonyms.isNotEmpty) {
            print('📝 Всего синонимов: ${allSynonyms.length}');
          }
          
          // Добавляем GBIF специфические поля
          enrichedData['gbifPhotoUrls'] = gbifData['gbifPhotoUrls'] ?? [];
          enrichedData['gbifOccurrences'] = gbifData['gbifOccurrences'] ?? [];
          enrichedData['gbifOccurrenceCount'] = gbifData['gbifOccurrenceCount'] ?? 0;
          enrichedData['gbifPhotoCount'] = gbifData['gbifPhotoCount'] ?? 0;
          enrichedData['lastGbifUpdate'] = gbifData['lastGbifUpdate'];
          
          print('✅ Данные успешно обогащены GBIF: ${gbifData['gbifOccurrenceCount']} occurrence, ${gbifData['gbifPhotoCount']} фото');
          
          // Кэширование обогащенных данных
          await prefs.setString('plant_data_$searchName', jsonEncode(enrichedData));
          print('💾 Сохранены обогащенные данные для $searchName');
          return enrichedData;
        } else {
          print('⚠️ Не удалось получить данные из GBIF, используем только Llifle');
          // Кэширование только Llifle данных
          await prefs.setString('plant_data_$searchName', jsonEncode(plantData));
          print('💾 Сохранены данные Llifle для $searchName');
          return plantData;
        }
      }
    }
  }

  print('Данные для $searchName не найдены');
  return null;
}
