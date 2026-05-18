import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../../core/logger/app_logger.dart';

/// Isolate для полного pipeline: HTTP + парсинг + сериализация.
///
/// Вариант Б: HTTP-запрос, парсинг HTML/JSON и jsonEncode выполняются
/// в isolate — UI thread полностью свободен.
///
/// SharedPreferences остаётся в main thread (platform channel).
///
/// Возвращает готовую JSON-строку, которую main thread сохраняет в кэш.
class HttpIsolate {
  static const Duration _timeout = Duration(seconds: 15);

  /// Выполнить HTTP GET + парсинг GBIF JSON в isolate.
  ///
  /// Возвращает готовую JSON-строку (serialized Map) или null при ошибке.
  static Future<String?> fetchAndParseGbif(String url) async {
    return _runInIsolate(_gbifEntryPoint, {'url': url});
  }

  /// Выполнить HTTP GET + парсинг Llifle HTML в isolate.
  ///
  /// Возвращает готовую JSON-строку (serialized Map) или null при ошибке.
  static Future<String?> fetchAndParseLlifle(String url, String referer) async {
    return _runInIsolate(_llifleEntryPoint, {'url': url, 'referer': referer});
  }

  static Future<String?> _runInIsolate(
    void Function(List<dynamic>) entryPoint,
    Map<String, dynamic> payload,
  ) async {
    final sw = Stopwatch()..start();
    final receivePort = ReceivePort();
    Isolate? isolate;

    try {
      isolate = await Isolate.spawn(
        entryPoint,
        [receivePort.sendPort, payload],
      );

      final result = await receivePort.first.timeout(
        _timeout,
        onTimeout: () {
          throw HttpIsolateException('HTTP isolate timeout after $_timeout');
        },
      );

      if (result is Map<String, dynamic>) {
        if (result['success'] == true) {
          sw.stop();
          AppLogger.api('[HttpIsolate] Completed in ${sw.elapsedMilliseconds}ms', tag: 'HTTP_ISOLATE');
          return result['data'] as String?;
        } else {
          throw HttpIsolateException(
            result['error']?.toString() ?? 'Unknown isolate error',
          );
        }
      } else {
        throw HttpIsolateException('Invalid isolate response format');
      }
    } catch (e) {
      sw.stop();
      AppLogger.error('[HttpIsolate] Failed after ${sw.elapsedMilliseconds}ms: $e', tag: 'HTTP_ISOLATE');
      return null;
    } finally {
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }
}

// ==================== GBIF Entry Point ====================

void _gbifEntryPoint(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final payload = args[1] as Map<String, dynamic>;
  final url = payload['url'] as String;

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'MyCactus-App/1.0 (https://github.com/pavel/mycactus)',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      sendPort.send({
        'success': false,
        'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
      });
      return;
    }

    final rawData = jsonDecode(response.body) as Map<String, dynamic>;
    final parsed = _parseGbifData(rawData);
    final serialized = jsonEncode(parsed);

    sendPort.send({'success': true, 'data': serialized});
  } catch (e, stack) {
    sendPort.send({'success': false, 'error': '$e\n$stack'});
  }
}

