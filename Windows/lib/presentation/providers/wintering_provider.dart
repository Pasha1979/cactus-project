import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_constants.dart';

/// Запись журнала зимовки
class WinteringLogEntry {
  final DateTime date;
  final String description;

  WinteringLogEntry({required this.date, required this.description});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'description': description,
      };

  factory WinteringLogEntry.fromJson(Map<String, dynamic> json) {
    return WinteringLogEntry(
      date: DateTime.tryParse(json['date']) ?? DateTime(1970, 1, 1),
      description: json['description'],
    );
  }
}

/// Провайдер для управления зимовкой
///
/// Отвечает за:
/// - Даты начала/окончания зимовки
/// - Температуру зимовки
/// - Журнал записей зимовки
class WinteringProvider with ChangeNotifier {
  DateTime? _startDate;
  DateTime? _endDate;
  double? _temperature;
  List<WinteringLogEntry> _logEntries = [];

  /// Загрузка настроек зимовки из SharedPreferences
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final ws = prefs.getString(PrefsKeys.winteringStart);
      _startDate = ws != null && ws.isNotEmpty ? DateTime.tryParse(ws) : null;

      final we = prefs.getString(PrefsKeys.winteringEnd);
      _endDate = we != null && we.isNotEmpty ? DateTime.tryParse(we) : null;

      _temperature = prefs.getDouble(PrefsKeys.winteringTemp);

      final wlJson = prefs.getStringList(PrefsKeys.winteringLog);
      if (wlJson != null) {
        _logEntries = wlJson
            .map((s) {
              try {
                return WinteringLogEntry.fromJson(
                    jsonDecode(s) as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<WinteringLogEntry>()
            .toList();
      } else {
        _logEntries = [];
      }

      notifyListeners();
      debugPrint('✅ WinteringProvider loaded: '
          'start=$_startDate, end=$_endDate, temp=$_temperature, logs=${_logEntries.length}');
    } catch (e) {
      debugPrint('❌ WinteringProvider load error: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        PrefsKeys.winteringStart,
        _startDate?.toIso8601String() ?? '',
      );
      await prefs.setString(
        PrefsKeys.winteringEnd,
        _endDate?.toIso8601String() ?? '',
      );
      if (_temperature != null) {
        await prefs.setDouble(PrefsKeys.winteringTemp, _temperature!);
      } else {
        await prefs.remove(PrefsKeys.winteringTemp);
      }
      await prefs.setStringList(
        PrefsKeys.winteringLog,
        _logEntries.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('❌ WinteringProvider save error: $e');
    }
  }

  // ==================== ГЕТТЕРЫ ====================
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  DateTime? get winteringStartDate => _startDate;
  DateTime? get winteringEndDate => _endDate;
  double? get temperature => _temperature;
  double? get winteringTemperature => _temperature;
  List<WinteringLogEntry> get logEntries => List.unmodifiable(_logEntries);
  List<WinteringLogEntry> get winteringLogEntries => List.unmodifiable(_logEntries);

  // ==================== СЕТТЕРЫ ====================
  set startDate(DateTime? value) {
    _startDate = value;
    _save();
    notifyListeners();
  }

  set endDate(DateTime? value) {
    _endDate = value;
    _save();
    notifyListeners();
  }

  set temperature(double? value) {
    _temperature = value;
    _save();
    notifyListeners();
  }

  set winteringTemperature(double? value) => temperature = value;
  set winteringStartDate(DateTime? value) => startDate = value;
  set winteringEndDate(DateTime? value) => endDate = value;

  // ==================== ЖУРНАЛ ====================
  void addLogEntry(WinteringLogEntry entry) {
    _logEntries.add(entry);
    _save();
    notifyListeners();
  }

  /// Алиас для совместимости с wintering_screen
  void addWinteringLogEntry(WinteringLogEntry entry) => addLogEntry(entry);

  /// Загрузка настроек (алиас для совместимости).
  ///
  /// В новой архитектуре используйте [load] в main.dart.
  Future<Map<String, dynamic>> loadSettings() async {
    await load();
    return {
      'startDate': _startDate?.toIso8601String(),
      'endDate': _endDate?.toIso8601String(),
      'temperature': _temperature,
      'entries': _logEntries.map((e) => e.toJson()).toList(),
    };
  }
}
