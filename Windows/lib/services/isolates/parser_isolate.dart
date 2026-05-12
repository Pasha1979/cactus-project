import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Isolate для парсинга тяжёлого контента (HTML, JSON).
///
/// Переносит CPU-bound операции из main thread:
/// - Парсинг Llifle HTML (DOM tree construction + CSS queries)
/// - Парсинг GBIF JSON (jsonDecode + object extraction)
///
/// HTTP-запросы и SharedPreferences остаются в main thread.
///
/// Вариант А (консервативный): только парсинг в isolate.
/// Вариант Б (расширенный): HTTP + парсинг + сериализация в isolate.
///   Запланирован после успешного тестирования Варианта А.
class ParserIsolate {
  static const Duration _timeout = Duration(seconds: 5);

  /// Парсит Llifle HTML и возвращает структурированные данные.
  static Future<Map<String, dynamic>> parseHtml(String html) async {
    return _runInIsolate(_llifleEntryPoint, html);
  }

  /// Парсит GBIF JSON и возвращает структурированные данные.
  static Future<Map<String, dynamic>> parseJson(String json) async {
    return _runInIsolate(_gbifEntryPoint, json);
  }

  static Future<Map<String, dynamic>> _runInIsolate(
    void Function(List<dynamic>) entryPoint,
    String payload,
  ) async {
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
          throw ParserIsolateException(
            'Isolate parsing timeout after $_timeout',
          );
        },
      );

      if (result is Map<String, dynamic>) {
        if (result['success'] == true) {
          return result['data'] as Map<String, dynamic>;
        } else {
          throw ParserIsolateException(
            result['error']?.toString() ?? 'Unknown isolate error',
          );
        }
      } else {
        throw ParserIsolateException('Invalid isolate response format');
      }
    } finally {
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }
}

// ==================== Llifle HTML Parsing ====================

void _llifleEntryPoint(List<dynamic> args) {
  final sendPort = args[0] as SendPort;
  final html = args[1] as String;

  try {
    final document = html_parser.parse(html);
    final data = _parseLlifleDocument(document);
    sendPort.send({'success': true, 'data': data});
  } catch (e, stack) {
    sendPort.send({'success': false, 'error': '$e\n$stack'});
  }
}

Map<String, dynamic> _parseLlifleDocument(Document document) {
  // Habitat и country
  final originElement = document.querySelector(
    'p.expandable.Description_Sheet_Origin_and_Habitat',
  );
  String habitat = '';
  String country = '';
  if (originElement != null) {
    habitat = originElement.text.trim();
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
      'Costa Rica',
    };
    for (final c in countries) {
      if (habitat.toLowerCase().contains(c.toLowerCase())) {
        country = c;
        break;
      }
    }
  }

  // CareTips
  final careElement = document.querySelector(
    'p.expandable.Description_Sheet_Cultivation_and_Propagation',
  );
  final careTips = careElement?.text.trim() ?? '';

  // Description
  final descElement = document.querySelector(
    'p.expandable.Description_Sheet_Description',
  );
  final description = descElement?.text.trim() ?? '';

  // Synonyms
  final synonymsElement = document.querySelector('#short_synonyms_list ul');
  String synonyms = '';
  if (synonymsElement != null) {
    synonyms = synonymsElement.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // Photos — сырые URL (обработка — в main thread)
  final photoUrls = <String>[];

  // Main photo
  final mainPhoto = document.querySelector('#main_photo_container img');
  if (mainPhoto != null && mainPhoto.attributes['src'] != null) {
    photoUrls.add(mainPhoto.attributes['src']!);
  }

  // Secondary photos
  final secondaryPhotos = document.querySelectorAll(
    '.secondary_photo_container img.zoom_on_click',
  );
  for (final img in secondaryPhotos) {
    final src = img.attributes['src'];
    if (src != null) photoUrls.add(src);
  }

  // Thumbnails
  final thumbnails = document.querySelectorAll(
    '#thumbnail_container img.thumbnail_photo',
  );
  for (final img in thumbnails) {
    final src = img.attributes['src'];
    if (src != null) photoUrls.add(src);
  }

  // Albums
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

// ==================== GBIF JSON Parsing ====================

void _gbifEntryPoint(List<dynamic> args) {
  final sendPort = args[0] as SendPort;
  final json = args[1] as String;

  try {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final result = _parseGbifData(data);
    sendPort.send({'success': true, 'data': result});
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

    // Extract occurrence as Map (lightweight, serializable)
    final occurrence = <String, dynamic>{};
    occurrence['key'] = result['key'];
    occurrence['scientificName'] = result['scientificName'];
    occurrence['decimalLatitude'] = result['decimalLatitude'];
    occurrence['decimalLongitude'] = result['decimalLongitude'];
    occurrence['country'] = result['country'];
    occurrence['locality'] = result['locality'];
    occurrence['eventDate'] = result['eventDate'];
    occurrences.add(occurrence);

    final country = result['country'] as String?;
    if (country != null && country.isNotEmpty) {
      countries.add(country);
    }

    // Photos
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

  // Synonyms
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

  return {
    'occurrences': occurrences,
    'photoUrls': photoUrls.toList(),
    'countries': countries,
    'synonyms': synonyms.join(', '),
  };
}

// ==================== Exceptions ====================

class ParserIsolateException implements Exception {
  final String message;
  ParserIsolateException(this.message);

  @override
  String toString() => 'ParserIsolateException: $message';
}