Map<String, dynamic> _parseGbifData(Map<String, dynamic> data) {
  final results = data['results'] as List<dynamic>?;
  if (results == null || results.isEmpty) {
    return {
      'occurrences': <Map<String, dynamic>>[],
      'photoUrls': <String>[],
      'countries': <String>[],
      'synonyms': '',
    };
  }

  final occurrences = <Map<String, dynamic>>[];
  final photoUrls = <String>{};
  final countries = <String>[];

  for (final result in results) {
    if (result is! Map<String, dynamic>) continue;

    final occurrence = <String, dynamic>{
      'key': result['key'],
      'scientificName': result['scientificName'],
      'decimalLatitude': result['decimalLatitude'],
      'decimalLongitude': result['decimalLongitude'],
      'country': result['country'],
      'locality': result['locality'],
      'eventDate': result['eventDate'],
    };
    occurrences.add(occurrence);

    final country = result['country'] as String?;
    if (country != null && country.isNotEmpty) {
      countries.add(country);
    }

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

  final synonyms = <String>[];
  final synList = data['synonyms'] as List<dynamic>?;
  if (synList != null) {
    for (final syn in synList) {
      if (syn is String && syn.isNotEmpty) {
        synonyms.add(syn.trim());
      }
    }
  }

  return {
    'occurrences': occurrences,
    'photoUrls': photoUrls.toList(),
    'countries': countries,
    'synonyms': synonyms.join(', '),
  };
}

// ==================== Llifle Entry Point ====================

void _llifleEntryPoint(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final payload = args[1] as Map<String, dynamic>;
  final url = payload['url'] as String;
  final referer = payload['referer'] as String? ?? 'https://llifle.com/';

  final headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Referer': referer,
    'Accept-Language': 'en-US,en;q=0.9',
  };

  try {
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode != 200 || response.body.isEmpty) {
      sendPort.send({
        'success': false,
        'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
      });
      return;
    }

    final document = html_parser.parse(response.body);
    final parsed = _parseLlifleDocument(document);
    final serialized = jsonEncode(parsed);

    sendPort.send({'success': true, 'data': serialized});
  } catch (e, stack) {
    sendPort.send({'success': false, 'error': '$e\n$stack'});
  }
}

