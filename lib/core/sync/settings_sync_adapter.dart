import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';

/// Адаптер legacy-настроек SharedPreferences ↔ user_settings (задача 2.4б).
///
/// Синхронизируются 6 ключей; searchHistory/scanHistory и прочие prefs
/// остаются локальными намеренно (R-047).
class SettingsSyncAdapter {
  SettingsSyncAdapter(this._prefs);

  static const String prefix = 'settings:';

  /// Ключи SharedPreferences, участвующие в синхронизации.
  static const List<String> syncedKeys = [
    PrefsKeys.globalWateringDates,
    PrefsKeys.winteringStart,
    PrefsKeys.winteringEnd,
    PrefsKeys.winteringTemp,
    PrefsKeys.winteringLog,
    PrefsKeys.adultImages,
  ];

  static bool isSettingId(String recordId) => recordId.startsWith(prefix);
  static String settingKey(String recordId) => recordId.substring(prefix.length);

  final SharedPreferences _prefs;

  /// Значение ключа как JSON (null — ключ отсутствует локально).
  dynamic readLegacy(String key) {
    switch (key) {
      case PrefsKeys.globalWateringDates:
      case PrefsKeys.winteringLog:
        return _prefs.getStringList(key);
      case PrefsKeys.winteringTemp:
        return _prefs.getDouble(key);
      case PrefsKeys.adultImages:
        final raw = _prefs.getString(key);
        return raw == null ? null : jsonDecode(raw);
      case PrefsKeys.winteringStart:
      case PrefsKeys.winteringEnd:
        final raw = _prefs.getString(key);
        return (raw == null || raw.isEmpty) ? null : raw;
      default:
        return null;
    }
  }

  /// Записать удалённое значение в prefs. Pull вызывает это напрямую —
  /// провайдеры потом перечитывают prefs через onPullComplete (петли нет:
  /// writeLegacy не идёт через _save-хуки).
  Future<void> writeLegacy(String key, dynamic value) async {
    switch (key) {
      case PrefsKeys.globalWateringDates:
      case PrefsKeys.winteringLog:
        await _prefs.setStringList(key, List<String>.from(value ?? const []));
      case PrefsKeys.winteringTemp:
        if (value == null) {
          await _prefs.remove(key);
        } else {
          await _prefs.setDouble(key, (value as num).toDouble());
        }
      case PrefsKeys.adultImages:
        await _prefs.setString(key, jsonEncode(value ?? {}));
      case PrefsKeys.winteringStart:
      case PrefsKeys.winteringEnd:
        await _prefs.setString(key, value?.toString() ?? '');
    }
  }

  /// Удалить ключ (tombstone с сервера).
  Future<void> removeLegacy(String key) => _prefs.remove(key);

  /// Строка для upsert в user_settings. last_modified НЕ отправляется —
  /// его ставит серверный триггер (миграция 00003, R-045).
  Map<String, dynamic> toRow(String key, String userId) => {
        'user_id': userId,
        'key': key,
        'value': readLegacy(key),
      };
}
