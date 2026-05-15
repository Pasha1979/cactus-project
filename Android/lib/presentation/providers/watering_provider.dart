import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_constants.dart';
import '../../core/logger/app_logger.dart';
import '../../core/ui/ui_state.dart';
import '../../models/plant.dart';

/// Провайдер для управления поливами
///
/// Отвечает за:
/// - Глобальные даты полива
/// - Индивидуальные даты полива растений
/// - Рекомендации по поливу
/// - Уведомления о поливе
class WateringProvider with ChangeNotifier {
  List<DateTime> _globalWateringDates = [];
  UiState<List<DateTime>> _uiState = const UiLoading();

  /// Загрузка globalWateringDates из SharedPreferences
  Future<void> load() async {
    _uiState = const UiLoading();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final datesJson = prefs.getStringList(PrefsKeys.globalWateringDates);
      if (datesJson != null) {
        _globalWateringDates = datesJson
            .map((s) => DateTime.tryParse(s))
            .whereType<DateTime>()
            .toList();
      } else {
        _globalWateringDates = [];
      }
      _uiState = UiSuccess(List.unmodifiable(_globalWateringDates));
      notifyListeners();
      AppLogger.api('✅ WateringProvider loaded: ${_globalWateringDates.length} dates', tag: 'WATERING');
    } catch (e) {
      AppLogger.error('❌ WateringProvider load error: $e', tag: 'WATERING');
      _globalWateringDates = [];
      _uiState = UiError(
        'Ошибка загрузки данных полива: $e',
        onRetry: load,
      );
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        PrefsKeys.globalWateringDates,
        _globalWateringDates.map((d) => d.toIso8601String()).toList(),
      );
    } catch (e) {
      AppLogger.error('❌ WateringProvider save error: $e', tag: 'WATERING');
    }
  }

  // ==================== ГЕТТЕРЫ ====================
  List<DateTime> get globalWateringDates => List.unmodifiable(_globalWateringDates);
  UiState<List<DateTime>> get uiState => _uiState;

  DateTime? get lastGlobalWateringDate {
    if (_globalWateringDates.isEmpty) return null;
    return _globalWateringDates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String get lastGlobalWateringText {
    final lastDate = lastGlobalWateringDate;
    if (lastDate == null) return 'Не поливалась вся коллекция';
    final daysAgo = DateTime.now().difference(lastDate).inDays;
    if (daysAgo == 0) return 'Полита вся коллекция сегодня';
    if (daysAgo == 1) return 'Полита вся коллекция вчера';
    if (daysAgo < 7) return 'Полита вся коллекция $daysAgo дней назад';
    final weeksAgo = (daysAgo / 7).floor();
    return 'Полита вся коллекция $weeksAgo недель назад';
  }

  // ==================== ГЛОБАЛЬНЫЕ ПОЛИВЫ ====================
  Future<void> addGlobalWateringDate(DateTime date) async {
    _globalWateringDates.add(date);
    await _save();
    _uiState = UiSuccess(List.unmodifiable(_globalWateringDates));
    notifyListeners();
  }

  Future<void> removeGlobalWateringDate(DateTime date) async {
    _globalWateringDates.removeWhere((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day,);
    await _save();
    _uiState = UiSuccess(List.unmodifiable(_globalWateringDates));
    notifyListeners();
  }

  // ==================== ИНДИВИДУАЛЬНЫЕ ПОЛИВЫ ====================
  /// Возвращает Plant с добавленной датой полива.
  /// Вызывающий код должен сохранить через PlantCrudProvider.updatePlant().
  Plant addIndividualWateringDate(Plant plant, DateTime date) {
    return plant.copyWith(
      wateringDates: [...plant.wateringDates, date],
    );
  }

  /// Возвращает Plant с удалённой датой полива.
  /// Вызывающий код должен сохранить через PlantCrudProvider.updatePlant().
  Plant removeIndividualWateringDate(Plant plant, DateTime date) {
    final updatedDates = plant.wateringDates
        .where((d) => d.year != date.year || d.month != date.month || d.day != date.day)
        .toList();
    return plant.copyWith(wateringDates: updatedDates);
  }

  // ==================== РЕКОМЕНДАЦИИ ====================
  DateTime? getNextWateringDate(DateTime? lastWatering) {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    final latest = lastWatering ?? lastGlobalWateringDate ?? now;

    if (month == 3 && day < 15) return DateTime(now.year, 3, 15);
    if (month >= 3 && month <= 4) return latest.add(const Duration(days: 14));
    if (month >= 5 && month <= 8) return latest.add(const Duration(days: 7));
    if (month == 9) return latest.add(const Duration(days: 10));
    if (month == 10) return latest.add(const Duration(days: 20));
    if (month == 11 && day <= 5) return DateTime(now.year, 11, 5);
    if (month >= 11 || month <= 2 || (month == 3 && day < 15)) {
      return DateTime(now.year + (month >= 11 ? 1 : 0), 3, 15);
    }
    return latest.add(const Duration(days: 7));
  }

  List<DateTime> getRecommendedWateringDates(DateTime? lastWatering) {
    final now = DateTime.now();
    final dates = <DateTime>[];
    DateTime current = lastWatering ?? lastGlobalWateringDate ?? now;

    for (int i = 0; i < 12; i++) {
      final next = getNextWateringDate(current);
      if (next == null || next.isBefore(now)) break;
      dates.add(next);
      current = next;
    }
    return dates;
  }

}
