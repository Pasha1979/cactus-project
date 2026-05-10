import 'package:hive/hive.dart';
import '../../../data/models/gbif_occurrence_dto.dart';

/// Локальный источник данных для GBIF кэша (Hive)
class GbifCacheLocalDataSource {
  final Box<GbifOccurrenceDto> _gbifBox;

  GbifCacheLocalDataSource(this._gbifBox);

  /// Получить все записи
  Future<List<GbifOccurrenceDto>> getAllOccurrences() async {
    return _gbifBox.values.toList();
  }

  /// Получить запись по ID
  Future<GbifOccurrenceDto?> getOccurrenceById(String id) async {
    return _gbifBox.get(id);
  }

  /// Сохранить запись
  Future<void> saveOccurrence(String id, GbifOccurrenceDto occurrence) async {
    await _gbifBox.put(id, occurrence);
  }

  /// Удалить запись
  Future<void> deleteOccurrence(String id) async {
    await _gbifBox.delete(id);
  }

  /// Очистить все данные
  Future<void> clearAll() async {
    await _gbifBox.clear();
  }
}
