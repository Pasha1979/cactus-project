import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Централизованный кэш-менеджер для сетевых фото (GBIF, llifle, adult images).
///
/// Использует flutter_cache_manager (транзитивная зависимость от cached_network_image).
/// Лимит: 200 файлов, stale period: 30 дней.
class PhotoCacheManager {
  static const String _key = 'photo_cache';
  static const Duration _stalePeriod = Duration(days: 30);
  static const int _maxObjects = 200;

  static final CacheManager _instance = CacheManager(
    Config(
      _key,
      stalePeriod: _stalePeriod,
      maxNrOfCacheObjects: _maxObjects,
    ),
  );

  /// Получить закэшированный файл по URL.
  /// Возвращает null если файл ещё не в кэше.
  static Future<File?> getCachedFile(String url) async {
    final fileInfo = await _instance.getFileFromCache(url);
    return fileInfo?.file;
  }

  /// Скачать и закэшировать файл по URL.
  static Future<File> cacheFile(String url) async {
    final fileInfo = await _instance.downloadFile(url);
    return fileInfo.file;
  }

  /// Фоновая загрузка (prefetch) нескольких URL.
  /// Ошибки отдельных URL игнорируются.
  static Future<void> prefetch(List<String> urls) async {
    for (final url in urls) {
      try {
        await _instance.downloadFile(url);
      } catch (e) {
        debugPrint('Prefetch error for $url: $e');
      }
    }
  }

  /// Очистить весь кэш фото.
  static Future<void> clearCache() async {
    await _instance.emptyCache();
  }
}
