import 'package:hive_flutter/hive_flutter.dart';

/// Хранилище состояния синхронизации (Hive-бокс 'sync_state', Box<String>).
///
/// Курсоры и штампы — ТОЛЬКО серверные значения (R-046):
/// - 'pull_cursor' — ISO-строка last_modified последней полученной строки;
/// - 'stamp:<permanentId>' — серверный last_modified записи на момент
///   последнего push/pull (база для LWW при конфликте).
class SyncStateStore {
  SyncStateStore(this._box);

  static const String _pullCursorKey = 'pull_cursor';
  static const String _settingsCursorKey = 'settings_cursor';
  static const String _stampPrefix = 'stamp:';

  final Box<String> _box;

  /// Локальный курсор pull (серверное время); null → тянуть всё.
  DateTime? get pullCursor {
    final raw = _box.get(_pullCursorKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setPullCursor(DateTime cursor) =>
      _box.put(_pullCursorKey, cursor.toIso8601String());

  /// Отдельный курсор для user_settings (серверное время).
  DateTime? get settingsCursor {
    final raw = _box.get(_settingsCursorKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setSettingsCursor(DateTime cursor) =>
      _box.put(_settingsCursorKey, cursor.toIso8601String());

  /// Серверный штамп записи (null — запись ещё не синхронизировалась).
  DateTime? stampFor(String permanentId) {
    final raw = _box.get('$_stampPrefix$permanentId');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setStamp(String permanentId, DateTime serverStamp) =>
      _box.put('$_stampPrefix$permanentId', serverStamp.toIso8601String());

  Future<void> removeStamp(String permanentId) =>
      _box.delete('$_stampPrefix$permanentId');
}
