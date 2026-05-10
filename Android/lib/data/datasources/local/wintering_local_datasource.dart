import 'package:hive/hive.dart';
import '../../../data/models/wintering_log_entry_dto.dart';

/// Локальный источник данных для зимовки (Hive)
class WinteringLocalDataSource {
  final Box<WinteringLogEntryDto> _winteringBox;

  WinteringLocalDataSource(this._winteringBox);

  /// Получить все записи зимовки
  Future<List<WinteringLogEntryDto>> getAllEntries() async {
    return _winteringBox.values.toList();
  }

  /// Получить запись по ID
  Future<WinteringLogEntryDto?> getEntryById(String id) async {
    return _winteringBox.get(id);
  }

  /// Сохранить запись зимовки
  Future<void> saveEntry(WinteringLogEntryDto entry) async {
    final key = entry.date.millisecondsSinceEpoch.toString();
    await _winteringBox.put(key, entry);
  }

  /// Удалить запись зимовки
  Future<void> deleteEntry(String id) async {
    await _winteringBox.delete(id);
  }

  /// Очистить все данные
  Future<void> clearAll() async {
    await _winteringBox.clear();
  }
}
