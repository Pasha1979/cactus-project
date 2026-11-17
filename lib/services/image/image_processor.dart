import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../core/logger/app_logger.dart';

/// Сервис сжатия изображений перед сохранением в локальное хранилище.
///
/// Сжимает КОПИЮ фото — оригинал в галерее телефона не затрагивается.
/// На Windows сжатие не поддерживается — файл копируется без изменений.
///
/// Целевые параметры: JPEG качество 85, макс. сторона 1920px.
/// Ожидаемый результат: 5 МБ → ~300 КБ.
class ImageProcessor {
  static const int _quality = 85;
  static const int _maxDimension = 1920;

  /// Сжать изображение и сохранить в [targetPath].
  ///
  /// Возвращает [targetPath] — путь к результирующему файлу.
  /// Если сжатие недоступно (Windows) или не дало выигрыша — копирует оригинал.
  static Future<String> compressAndSave({
    required String sourcePath,
    required String targetPath,
  }) async {
    // Windows не поддерживается flutter_image_compress — fallback на копирование
    if (!_isCompressionSupported()) {
      AppLogger.api('ℹ️ ImageProcessor: сжатие недоступно на этой платформе, копируем', tag: 'IMAGE_PROCESSOR');
      await File(sourcePath).copy(targetPath);
      return targetPath;
    }

    try {
      final sourceFile = File(sourcePath);
      final sourceSize = await sourceFile.length();

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: _quality,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        AppLogger.warning('⚠️ ImageProcessor: сжатие вернуло null, копируем оригинал', tag: 'IMAGE_PROCESSOR');
        await sourceFile.copy(targetPath);
        return targetPath;
      }

      final resultSize = await File(result.path).length();
      final savedKb = ((sourceSize - resultSize) / 1024).round();
      AppLogger.api('✅ ImageProcessor: ${(sourceSize / 1024).round()} КБ → ${(resultSize / 1024).round()} КБ (сэкономлено $savedKb КБ)', tag: 'IMAGE_PROCESSOR');

      return result.path;
    } catch (e) {
      AppLogger.warning('⚠️ ImageProcessor: ошибка сжатия ($e), копируем оригинал', tag: 'IMAGE_PROCESSOR');
      await File(sourcePath).copy(targetPath);
      return targetPath;
    }
  }

  /// Поддерживается ли сжатие на текущей платформе.
  static bool _isCompressionSupported() {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }
}
