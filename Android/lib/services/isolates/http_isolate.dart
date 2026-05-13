import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

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
          debugPrint('[HttpIsolate] Completed in ${sw.elapsedMilliseconds}ms');
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
      debugPrint('[HttpIsolate] Failed after ${sw.elapsedMilliseconds}ms: $e');
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
  }

  final careElement = document.querySelector(
    'p.expandable.Description_Sheet_Cultivation_and_Propagation',
  );
  final careTips = careElement?.text.trim() ?? '';

  final descElement = document.querySelector(
    'p.expandable.Description_Sheet_Description',
  );
  final description = descElement?.text.trim() ?? '';

  final synonymsElement = document.querySelector('#short_synonyms_list ul');
  String synonyms = '';
  if (synonymsElement != null) {
    synonyms = synonymsElement.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  final photoUrls = <String>[];
  final mainPhoto = document.querySelector('#main_photo_container img');
  if (mainPhoto != null && mainPhoto.attributes['src'] != null) {
    photoUrls.add(mainPhoto.attributes['src']!);
  }

  final secondaryPhotos = document.querySelectorAll(
    '.secondary_photo_container img.zoom_on_click',
  );
  for (final img in secondaryPhotos) {
    final src = img.attributes['src'];
    if (src != null) photoUrls.add(src);
  }

  final thumbnails = document.querySelectorAll(
    '#thumbnail_container img.thumbnail_photo',
  );
  for (final img in thumbnails) {
    final src = img.attributes['src'];
    if (src != null) photoUrls.add(src);
  }

  final albumLinks = document.querySelectorAll(
    '#thumbnail_container a.screenshot',
  );
  for (final link in albumLinks) {
    final rel = link.attributes['rel'];
    if (rel != null && rel.startsWith('/screenshots/')) {
      photoUrls.add(rel);
    }
  }

  return {
    'habitat': habitat,
    'country': country,
    'careTips': careTips,
    'description': description,
    'synonyms': synonyms,
    'photoUrls': photoUrls,
  };
}

// ==================== Exceptions ====================

class HttpIsolateException implements Exception {
  final String message;
  HttpIsolateException(this.message);

  @override
  String toString() => 'HttpIsolateException: $message';
}