Map<String, dynamic> _parseLlifleDocument(dynamic document) {
  final originElement = document.querySelector(
    'p.expandable.Description_Sheet_Origin_and_Habitat',
  );
  String habitat = '';
  String country = '';
  if (originElement != null) {
    habitat = originElement.text.trim();
    const countries = [
      'Mexico', 'United States', 'Argentina', 'Bolivia', 'Chile', 'Peru',
      'Brazil', 'Paraguay', 'Uruguay', 'Colombia', 'Ecuador', 'Venezuela',
      'Spain', 'South Africa', 'Namibia', 'Madagascar', 'Australia',
      'Guatemala', 'Honduras', 'Costa Rica',
    ];
    for (final c in countries) {
      if (habitat.toLowerCase().contains(c.toLowerCase())) {
        country = c;
        break;
      }
    }
  } else {
    // Fallback: попробовать без expandable
    final fallbackElement = document.querySelector(
      'p.Description_Sheet_Origin_and_Habitat',
    );
    if (fallbackElement != null) {
      habitat = fallbackElement.text.trim();
      const countries = [
        'Mexico', 'United States', 'Argentina', 'Bolivia', 'Chile', 'Peru',
        'Brazil', 'Paraguay', 'Uruguay', 'Colombia', 'Ecuador', 'Venezuela',
        'Spain', 'South Africa', 'Namibia', 'Madagascar', 'Australia',
        'Guatemala', 'Honduras', 'Costa Rica',
      ];
      for (final c in countries) {
        if (habitat.toLowerCase().contains(c.toLowerCase())) {
          country = c;
          break;
        }
      }
    }
  }

  final careElement = document.querySelector(
    'p.expandable.Description_Sheet_Cultivation_and_Propagation',
  );
  final careTips = careElement?.text.trim() ?? '';
  
  // Fallback для careTips
  String finalCareTips = careTips;
  if (finalCareTips.isEmpty) {
    final fallbackCareElement = document.querySelector(
      'p.Description_Sheet_Cultivation_and_Propagation',
    );
    finalCareTips = fallbackCareElement?.text.trim() ?? '';
  }

  final descElement = document.querySelector(
    'p.expandable.Description_Sheet_Description',
  );
  final description = descElement?.text.trim() ?? _parseDescription(document);

  final synonymsElement = document.querySelector('#short_synonyms_list ul');
  String synonyms = '';
  if (synonymsElement != null) {
    synonyms = synonymsElement.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // Дополнительные fallback для надежности (как в стабильной версии)
  if (habitat.isEmpty) {
    habitat = _parseHabitat(document);
  }
  if (finalCareTips.isEmpty) {
    finalCareTips = _parseCareTips(document);
  }

  final photoUrls = <String>[];
  final mainPhoto = document.querySelector('#main_photo_container img');
  if (mainPhoto != null && mainPhoto.attributes['src'] != null) {
    var src = mainPhoto.attributes['src']!;
    src = src.startsWith('http') ? src : 'https://llifle.com$src';
    src = src.replaceAll('https://llifle.comphotos/', 'https://llifle.com/photos/');
    src = src.replaceAll('+', '_');
    src = src.replaceAll('_m.jpg', '_l.jpg');
    if (src.contains('llifle.com') && src.endsWith('.jpg')) {
      photoUrls.add(Uri.encodeFull(src));
    }
  }

  final secondaryPhotos = document.querySelectorAll(
    '.secondary_photo_container img.zoom_on_click',
  );
  for (final img in secondaryPhotos) {
    final src = img.attributes['src'];
    if (src != null) {
      var photoUrl = src.startsWith('http') ? src : 'https://llifle.com$src';
      photoUrl = photoUrl.replaceAll('https://llifle.comphotos/', 'https://llifle.com/photos/');
      photoUrl = photoUrl.replaceAll('+', '_');
      photoUrl = photoUrl.replaceAll('_m.jpg', '_l.jpg');
      if (photoUrl.contains('llifle.com') && photoUrl.endsWith('.jpg')) {
        photoUrls.add(Uri.encodeFull(photoUrl));
      }
    }
  }

  final thumbnails = document.querySelectorAll(
    '#thumbnail_container img.thumbnail_photo',
  );
  for (final img in thumbnails) {
    final src = img.attributes['src'];
    if (src != null) {
      var photoUrl = src.startsWith('http') ? src : 'https://llifle.com$src';
      photoUrl = photoUrl.replaceAll('/thumbnails/', '/photos/');
      photoUrl = photoUrl.replaceAll('https://llifle.comphotos/', 'https://llifle.com/photos/');
      photoUrl = photoUrl.replaceAll('+', '_');
      photoUrl = photoUrl.replaceAll('_m.jpg', '_l.jpg');
      if (photoUrl.contains('llifle.com') && photoUrl.endsWith('.jpg')) {
        photoUrls.add(photoUrl); // Без избыточного кодирования
      }
    }
  }

  final albumLinks = document.querySelectorAll(
    '#thumbnail_container a.screenshot',
  );
  for (final link in albumLinks) {
    final rel = link.attributes['rel'];
    if (rel != null && rel.startsWith('/screenshots/')) {
      var photoUrl = 'https://llifle.com$rel';
      photoUrl = photoUrl.replaceAll('https://llifle.comphotos/', 'https://llifle.com/photos/');
      photoUrl = photoUrl.replaceAll('+', '_');
      photoUrl = photoUrl.replaceAll('_m.jpg', '_l.jpg');
      if (photoUrl.contains('llifle.com') && photoUrl.endsWith('.jpg')) {
        photoUrls.add(photoUrl); // Без избыточного кодирования
      }
    }
  }

  return {
    'habitat': habitat,
    'country': country,
    'careTips': finalCareTips,
    'description': description,
    'synonyms': synonyms,
    'photoUrls': photoUrls,
  };
}

String _parseDescription(dynamic document) {
  try {
    final element = document.querySelector('p.Description_Sheet_Description');
    if (element != null) {
      return element.text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
    return '';
  } catch (e) {
    return '';
  }
}

String _parseHabitat(dynamic document) {
  try {
    final element = document.querySelector('p.Description_Sheet_Origin_and_Habitat');
    if (element != null) {
      return element.text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
    return '';
  } catch (e) {
    return '';
  }
}

String _parseCareTips(dynamic document) {
  try {
    final element = document.querySelector('p.Description_Sheet_Cultivation_and_Propagation');
    if (element != null) {
      return element.text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
    return '';
  } catch (e) {
    return '';
  }
}

// ==================== Exceptions ====================

class HttpIsolateException implements Exception {
  HttpIsolateException(this.message);
  final String message;

  @override
  String toString() => 'HttpIsolateException: $message';
}
