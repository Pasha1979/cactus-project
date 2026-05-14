import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../core/logger/app_logger.dart';
import '../data/datasources/local/plant_local_datasource.dart';

/// Сервис для экспорта данных приложения.
///
/// Поддерживает форматы: JSON, CSV
/// Использует file_picker для выбора пути сохранения.
class DataExportService {
  DataExportService(this._plantDataSource);

  static const String _tag = 'EXPORT';

  final PlantLocalDataSource _plantDataSource;

  /// Экспортирует все данные в JSON формат.
  ///
  /// Возвращает путь к созданному файлу или null при ошибке.
  Future<String?> exportToJson() async {
    try {
      AppLogger.api('Начало экспорта в JSON', tag: _tag);

      // Получаем данные из Hive
      final plants = await _plantDataSource.getAllPlants();

      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'plants': plants.map((p) => _plantToJson(p)).toList(),
      };

      // Выбираем путь для сохранения
      final outputPath = await _pickSaveLocation(
        suggestedName: 'cactus_backup_${_formatDateTime(DateTime.now())}.json',
      );

      if (outputPath == null) {
        AppLogger.api('Экспорт отменен пользователем', tag: _tag);
        return null;
      }

      // Записываем файл
      final file = File(outputPath);
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      await file.writeAsString(jsonString);

      AppLogger.api('Экспорт в JSON завершен: $outputPath', tag: _tag);
      return outputPath;
    } catch (e, stack) {
      AppLogger.error('Ошибка экспорта в JSON', tag: _tag, error: e, stackTrace: stack);
      return null;
    }
  }

  /// Экспортирует данные в CSV формат (только растения).
  ///
  /// Возвращает путь к созданному файлу или null при ошибке.
  Future<String?> exportToCsv() async {
    try {
      AppLogger.api('Начало экспорта в CSV', tag: _tag);

      // Получаем данные растений
      final plants = await _plantDataSource.getAllPlants();

      if (plants.isEmpty) {
        AppLogger.warning('Нет данных для экспорта', tag: _tag);
        return null;
      }

      // Формируем CSV
      final csvBuffer = StringBuffer();

      // Заголовки
      final headers = [
        'ID',
        'Латинское название',
        'Страна происхождения',
        'Статус',
        'Год',
        'Категория',
        'Количество семян',
        'Пророщено',
        'Заметки',
      ];
      csvBuffer.writeln(headers.join(','));

      // Данные
      for (final plant in plants) {
        final row = [
          '"${plant.permanentId}"',
          '"${plant.latinName}"',
          '"${plant.country ?? ''}"',
          '"${plant.status}"',
          '"${plant.year}"',
          '"${plant.category}"',
          '"${plant.seedsCount}"',
          '"${plant.germinatedCount}"',
  '"${plant.notesJson.join('; ').replaceAll('"', '""')}"',
        ];
        csvBuffer.writeln(row.join(','));
      }

      // Выбираем путь для сохранения
      final outputPath = await _pickSaveLocation(
        suggestedName: 'cactus_export_${_formatDateTime(DateTime.now())}.csv',
      );

      if (outputPath == null) {
        AppLogger.api('Экспорт отменен пользователем', tag: _tag);
        return null;
      }

      // Записываем файл
      final file = File(outputPath);
      await file.writeAsString(csvBuffer.toString(), encoding: utf8);

      AppLogger.api('Экспорт в CSV завершен: $outputPath', tag: _tag);
      return outputPath;
    } catch (e, stack) {
      AppLogger.error('Ошибка экспорта в CSV', tag: _tag, error: e, stackTrace: stack);
      return null;
    }
  }

  /// Открывает диалог выбора пути для сохранения файла.
  Future<String?> _pickSaveLocation({required String suggestedName}) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить резервную копию',
        fileName: suggestedName,
        type: FileType.any,
      );
      return result;
    } catch (e, stack) {
      AppLogger.error('Ошибка выбора пути', tag: _tag, error: e, stackTrace: stack);
      return null;
    }
  }

  /// Форматирует DateTime для имени файла.
  String _formatDateTime(DateTime dt) {
    return '${dt.year}${_twoDigits(dt.month)}${_twoDigits(dt.day)}_'
        '${_twoDigits(dt.hour)}${_twoDigits(dt.minute)}';
  }

  /// Конвертирует PlantDto в JSON Map.
  Map<String, dynamic> _plantToJson(dynamic plant) {
    return {
      'permanentId': plant.permanentId,
      'displayId': plant.displayId,
      'latinName': plant.latinName,
      'status': plant.status,
      'year': plant.year,
      'category': plant.category,
      'seedsCount': plant.seedsCount,
      'germinatedCount': plant.germinatedCount,
      'country': plant.country,
      'notesJson': plant.notesJson,
    };
  }

  String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
}
