import 'package:flutter/material.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plant.dart';
import '../utils/gbif_utils.dart';
import 'dart:convert' show jsonDecode, jsonEncode, utf8, latin1;
import 'package:file_picker/file_picker.dart';
// import 'package:provider/provider.dart';          // ← закомментировали, потому что не используется напрямую
// import '../providers/cloud_storage_provider.dart'; // закомментировали, потому что используется только через Provider.of в других местах
import '../main.dart'; // Импорт main.dart для доступа к navigatorKey
import 'package:collection/collection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path; // Добавьте импорт пакета path
import 'package:html/parser.dart' show parse;
// Новый импорт: Для интеграции погоды в провайдер (Вариант 3). Меняет: Добавляет доступ к WeatherService — теперь провайдер может получать координаты/советы/уведомления. Не удаляет: Твои импорты (uuid, shared_preferences, plant.dart) — все работают как раньше. Функциональность: Кросс-платформенный (geolocator в service, no conflicts с твоим loadPlants/savePlants). Проверено: Нет дубликатов, синтаксис OK (relative path из providers/ к utils/).
import '../utils/weather_service.dart';
// Новый импорт: Для классов уведомлений (AndroidNotificationDetails, NotificationDetails, Importance, Priority и т.д.) в методах sendWeatherNotification/scheduleDailyWeatherCheck (Вариант 3). Меняет: Разрешает Dart распознавать эти классы — убирает ошибки "undefined class/method" (строки 1142–1148, 1163). Не удаляет: Твои импорты (weather_service, uuid, shared_preferences) — все работают как раньше. Функциональность: Кросс-платформенный (Windows — трей, без конфликтов с твоим Plant model или savePlants). Проверено: Нет дубликатов (импорт уже в main.dart, но нужен локально), синтаксис OK (package direct).
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Новый импорт: Для tz.TZDateTime в scheduleDailyWeatherCheck (планировщик ежедневных уведомлений, Вариант 3). Меняет: Разрешает Dart распознавать tz — убирает ошибки "undefined identifier 'tz'" (строки 1162). Не удаляет: Твои импорты — все intact. Функциональность: Позволяет планировать на локальное время (e.g., 8:00 MSK 01.10.2025), без конфликтов с твоим DateTime.now() в _getSeasonalTip. Проверено: Alias 'as tz' OK (no name conflicts), синтаксис чистый (package из pubspec ^0.9.2).
import 'package:timezone/timezone.dart' as tz;
// Новый импорт для скачивания фото из облака в ensureLocalPhotosExist
import 'package:http/http.dart' as http;

class PlantProvider with ChangeNotifier {
  List<Plant> _plants = [];
  bool _hasUnsavedChanges = false;
  final Set<String> _selectedIds = {};
  // === НОВОЕ: Флаг для отложенной синхронизации фото ===
  bool _needsPhotoSync = false;
  
  // === ЗАЩИТА ОТ RACE CONDITIONS ===
  bool _isEnsuringPhotos = false;
  
  // === ОТСЛЕЖИВАНИЕ УДАЛЕННЫХ ФОТО ===
  final Set<String> _deletedUserPhotos = {};      // Удаленные свои фото
  final Set<String> _deletedLliflePhotos = {};    // Удаленные Llifle фото
  
  static const String _prefsKey = 'plants';
  static const String _globalWateringKey = 'global_watering_dates';
  List<DateTime> _globalWateringDates = [];
  Map<String, String?> _adultImages = {};
  DateTime? _lastLocalUpdate; //
  DateTime? _winteringStartDate;
  DateTime? _winteringEndDate;
  double? _winteringTemperature;
  List<WinteringLogEntry> _winteringLogEntries = [];

  // Геттеры и сеттеры для данных о зимовке
  DateTime? get winteringStartDate => _winteringStartDate;
  set winteringStartDate(DateTime? value) {
    _winteringStartDate = value;
    _hasUnsavedChanges = true;
    notifyListeners();
    savePlants();
  }

  DateTime? get winteringEndDate => _winteringEndDate;
  set winteringEndDate(DateTime? value) {
    _winteringEndDate = value;
    _hasUnsavedChanges = true;
    notifyListeners();
    savePlants();
  }

  double? get winteringTemperature => _winteringTemperature;
  set winteringTemperature(double? value) {
    _winteringTemperature = value;
    _hasUnsavedChanges = true;
    notifyListeners();
    savePlants();
  }

  List<WinteringLogEntry> get winteringLogEntries => _winteringLogEntries;
  set winteringLogEntries(List<WinteringLogEntry> value) {
    _winteringLogEntries = value;
    _hasUnsavedChanges = true;
    notifyListeners();
    savePlants();
  }

  // Метод для добавления записи в журнал
  void addWinteringLogEntry(WinteringLogEntry entry) {
    _winteringLogEntries.add(entry);
    _hasUnsavedChanges = true;
    notifyListeners();
    savePlants();
  }

  // === ГЕТТЕРЫ И МЕТОДЫ ДЛЯ УДАЛЕННЫХ ФОТО ===
  Set<String> get deletedUserPhotos => _deletedUserPhotos;
  Set<String> get deletedLliflePhotos => _deletedLliflePhotos;
  
  void markUserPhotoAsDeleted(String photoUrl) {
    _deletedUserPhotos.add(photoUrl);
    markNeedsPhotoSync();
  }
  
  void markLliflePhotoAsDeleted(String photoUrl) {
    _deletedLliflePhotos.add(photoUrl);
    markNeedsPhotoSync();
  }
  
  void clearDeletedPhotos() {
    _deletedUserPhotos.clear();
    _deletedLliflePhotos.clear();
  }

  Map<DateTime, List<Plant>> _individualWateringDatesCache = {};
  Map<DateTime, int> _customWateringDatesCache = {};
  List<DateTime> _recommendedWateringDatesCache = [];

  // Геттеры для основных данных
  List<Plant> get plants => _plants;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  Set<String> get selectedIds => _selectedIds;
  List<DateTime> get globalWateringDates => _globalWateringDates;
  DateTime? get lastLocalUpdate => _lastLocalUpdate; // Геттер для метки времени

  // Геттеры для кэшированных данных
  Map<DateTime, List<Plant>> get individualWateringDates {
    if (_individualWateringDatesCache.isEmpty) {
      print('Пересчёт individualWateringDates');
      _individualWateringDatesCache = {};
      for (var plant in _plants) {
        for (var date in plant.wateringDates) {
          final normalizedDate = DateTime(date.year, date.month, date.day);
          _individualWateringDatesCache[normalizedDate] ??= [];
          _individualWateringDatesCache[normalizedDate]!.add(plant);
        }
      }
    }
    return _individualWateringDatesCache;
  }

  Map<DateTime, int> get customWateringDates {
    if (_customWateringDatesCache.isEmpty) {
      print('Пересчёт customWateringDates');
      _customWateringDatesCache = {};
      for (var plant in _plants) {
        for (var date in plant.customWateringDates) {
          final normalizedDate = DateTime(date.year, date.month, date.day);
          _customWateringDatesCache[normalizedDate] =
              (_customWateringDatesCache[normalizedDate] ?? 0) + 1;
        }
      }
    }
    return _customWateringDatesCache;
  }

  List<DateTime> get recommendedWateringDates {
    if (_recommendedWateringDatesCache.isNotEmpty) {
      print('Возвращаем кэшированные recommendedWateringDates');
      return _recommendedWateringDatesCache;
    }

    print('Пересчёт recommendedWateringDates');
    final lastWatering = lastGlobalWateringDate;
    if (lastWatering == null) {
      _recommendedWateringDatesCache = [];
      return _recommendedWateringDatesCache;
    }

    List<DateTime> dates = [];
    DateTime current = lastWatering;
    final now = DateTime.now();

    for (int i = 0; i < 12; i++) {
      final nextDate = getNextWateringDate(current);
      if (nextDate == null || nextDate.isBefore(now)) break;
      dates.add(nextDate);
      current = nextDate;
    }
    _recommendedWateringDatesCache = dates;
    return _recommendedWateringDatesCache;
  }

// Добавляем кэш для подкормок
  Map<DateTime, List<Plant>> _fertilizationDatesCache = {};
  Map<DateTime, List<Plant>> _plannedFertilizationDatesCache = {};

// Геттеры для кэшированных данных подкормок
  Map<DateTime, List<Plant>> get fertilizationDates {
    if (_fertilizationDatesCache.isEmpty) {
      print('Пересчёт fertilizationDates');
      _fertilizationDatesCache = {};
      for (var plant in _plants) {
        if (plant.lastFertilization != null) {
          final date = DateTime(plant.lastFertilization!.year,
              plant.lastFertilization!.month, plant.lastFertilization!.day);
          _fertilizationDatesCache[date] ??= [];
          _fertilizationDatesCache[date]!.add(plant);
        }
      }
    }
    return _fertilizationDatesCache;
  }

  Map<DateTime, List<Plant>> get plannedFertilizationDates {
    if (_plannedFertilizationDatesCache.isEmpty) {
      print('Пересчёт plannedFertilizationDates');
      _plannedFertilizationDatesCache = {};
      for (var plant in _plants) {
        if (plant.plannedFertilizationDate != null) {
          final date = DateTime(
              plant.plannedFertilizationDate!.year,
              plant.plannedFertilizationDate!.month,
              plant.plannedFertilizationDate!.day);
          _plannedFertilizationDatesCache[date] ??= [];
          _plannedFertilizationDatesCache[date]!.add(plant);
        }
      }
    }
    return _plannedFertilizationDatesCache;
  }

// Метод для сброса кэша подкормок
  void invalidateFertilizationDatesCache() {
    print('Сброс кэша fertilization dates');
    _fertilizationDatesCache = {};
    _plannedFertilizationDatesCache = {};
    notifyListeners();
  }

  void invalidateWateringDatesCache() {
    print('Сброс кэша watering dates');
    _individualWateringDatesCache = {};
    _customWateringDatesCache = {};
    _recommendedWateringDatesCache = []; // Добавляем сброс кэша
    notifyListeners();
  }

  void setLastLocalUpdate(DateTime date) {
    _lastLocalUpdate = date;
    notifyListeners();
  }

// Геттер для флага синхронизации фото
  bool get needsPhotoSync => _needsPhotoSync;

// Метод для пометки, что нужно синхронизировать фото
  void markNeedsPhotoSync() {
    _needsPhotoSync = true;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

// Новый метод: сбрасывает флаг после успешной синхронизации
  void resetPhotoSyncFlag() {
    _needsPhotoSync = false;
  }

  bool get hasUnreadNotifications {
    return _plants.any((plant) => plant.hasUnreadNotification);
  }

  int getPlantCountForYear(int year) {
    return plants.where((p) => p.category == 'sown' && p.year == year).length;
  }

  List<int> getUniqueSowingYears() {
    return plants
        .where((p) => p.category == 'sown')
        .map((p) => p.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

// Проверка и миграция существующих фото при загрузке
  Future<void> migrateExistingPhotos() async {
    final photosDir = await _getPhotosDirectory();
    for (var plant in _plants) {
      final updatedPhotos = <String>[];
      for (var photoPath in plant.userPhotos) {
        final file = File(photoPath);
        if (await file.exists() && !photoPath.startsWith(photosDir)) {
          // Если файл существует и не в папке plant_photos, копируем его
          final newPath = await _copyPhotoToAppStorage(photoPath);
          updatedPhotos.add(newPath);
        } else {
          updatedPhotos.add(photoPath);
        }
      }
      final listEquality = ListEquality(); // Создаём экземпляр
      if (updatedPhotos.length != plant.userPhotos.length ||
          !listEquality.equals(updatedPhotos, plant.userPhotos)) {
        // Используем экземпляр
        final updatedPlant = plant.copyWith(userPhotos: updatedPhotos);
        final index = _plants.indexOf(plant);
        _plants[index] = updatedPlant;
        _hasUnsavedChanges = true;
      }
    }
    if (_hasUnsavedChanges) {
      await savePlants();
    }
  }

  Future<void> loadPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final plantsJson = prefs.getStringList(_prefsKey) ?? [];
    print('Загружено растений: ${plantsJson.length}');
    _plants = [];
    for (var json in plantsJson) {
      try {
        final plantData = jsonDecode(json);
        _plants.add(Plant.fromJson(plantData));
      } catch (e) {
        print('Ошибка при загрузке растения: $e');
        try {
          // Пробуем исправить кодировку через Latin1 как запасной вариант
          final decodedJson = latin1.decode(json.codeUnits, allowInvalid: true);
          final plantData = jsonDecode(decodedJson);
          _plants.add(Plant.fromJson(plantData));
          print('Исправлена кодировка для растения (latin1)');
        } catch (e2) {
          print('Не удалось исправить кодировку: $e2');
          // В случае ошибки добавляем растение с пустыми полями страны
          try {
            final plantData = jsonDecode(json);
            Plant plant = Plant.fromJson(plantData);
            plant = plant.copyWith(country: 'Неизвестно', countryFlag: null);
            _plants.add(plant);
            print('Добавлено растение с неизвестной страной');
          } catch (e3) {
            print('Полностью поврежденные данные, пропускаем: $e3');
          }
        }
      }
    }
    _lastLocalUpdate =
        DateTime.tryParse(prefs.getString('last_local_update') ?? '');
    print(
        'Локальные данные загружены, последнее обновление: $_lastLocalUpdate');
    _hasUnsavedChanges = false;
    await _loadGlobalWateringDates();
    // Загрузка данных о зимовке
    _winteringStartDate =
        DateTime.tryParse(prefs.getString('wintering_start_date') ?? '');
    _winteringEndDate =
        DateTime.tryParse(prefs.getString('wintering_end_date') ?? '');
    _winteringTemperature =
        double.tryParse(prefs.getString('wintering_temperature') ?? '');
    final logEntriesJson = prefs.getStringList('wintering_log_entries') ?? [];
    _winteringLogEntries = logEntriesJson.map((json) {
      try {
        final decodedJson = utf8.decode(json.codeUnits, allowMalformed: true);
        return WinteringLogEntry.fromJson(jsonDecode(decodedJson));
      } catch (e) {
        print('Ошибка загрузки записи о зимовке: $e');
        try {
          final bytes = latin1.encode(json);
          final correctedJson = utf8.decode(bytes);
          return WinteringLogEntry.fromJson(jsonDecode(correctedJson));
        } catch (e2) {
          print('Не удалось исправить кодировку записи о зимовке: $e2');
          rethrow;
        }
      }
    }).toList();
    await loadAdultImages();
    await migrateExistingPhotos();
    checkWateringNotifications();
    notifyListeners();
  }

  Future<void> savePlants() async {
    if (!_hasUnsavedChanges) {
      print('Нет несохранённых изменений, пропускаем сохранение');
      return;
    }
// === НОВОЕ: Создаём бэкап перед сохранением ===
    await createLocalBackup();
    try {
      final prefs = await SharedPreferences.getInstance();
      final plantsJson = _plants.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_prefsKey, plantsJson);
      final adultImagesJson = jsonEncode(_adultImages);
      await prefs.setString('adult_images', adultImagesJson);
      _lastLocalUpdate = DateTime.now();
      await prefs.setString(
          'last_local_update', _lastLocalUpdate!.toIso8601String());
      print('Локальные данные сохранены, время: $_lastLocalUpdate');
      await _saveGlobalWateringDates();
      // Сохранение данных о зимовке
      await prefs.setString(
          'wintering_start_date', _winteringStartDate?.toIso8601String() ?? '');
      await prefs.setString(
          'wintering_end_date', _winteringEndDate?.toIso8601String() ?? '');
      await prefs.setString(
          'wintering_temperature', _winteringTemperature?.toString() ?? '');
      await prefs.setStringList(
        'wintering_log_entries',
        _winteringLogEntries
            .map((entry) => jsonEncode(entry.toJson()))
            .toList(),
      );
      _hasUnsavedChanges = false;
      // Если были изменения фото — помечаем на синхронизацию (уже есть флаг)
      if (_needsPhotoSync) {
        print(
            '📸 Фото изменены — будет синхронизировано при следующей полной синхронизации');
      }
    } catch (e) {
      print('Ошибка сохранения: $e');
      _hasUnsavedChanges = true;
      throw Exception('Не удалось сохранить растения: $e');
    } finally {
      notifyListeners();
    }
  }

  void addPlant(Plant newPlant) {
    // Устанавливаем время последнего изменения
    final plantWithTime = newPlant.copyWith(lastModified: DateTime.now());
    _plants.add(plantWithTime);
    _hasUnsavedChanges = true;
    notifyListeners();
    savePlants();
  }

  void updatePlant(String id, Plant updatedPlant) {
    final index = _plants.indexWhere((p) => p.permanentId == id);
    if (index != -1) {
      if (_plants[index] != updatedPlant) {
        // Устанавливаем время последнего изменения
        final plantWithTime =
            updatedPlant.copyWith(lastModified: DateTime.now());
        _plants[index] = plantWithTime;
        _hasUnsavedChanges = true;
        invalidateFertilizationDatesCache();
        notifyListeners();
        savePlants();
      } else {
        print('Данные не изменились, обновление не требуется');
      }
    }
  }

  void deletePlant(String id) {
    _plants.removeWhere((p) => p.permanentId == id);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void updateRecommendedWateringDates() {
    checkWateringNotifications();
    notifyListeners();
    savePlants();
  }

  Future<void> updateMultipleStatus(String newStatus) async {
    final updatedPlants = _plants.map((plant) {
      return _selectedIds.contains(plant.permanentId)
          ? plant.copyWith(
              status: newStatus,
              notes: plant.notes,
              lastModified: DateTime.now(), // ← НОВОЕ
            )
          : plant;
    }).toList();

    _plants = updatedPlants;
    _hasUnsavedChanges = true;
    await savePlants();
  }

  Future<void> updateMultipleCategory(String newCategory) async {
    final updatedPlants = _plants.map((plant) {
      return _selectedIds.contains(plant.permanentId)
          ? plant.copyWith(
              category: newCategory,
              notes: plant.notes,
              lastModified: DateTime.now(), // ← НОВОЕ
            )
          : plant;
    }).toList();

    _plants = updatedPlants;
    _hasUnsavedChanges = true;
    await savePlants();
  }

  void deleteMultiplePlants() {
    _plants.removeWhere((plant) => _selectedIds.contains(plant.permanentId));
    _selectedIds.clear();
    _hasUnsavedChanges = true;
    notifyListeners();
    savePlants();
  }

  bool isNumberUnique(int year, int number, String category) {
    return !_plants.any((p) =>
        p.category == category && p.year == year && p.customNumber == number);
  }

  int getNextNumber(int year, String category) {
    final numbers = _plants
        .where((p) => p.category == category && p.year == year)
        .map((p) => p.customNumber)
        .toList();
    return numbers.isEmpty ? 1 : numbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  Plant getPlantById(String permanentId) {
    return _plants.firstWhere(
      (p) => p.permanentId == permanentId,
      orElse: () => throw Exception('Plant not found'),
    );
  }

  Future<void> exportSelectedToCSV(BuildContext context) async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите растения для экспорта')),
      );
      return;
    }

    String? selectedDir = await FilePicker.platform.getDirectoryPath();

    final selectedPlants =
        _plants.where((p) => _selectedIds.contains(p.permanentId)).toList();
    final csvData = const ListToCsvConverter().convert([
      ['ID', 'Латинское название', 'Статус', 'Год', 'Категория'],
      ...selectedPlants.map((p) => [
            p.displayId,
            p.latinName,
            p.statusText,
            p.year.toString(),
            p.category == 'sown' ? 'Посев' : 'Куплен'
          ])
    ]);

    final file = File(
        '$selectedDir/cactus_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл сохранён: ${file.path}')),
      );
    }
  }

  Map<String, int> get statusDistribution {
    return {
      'В коллекции': plants.where((p) => p.status == 'in_collection').length,
      'Растёт': plants.where((p) => p.status == 'growing').length,
      'Погиб': plants.where((p) => p.status == 'dead').length,
      'Не взошел': plants.where((p) => p.status == 'failed').length,
    };
  }

  String? getAdultImage(String plantId) => _adultImages[plantId];

  void updateAdultImage(String plantId, String imageUrl) {
    _adultImages[plantId] = imageUrl;
    _hasUnsavedChanges = true; // Добавлено
    notifyListeners();
    savePlants(); // Заменяет _saveAdultImages()
  }

  Future<void> loadAdultImages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedImages = prefs.getString('adult_images');
    if (encodedImages != null) {
      _adultImages = Map<String, String?>.from(jsonDecode(encodedImages));
      notifyListeners();
    }
  }

  void selectAll(List<String> ids) {
    _selectedIds.addAll(ids);
    notifyListeners();
  }

  void clearSelections() {
    _selectedIds.clear();
    notifyListeners();
  }

  Future<void> _loadGlobalWateringDates() async {
    final prefs = await SharedPreferences.getInstance();
    final datesJson = prefs.getStringList(_globalWateringKey) ?? [];
    _globalWateringDates =
        datesJson.map((dateStr) => DateTime.parse(dateStr)).toList();
  }

  Future<void> _saveGlobalWateringDates() async {
    final prefs = await SharedPreferences.getInstance();
    final datesJson =
        _globalWateringDates.map((date) => date.toIso8601String()).toList();
    await prefs.setStringList(_globalWateringKey, datesJson);
  }

  void addGlobalWateringDate(DateTime date) {
    _globalWateringDates.add(date);
    _hasUnsavedChanges = true;
    updateRecommendedWateringDates();
  }

  DateTime? getNextWateringDate(DateTime? lastWatering) {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    final latestWatering = lastWatering ?? lastGlobalWateringDate ?? now;
    final latestCustomDate = _getLatestCustomWateringDate();
    if (latestCustomDate != null && latestCustomDate.isAfter(latestWatering)) {
      return latestCustomDate;
    }

    if (month == 3 && day < 15) {
      return DateTime(now.year, 3, 15);
    } else if (month >= 3 && month <= 4) {
      return latestWatering.add(const Duration(days: 14));
    } else if (month >= 5 && month <= 8) {
      return latestWatering.add(const Duration(days: 7));
    } else if (month == 9) {
      return latestWatering.add(const Duration(days: 10));
    } else if (month == 10) {
      return latestWatering.add(const Duration(days: 20));
    } else if (month == 11 && day <= 5) {
      return DateTime(now.year, 11, 5);
    } else if (month >= 11 || month <= 2 || (month == 3 && day < 15)) {
      return DateTime(now.year + (month >= 11 ? 1 : 0), 3, 15);
    }
    return latestWatering.add(const Duration(days: 7));
  }

  void checkWateringNotifications() {
    print('Проверка уведомлений о поливе');
    final now = DateTime.now();
    final lastGlobalWatering = lastGlobalWateringDate;
    final recommendedDates = recommendedWateringDates;
    bool hasChanges = false;

    for (var i = 0; i < _plants.length; i++) {
      bool needsNotification = false;
      if (lastGlobalWatering == null) {
        needsNotification = true;
      } else {
        for (var date in recommendedDates) {
          if (now.isAfter(date)) {
            needsNotification = true;
            break;
          }
        }
      }
      if (_plants[i].hasUnreadNotification != needsNotification) {
        _plants[i] =
            _plants[i].copyWith(hasUnreadNotification: needsNotification);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      print('Уведомления изменены, обновляем данные');
      _hasUnsavedChanges = true;
      notifyListeners();
      savePlants();
    } else {
      print('Уведомления не изменились');
    }
  }

  void removeGlobalWateringDate(DateTime date) {
    globalWateringDates.removeWhere((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
    notifyListeners();
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void clearWateringDataForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    _globalWateringDates.removeWhere((d) => isSameDay(d, normalizedDate));
    for (var plant in _plants) {
      plant.wateringDates.removeWhere((d) => isSameDay(d, normalizedDate));
      plant.customWateringDates
          .removeWhere((d) => isSameDay(d, normalizedDate));
    }
    updateRecommendedWateringDates();
    invalidateWateringDatesCache(); // Добавляем сброс кэша
  }

  void removeCustomWateringDate(String plantId, DateTime date) {
    final plant = plants.firstWhere((p) => p.permanentId == plantId);
    plant.customWateringDates.removeWhere((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
    _hasUnsavedChanges = true;
    invalidateWateringDatesCache(); // Добавляем сброс кэша
    notifyListeners();
    savePlants();
  }

  // Новый метод для парсинга HTML с Llifle. Что меняет: Добавляет извлечение country (первая страна из "Origin and Habitat", e.g., "Argentina" или "Mexico" по списку из mapping.json), habitat (весь текст раздела для ареала) и careTips ("Cultivation and Propagation" для ухода: полив, почва, размножение — полезно для кактусов, e.g., Ariocarpus не любит мокрую почву).
  // Функциональность: Возвращает Map для заполнения Plant. Если раздела нет — null (fallback). Интеграция: Вызывайте после загрузки HTML в fetch-методе.
  // Не удаляет: Существующий парсинг description/synonyms (fallback на null, если не парсите отдельно). Не конфликтует: Использует html/parser (уже в pubspec), null-safe.
  // Ботаника: Country для флагов/рекомендаций (e.g., аргентинские кактусы любят сухость); habitat для полного описания экологии (почва, высота — имитируйте в уходе).
  Map<String, String?> parseLlifleData(String htmlContent) {
    final document = parse(htmlContent); // parse из html/parser

    // Извлечение habitat и country из "Origin and Habitat"
    final originElement = document
        .querySelector('p.expandable.Description_Sheet_Origin_and_Habitat');
    String? habitat;
    String? country;
    if (originElement != null) {
      habitat = originElement.text
          .trim(); // Весь текст в habitat (как просили: для glaucum — "Belen, Catamarca, Argentina"; для fissuratus — полный абзац)

      // Извлечение первой страны (case-insensitive поиск по списку из вашего assets/country_mapping.json)
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
        'Costa Rica'
      }; // Расширьте при необходимости
      for (final c in countries) {
        if (habitat.toLowerCase().contains(c.toLowerCase())) {
          country = c;
          break; // Первая найденная (e.g., "Mexican" → "Mexico" для fissuratus)
        }
      }
    }

    // Извлечение careTips из "Cultivation and Propagation" (новое: полив, почва, размножение)
    final careElement = document.querySelector(
        'p.expandable.Description_Sheet_Cultivation_and_Propagation');
    final careTips = careElement?.text.trim();

    // Fallback для description и synonyms (если у вас уже есть парсер — не трогаем, возвращаем null для ручного)
    final descElement =
        document.querySelector('p.expandable.Description_Sheet_Description');
    final description = descElement?.text.trim();

    final synonymsElement = document.querySelector('#short_synonyms_list ul');
    String? synonyms;
    if (synonymsElement != null) {
      synonyms = synonymsElement.text
          .trim()
          .replaceAll(RegExp(r'\s+'), ' '); // Очистка множественных пробелов
    }

    return {
      'country': country,
      'habitat': habitat,
      'careTips': careTips,
      'description': description,
      'synonyms': synonyms,
    };
  }

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

  void addIndividualWateringDate(String plantId, DateTime date) {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final updatedPlant = _plants[plantIndex].copyWith(
        wateringDates: [
          ..._plants[plantIndex].wateringDates,
          date,
        ],
      );
      _plants[plantIndex] = updatedPlant;
      _hasUnsavedChanges = true;
      invalidateWateringDatesCache(); // Добавляем сброс кэша
      notifyListeners();
      savePlants();
    }
  }

  void removeIndividualWateringDate(String plantId, DateTime date) {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final updatedDates = _plants[plantIndex]
          .wateringDates
          .where((d) =>
              d.year != date.year || d.month != date.month || d.day != date.day)
          .toList();
      final updatedPlant = _plants[plantIndex].copyWith(
        wateringDates: updatedDates,
      );
      _plants[plantIndex] = updatedPlant;
      _hasUnsavedChanges = true;
      invalidateWateringDatesCache(); // Добавляем сброс кэша
      notifyListeners();
      savePlants();
    }
  }

  void cleanupIndividualWateringDates() {
    final now = DateTime.now();
    for (var i = 0; i < _plants.length; i++) {
      final updatedDates = _plants[i].wateringDates.where((date) {
        return now.difference(date).inDays <= 90;
      }).toList();
      if (updatedDates.length != _plants[i].wateringDates.length) {
        _plants[i] = _plants[i].copyWith(wateringDates: updatedDates);
        _hasUnsavedChanges = true;
      }
    }
    notifyListeners();
    savePlants();
  }

  int getPlantsWateredOnDate(DateTime date) {
    return _plants
        .where((plant) => plant.wateringDates.any((d) =>
            d.year == date.year && d.month == date.month && d.day == date.day))
        .length;
  }

  DateTime? _getLatestCustomWateringDate() {
    List<DateTime> allCustomDates = [];
    for (var plant in _plants) {
      allCustomDates.addAll(plant.customWateringDates);
    }
    if (allCustomDates.isEmpty) return null;
    return allCustomDates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  void clearNotifications() {
    for (var i = 0; i < _plants.length; i++) {
      if (_plants[i].hasUnreadNotification) {
        _plants[i] = _plants[i].copyWith(hasUnreadNotification: false);
      }
    }
    _hasUnsavedChanges = true;
    notifyListeners();
    savePlants();
  }

  void addCustomWateringDate(String plantId, DateTime date) {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final updatedPlant = _plants[plantIndex].copyWith(
        customWateringDates: [
          ..._plants[plantIndex].customWateringDates,
          date,
        ],
      );
      _plants[plantIndex] = updatedPlant;
      _hasUnsavedChanges = true;
      invalidateWateringDatesCache(); // Добавляем сброс кэша
      notifyListeners();
      savePlants();
    }
  }

  // Методы для загрузки данных из облака
  void loadPlantsFromJson(dynamic jsonData) {
    _plants = (jsonData as List<dynamic>)
        .map((item) => Plant.fromJson(item as Map<String, dynamic>))
        .toList();
    invalidateWateringDatesCache(); // Добавляем сброс кэша
    notifyListeners();
  }

  void loadGlobalWateringDatesFromJson(dynamic jsonData) {
    _globalWateringDates = (jsonData as List<dynamic>)
        .map((dateStr) => DateTime.parse(dateStr as String))
        .toList();
    notifyListeners();
  }

  Map<String, String?> getAdultImages() => _adultImages;

  void loadAdultImagesFromJson(dynamic jsonData) {
    _adultImages = Map<String, String?>.from(jsonData as Map<String, dynamic>);
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'plants': _plants.map((p) => p.toJson()).toList(),
        'globalWateringDates':
            _globalWateringDates.map((date) => date.toIso8601String()).toList(),
        'adultImages': _adultImages,
        'lastLocalUpdate': _lastLocalUpdate?.toIso8601String(),
        'winteringStartDate': _winteringStartDate?.toIso8601String(),
        'winteringEndDate': _winteringEndDate?.toIso8601String(),
        'winteringTemperature': _winteringTemperature,
        'winteringLogEntries':
            _winteringLogEntries.map((entry) => entry.toJson()).toList(),
      };

  // === МЕТОДЫ УМНОГО СЛИЯНИЯ ДАННЫХ ===
  
  /// Сливает данные растения по принципу "кто первый тот и прав"
  Plant _mergePlantData(Plant local, Plant cloud) {
    // Сравниваем timestamps последнего изменения
    final useCloudAsBase = cloud.lastModified != null && 
        local.lastModified != null && 
        cloud.lastModified!.isAfter(local.lastModified!);
    
    final base = useCloudAsBase ? cloud : local;
    final other = useCloudAsBase ? local : cloud;
    
    print('🔄 Слияние ${base.latinName}: ${useCloudAsBase ? "облако > локальное" : "локальное > облако"}');
    
    // Сливаем свои фото с исключением удаленных
    final mergedPhotos = _mergePhotoLists(base.userPhotos, other.userPhotos, _deletedUserPhotos);
    
    // Сливаем Llifle фото с исключением удаленных
    final mergedLliflePhotos = _mergePhotoLists(base.lliflePhotoUrls, other.lliflePhotoUrls, _deletedLliflePhotos);
    
    return base.copyWith(
      userPhotos: mergedPhotos,
      lliflePhotoUrls: mergedLliflePhotos,
      lastModified: DateTime.now(),
      // Остальные поля берем из base (более свежей версии)
      status: base.status,
      category: base.category,
      notes: _mergeNotes(base.notes, other.notes),
      lastFertilization: base.lastFertilization,
      plannedFertilizationDate: base.plannedFertilizationDate,
      floweringHistory: _mergeFloweringHistory(base.floweringHistory, other.floweringHistory),
      germinationHistory: _mergeGerminationHistory(base.germinationHistory, other.germinationHistory),
      lastRepotting: base.lastRepotting,
      plannedTransplantDate: base.plannedTransplantDate,
      wateringDates: _mergeWateringDates(base.wateringDates, other.wateringDates),
      customWateringDates: _mergeCustomWateringDates(base.customWateringDates, other.customWateringDates),
      hasUnreadNotification: base.hasUnreadNotification,
    );
  }
  
  /// Сливает списки фото без дубликатов, исключая удаленные фото
  List<String> _mergePhotoLists(List<String> base, List<String> other, Set<String> deletedPhotos) {
    final allPhotos = <String>{};
    final orderedPhotos = <String>[];
    
    // Фильтруем удаленные фото
    final filteredBase = base.where((photo) {
      final dedupeKey = _photoDedupKey(photo);
      return !deletedPhotos.contains(dedupeKey);
    }).toList();
    
    final filteredOther = other.where((photo) {
      final dedupeKey = _photoDedupKey(photo);
      return !deletedPhotos.contains(dedupeKey);
    }).toList();
    
    // Добавляем в порядке: сначала base, потом недостающие из other
    for (final photo in filteredBase) {
      final dedupeKey = _photoDedupKey(photo);
      if (!allPhotos.contains(dedupeKey)) {
        allPhotos.add(dedupeKey);
        orderedPhotos.add(photo);
      }
    }
    
    for (final photo in filteredOther) {
      final dedupeKey = _photoDedupKey(photo);
      if (!allPhotos.contains(dedupeKey)) {
        allPhotos.add(dedupeKey);
        orderedPhotos.add(photo);
      }
    }
    
    return orderedPhotos;
  }

  /// Сливает историю всходов по принципу "кто первый тот и прав"
  List<GerminationRecord> _mergeGerminationHistory(
    List<GerminationRecord> base,
    List<GerminationRecord> other,
  ) {
    final allRecords = <GerminationRecord>[];
    final seenDates = <DateTime>{};
    
    // Собираем все уникальные записи по дате
    for (final record in [...base, ...other]) {
      final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
      if (!seenDates.contains(dateKey)) {
        allRecords.add(record);
        seenDates.add(dateKey);
      }
    }
    
    return allRecords..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Сливает историю цветения по принципу "кто первый тот и прав"
  List<FloweringRecord> _mergeFloweringHistory(
    List<FloweringRecord> base,
    List<FloweringRecord> other,
  ) {
    final allRecords = <FloweringRecord>[];
    final seenKeys = <String>{};
    
    // Собираем все уникальные записи по дате + событию
    for (final record in [...base, ...other]) {
      final key = '${record.date.year}-${record.date.month}-${record.date.day}_${record.event}';
      if (!seenKeys.contains(key)) {
        allRecords.add(record);
        seenKeys.add(key);
      }
    }
    
    return allRecords..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Сливает даты полива по принципу "кто первый тот и прав"
  List<DateTime> _mergeWateringDates(List<DateTime> base, List<DateTime> other) {
    final allDates = <DateTime>{};
    final orderedDates = <DateTime>[];
    
    // Собираем все уникальные даты
    for (final date in [...base, ...other]) {
      final dateKey = DateTime(date.year, date.month, date.day);
      if (!allDates.contains(dateKey)) {
        allDates.add(dateKey);
        orderedDates.add(date);
      }
    }
    
    return orderedDates..sort((a, b) => a.compareTo(b));
  }

  /// Сливает кастомные даты полива по принципу "кто первый тот и прав"
  List<DateTime> _mergeCustomWateringDates(List<DateTime> base, List<DateTime> other) {
    final allDates = <DateTime>{};
    final orderedDates = <DateTime>[];
    
    // Собираем все уникальные даты
    for (final date in [...base, ...other]) {
      final dateKey = DateTime(date.year, date.month, date.day);
      if (!allDates.contains(dateKey)) {
        allDates.add(dateKey);
        orderedDates.add(date);
      }
    }
    
    return orderedDates..sort((a, b) => a.compareTo(b));
  }

  /// Сливает заметки по принципу "кто первый тот и прав"
  List<Note> _mergeNotes(List<Note> base, List<Note> other) {
    final allNotes = <Note>[];
    final seenIds = <String>{};
    
    // Собираем все уникальные заметки по ID
    for (final note in [...base, ...other]) {
      if (!seenIds.contains(note.id)) {
        allNotes.add(note);
        seenIds.add(note.id);
      }
    }
    
    return allNotes..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  
  /// Генерирует ключ для дедупликации фото
  String _photoDedupKey(String photo) {
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      final uri = Uri.tryParse(photo);
      if (uri != null) {
        return '${uri.scheme}://${uri.host}${uri.path}'.toLowerCase();
      }
    }
    return photo;
  }

  // === МЕТОД ЗАГРУЗКИ ДАННЫХ ИЗ ОБЛАКА ===
  void loadFromCloudJson(Map<String, dynamic> data) {
    print(
        '🔄 loadFromCloudJson вызван — загружаем ${data['plants']?.length ?? 0} растений');

    final plantsJson = data['plants'] as List<dynamic>? ?? [];
    final cloudPlants = <Plant>[];

    // Сначала загружаем все растения из облака
    for (var json in plantsJson) {
      try {
        final plant = Plant.fromJson(json as Map<String, dynamic>);
        cloudPlants.add(plant);
      } catch (e) {
        print('❌ Ошибка загрузки растения из облака: $e');
      }
    }

    // Теперь сливаем с локальными данными
    final mergedPlants = <Plant>[];
    
    // Обрабатываем растения, которые есть в облаке
    for (var cloudPlant in cloudPlants) {
      final localIndex = _plants.indexWhere((p) => p.permanentId == cloudPlant.permanentId);
      
      if (localIndex != -1) {
        // Растение есть локально и в облаке - сливаем
        final merged = _mergePlantData(_plants[localIndex], cloudPlant);
        mergedPlants.add(merged);
        print('✅ Слияние: ${merged.latinName}');
      } else {
        // Растение только в облаке - добавляем как есть
        mergedPlants.add(cloudPlant);
        print('➕ Новое из облака: ${cloudPlant.latinName}');
      }
    }
    
    // Добавляем растения, которые есть только локально
    for (var localPlant in _plants) {
      final existsInCloud = cloudPlants.any((p) => p.permanentId == localPlant.permanentId);
      if (!existsInCloud) {
        mergedPlants.add(localPlant);
        print('💾 Только локальное: ${localPlant.latinName}');
      }
    }
    
    // Обновляем список растений
    _plants = mergedPlants;

    // Загружаем остальные данные
    _globalWateringDates = (data['globalWateringDates'] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d as String))
            .toList() ??
        [];

    _adultImages = Map<String, String?>.from(data['adultImages'] ?? {});

    _lastLocalUpdate = data['lastLocalUpdate'] != null
        ? DateTime.tryParse(data['lastLocalUpdate'] as String)
        : null;

    // Зимовка
    _winteringStartDate = data['winteringStartDate'] != null
        ? DateTime.tryParse(data['winteringStartDate'] as String)
        : null;
    _winteringEndDate = data['winteringEndDate'] != null
        ? DateTime.tryParse(data['winteringEndDate'] as String)
        : null;
    _winteringTemperature = data['winteringTemperature'] as double?;

    _winteringLogEntries = (data['winteringLogEntries'] as List<dynamic>?)
            ?.map((e) => WinteringLogEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    print('✅ Загружено ${_plants.length} растений из облака');

    // КРИТИЧНО: После загрузки сразу приводим фото в порядок
    ensureLocalPhotosExist().then((_) {
      cleanupLocalPhotosAfterCloudLoad();
      invalidateAllCaches();
      notifyListeners();
      print('✅ Фото обработаны после загрузки из облака');
    });
  }

  // === ВРЕМЕННО ЗАКОММЕНТИРОВАНО, Т.К. НЕ ИСПОЛЬЗУЕТСЯ ===
  // Plant _mergePlant(Plant local, Plant cloud) {
  //   final useCloudAsBase =
  //       (cloud.lastModified != null && local.lastModified != null)
  //           ? cloud.lastModified!.isAfter(local.lastModified!)
  //           : (cloud.lastModified != null);

  //   final base = useCloudAsBase ? cloud : local;
  //   final other = useCloudAsBase ? local : cloud;

  //   final mergedGermination = _mergeGerminationHistory(
  //     base.germinationHistory,
  //     other.germinationHistory,
  //   );

  //   final mergedFlowering = _mergeListsByDate(
  //     base.floweringHistory,
  //     other.floweringHistory,
  //     (a, b) => a.date == b.date && a.event == b.event,
  //   );

  //   final mergedNotes = _mergeListsByDate(
  //     base.notes,
  //     other.notes,
  //     (a, b) => a.id == b.id,
  //   );

  //   final mergedWatering = {...base.wateringDates, ...other.wateringDates}
  //       .toList()
  //     ..sort((a, b) => a.compareTo(b));

  //   final mergedCustomWatering = {
  //     ...base.customWateringDates,
  //     ...other.customWateringDates
  //   }.toList()
  //     ..sort((a, b) => a.compareTo(b));

  //   final mergedUserPhotos =
  //       <String>{...base.userPhotos, ...other.userPhotos}.toList();

  //   return base.copyWith(
  //     germinationHistory: mergedGermination,
  //     floweringHistory: mergedFlowering,
  //     notes: mergedNotes,
  //     wateringDates: mergedWatering,
  //     customWateringDates: mergedCustomWatering,
  //     userPhotos: mergedUserPhotos,
  //     lastModified: DateTime.now(),
  //   );
  // }

  // === ВРЕМЕННО ЗАКОММЕНТИРОВАНО — НЕ ИСПОЛЬЗУЕТСЯ ===
  // List<GerminationRecord> _mergeGerminationHistory(
  //   List<GerminationRecord> list1,
  //   List<GerminationRecord> list2,
  // ) {
  //   final result = <GerminationRecord>{...list1};

  //   for (var item in list2) {
  //     final existing = result.firstWhereOrNull((e) => e.date == item.date);

  //     if (existing == null) {
  //       result.add(item);
  //     } else {
  //       final existingAlive = existing.germinatedCount - existing.deadCount;
  //       final newAlive = item.germinatedCount - item.deadCount;

  //       if (newAlive > existingAlive) {
  //         result.remove(existing);
  //         result.add(item);
  //       }
  //     }
  //   }

  //   return result.toList()..sort((a, b) => a.date.compareTo(b.date));
  // }

  // List<T> _mergeListsByDate<T>(
  //   List<T> list1,
  //   List<T> list2,
  //   bool Function(T, T) isSame,
  // ) {
  //   final result = <T>{...list1};
  //   for (var item in list2) {
  //     final existing = result.firstWhereOrNull((e) => isSame(e, item));
  //     if (existing == null) {
  //       result.add(item);
  //     }
  //   }
  //   return result.toList();
  // }

// Получение пути к папке plant_photos
  Future<String> _getPhotosDirectory() async {
    final directory =
        await getApplicationDocumentsDirectory(); // Должно работать с импортом
    final photosDir = Directory('${directory.path}/plant_photos');
    if (!await photosDir.exists()) {
      await photosDir.create();
    }
    return photosDir.path;
  }

  // Копирование файла в папку plant_photos с уникальным именем
  Future<String> _copyPhotoToAppStorage(String originalPath) async {
    try {
      final photosDir = await _getPhotosDirectory();
      final baseName = path.basename(originalPath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$baseName';
      final newPath = path.join(photosDir, fileName);
      final sourceFile = File(originalPath);
      if (!await sourceFile.exists()) {
        throw Exception('Исходный файл не существует: $originalPath');
      }
      await sourceFile.copy(newPath);
      return newPath;
    } catch (e) {
      print('Ошибка копирования файла: $e');
      rethrow; // Или обработайте ошибку иным способом
    }
  }

  // Удаление файла из папки plant_photos
  Future<void> _deletePhotoFromStorage(String photoPath) async {
    final file = File(photoPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> addUserPhoto(String plantId, String photoPath) async {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      try {
        final newPhotoPath = await _copyPhotoToAppStorage(photoPath);
        final updatedPhotos = List<String>.from(_plants[plantIndex].userPhotos)
          ..add(newPhotoPath);
        final updatedPlant = _plants[plantIndex].copyWith(
          userPhotos: updatedPhotos,
          lastModified: DateTime.now(), // ← НОВОЕ
        );
        _plants[plantIndex] = updatedPlant;
        _hasUnsavedChanges = true;
        notifyListeners();
        await savePlants();

        // Вместо прямого вызова синхронизации — только помечаем
        markNeedsPhotoSync();

        // Опционально: можно запустить синхронизацию в фоне, но позже
        // final cloudProvider = Provider.of<CloudStorageProvider>(navigatorKey.currentContext!, listen: false);
        // if (cloudProvider.isConnected) {
        //   cloudProvider.syncUserPhotos(this); // пока закомментируем
        // }
      } catch (e) {
        print('Ошибка добавления фото: $e');
        rethrow;
      }
    }
  }

  Future<void> removeUserPhoto(String plantId, String photoPath) async {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final updatedPhotos = List<String>.from(_plants[plantIndex].userPhotos)
        ..remove(photoPath);
      final updatedPlant = _plants[plantIndex].copyWith(
        userPhotos: updatedPhotos,
        lastModified: DateTime.now(),
      );
      _plants[plantIndex] = updatedPlant;
      _hasUnsavedChanges = true;

      // Если это cloud URL - помечаем на удаление с облака
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        markUserPhotoAsDeleted(photoPath);
      }

      // Удаляем файл из хранилища
      await _deletePhotoFromStorage(photoPath);

      notifyListeners();
      await savePlants();

      // Вместо прямого вызова — только помечаем на отложенную синхронизацию
      markNeedsPhotoSync();
    }
  }

  Future<void> addLliflePhoto(String plantId, String photoUrl) async {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final updatedPhotos = List<String>.from(_plants[plantIndex].lliflePhotoUrls);
      if (!updatedPhotos.contains(photoUrl)) {
        updatedPhotos.add(photoUrl);
        final updatedPlant = _plants[plantIndex].copyWith(
          lliflePhotoUrls: updatedPhotos,
          lastModified: DateTime.now(),
        );
        _plants[plantIndex] = updatedPlant;
        _hasUnsavedChanges = true;

        notifyListeners();
        await savePlants();

        // Помечаем на синхронизацию
        markNeedsPhotoSync();
      }
    }
  }

  Future<void> setLlifleAsMainPhoto(String plantId, String photoUrl) async {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final lliflePhotos = List<String>.from(_plants[plantIndex].lliflePhotoUrls);
      if (lliflePhotos.contains(photoUrl)) {
        lliflePhotos.remove(photoUrl);
        lliflePhotos.insert(0, photoUrl); // В начало списка
        
        final updatedPlant = _plants[plantIndex].copyWith(
          lliflePhotoUrls: lliflePhotos,
          lastModified: DateTime.now(),
        );
        _plants[plantIndex] = updatedPlant;
        _hasUnsavedChanges = true;

        notifyListeners();
        await savePlants();

        // Помечаем на синхронизацию
        markNeedsPhotoSync();
      }
    }
  }

  Future<void> removeLliflePhoto(String plantId, String photoUrl) async {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final updatedPhotos = List<String>.from(_plants[plantIndex].lliflePhotoUrls)
        ..remove(photoUrl);
      final updatedPlant = _plants[plantIndex].copyWith(
        lliflePhotoUrls: updatedPhotos,
        lastModified: DateTime.now(),
      );
      _plants[plantIndex] = updatedPlant;
      _hasUnsavedChanges = true;

      // Помечаем на удаление с облака
      markLliflePhotoAsDeleted(photoUrl);

      notifyListeners();
      await savePlants();

      // Вместо прямого вызова — только помечаем на отложенную синхронизацию
      markNeedsPhotoSync();
    }
  }

  List<String> getUserPhotos(String plantId) {
    try {
      final plant = _plants.firstWhere((p) => p.permanentId == plantId);
      return plant.userPhotos;
    } catch (e) {
      return []; // Если растение не найдено, возвращаем пустой список
    }
  }

  void markAsFertilized(String permanentId, {DateTime? date}) {
    final plant = _plants.firstWhere((p) => p.permanentId == permanentId);
    final fertilizationDate = date ?? DateTime.now();
    final updatedPlant = plant.copyWith(
      lastFertilization: fertilizationDate,
      plannedFertilizationDate: null,
      notes: plant.notes,
      lastModified: DateTime.now(), // ← НОВОЕ
    );
    updatePlant(permanentId, updatedPlant);
    invalidateFertilizationDatesCache();
    savePlants();
    notifyListeners();
  }

  void planFertilization(String plantId, DateTime date) {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final updatedPlant = _plants[plantIndex].copyWith(
        plannedFertilizationDate: date,
        notes: _plants[plantIndex].notes,
        lastModified: DateTime.now(), // ← НОВОЕ
      );
      _plants[plantIndex] = updatedPlant;
      _hasUnsavedChanges = true;
      invalidateFertilizationDatesCache();
      notifyListeners();
      savePlants();
    }
  }

  void markGroupAsFertilized(Set<String> plantIds, {DateTime? date}) {
    for (final permanentId in plantIds) {
      markAsFertilized(permanentId, date: date);
    }
    invalidateFertilizationDatesCache();
    savePlants();
    notifyListeners();
  }

  void planGroupFertilization(Set<String> plantIds, DateTime date) {
    for (var plantId in plantIds) {
      final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
      if (plantIndex != -1) {
        final updatedPlant = _plants[plantIndex].copyWith(
          plannedFertilizationDate: date,
          lastModified: DateTime.now(), // ← НОВОЕ
        );
        _plants[plantIndex] = updatedPlant;
      }
    }
    _hasUnsavedChanges = true;
    invalidateFertilizationDatesCache();
    notifyListeners();
    savePlants();
  }

  void addFloweringEvent(String plantId, DateTime date, String event) {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final updatedFloweringHistory =
          List<FloweringRecord>.from(_plants[plantIndex].floweringHistory)
            ..add(FloweringRecord(date: date, event: event));
      final updatedPlant = _plants[plantIndex].copyWith(
        floweringHistory: updatedFloweringHistory,
        lastModified: DateTime.now(), // ← НОВОЕ
      );
      _plants[plantIndex] = updatedPlant;
      _hasUnsavedChanges = true;
      notifyListeners();
      savePlants();
    }
  }

  void clearFloweringData(String plantId) {
    final plantIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (plantIndex != -1) {
      final updatedPlant = _plants[plantIndex].copyWith(
        floweringHistory: [],
        lastModified: DateTime.now(), // ← НОВОЕ
      );
      _plants[plantIndex] = updatedPlant;
      _hasUnsavedChanges = true;
      notifyListeners();
      savePlants();
    }
  }

  Future<void> resetAppData() async {
    // Очистка памяти
    _plants = [];
    _selectedIds.clear();
    _globalWateringDates = [];
    _adultImages = {};
    _lastLocalUpdate = null;

    // Очистка SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Удаление папки с фото
    try {
      final photosDir = await _getPhotosDirectory();
      final photoDir = Directory(photosDir);
      if (await photoDir.exists()) {
        await photoDir.delete(recursive: true);
      }
      await photoDir.create(recursive: true);
    } catch (e) {
      print('Ошибка очистки фото: $e');
    }

    // Сброс кэшей
    invalidateWateringDatesCache();
    invalidateFertilizationDatesCache();

    notifyListeners();
    print('Все данные приложения сброшены');
  }

  // Новый метод: Инициализирует координаты локации (один раз при запуске, Шаг 5 в welcome_screen). Меняет: Автоматически получает lat/lon через WeatherService и сохраняет в shared_preferences для кэша. Не удаляет: Твои методы (loadPlants/addPlant/deletePlant intact — не вызываются здесь). Функциональность: Fallback на null если отказ в гео (ручной ввод города позже, если нужно); notifyListeners() для обновления UI (минимально, без rebuild списков). Проверено: Async OK, prefs.setDouble без ошибок (если lat null — не сохраняет), no conflicts с твоим savePlants (отдельные ключи 'lat'/'lon'). Ботаника: Точные координаты — для локальной погоды (e.g., +12°C в твоем районе Москвы 29.09.2025, не общий).
  Future<void> initLocation() async {
    final service = WeatherService();
    final position = await service.getCurrentLocation();
    if (position != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('lat', position.latitude);
      await prefs.setDouble('lon', position.longitude);
      notifyListeners(); // Обновляем UI, если локация влияет на экраны (e.g., watering_calendar).
    }
  }

  // Новый метод: Генерирует персональный совет по поливу для растения (на основе погоды + category). Меняет: Получает weather из кэша, применяет логику if (дождь/влажность >60% для sown, >70% для purchased — отложить; жара — полить). Не удаляет: Твои методы (updatePlant/getNextNumber intact). Функциональность: Кэш из prefs (экономит API), fallback 'Проверьте вручную' если null; async для UI (FutureBuilder в Шагах 6/7). Проверено: service.getCurrentWeather(lat ?? null) safe (null-check), getWateringAdvice возвращает String без краша. Ботаника: Адаптировано под коллекцию (purchased чувствительнее — строже к влаге в сентябре).
  Future<String> getWeatherAdvice(Plant plant) async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('lat');
    final lon = prefs.getDouble('lon');
    final service = WeatherService();
    // Фикс: Fallback на city if lat/lon null (для desktop без GPS). Меняет: Если lat/lon null — getCity, if city not empty — service.getWeatherByCity, else null. Не удаляет: Логику lat/lon (if coords — use them). Функциональность: Async safe (await getCity/getWeatherByCity, кэш intact); fallback null если no city — 'Проверьте вручную'. Проверено: getCity/setCity new (Шаг 7.3), no null errors (city.isEmpty check); no конфликтов с savePlants (отдельные ключи 'city').
    Map<String, dynamic>? weather;
    if (lat != null && lon != null) {
      weather = await service.getCurrentWeather(lat, lon);
    } else {
      final city = await getCity(); // Get saved city.
      if (city != null && city.isNotEmpty) {
        weather = await service.getWeatherByCity(city); // Fallback на город.
      }
    }
    return service.getWateringAdvice(weather, plant);
  }

  // Новый метод: Отправляет push-уведомление о погоде/поливе (из Шага 6 при открытии экрана). Меняет: Использует global flutterLocalNotificationsPlugin (из Шага 3) для показа в трее (title/body с каналом 'weather_channel'). Не удаляет: Твои методы (toggleSelection intact). Функциональность: High priority (звуком/вибрацией), ID 0 уникален (не дублирует daily ID 1); async без блокировок. Проверено: NotificationDetails const OK, show() await safe (no errors если нет разрешений). Ботаника: Автоматический push (e.g., "Дождь 29.09 — отложите для всех sown!").
  Future<void> sendWeatherNotification(String title, String body) async {
    // Исправление: Убрали const для AndroidNotificationDetails/NotificationDetails — теперь safe после импортов (убирает ошибку "const_initialized_with_non_constant_value", строки 1142/1148). Меняет: Non-const конструкторы (плагин позволяет, без потери функциональности). Не удаляет: Логику канала/importance/priority — push high priority intact (звук/вибрация на Windows). Функциональность: Работает как раньше (ID 'weather_channel' для группировки советов по поливу). Проверено: Синтаксис OK, no runtime errors (await show() safe).
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'weather_channel', 'Погода для кактусов', // ID канала для группировки.
      channelDescription: 'Уведомления о поливу с учетом погоды.',
      importance: Importance.high,
      priority: Priority.high,
    );
    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0, // ID уведомления (уникален, не конфликтует с daily 1).
      title, body, platformDetails,
    );
  }

  // Фикс: Skip zonedSchedule on Windows (unimplemented, fallback silent — immediate push in sendWeatherNotification). Меняет: If Platform.isWindows — return (no daily, but immediate OK). Не удаляет: Логику Android/iOS (zonedSchedule intact). Функциональность: Add import 'dart:io';, Platform.isWindows check — silent skip, no crash. Проверено: Import at top, isWindows bool safe, no конфликтов с sendWeatherNotification (immediate push intact); fallback no daily on desktop — user can open app for advice.
  Future<void> scheduleDailyWeatherCheck() async {
    if (Platform.isWindows) {
      return; // Skip on Windows — unimplemented, fallback silent.
    }
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1, // ID (отличается от send 0).
      'Ежедневный совет по поливу', 'Проверьте погоду для коллекции!',
      tz.TZDateTime.from(DateTime.now(), tz.local)
          .add(const Duration(hours: 8)), // 8:00 завтра (tz.local auto).
      const NotificationDetails(
          android: AndroidNotificationDetails('daily_channel', 'Ежедневно')),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Ежедневно в 8:00.
    );
  }

  // Новый метод: Получает сохранённый город из prefs (fallback для desktop без GPS). Меняет: Добавляет getCity() — возвращает 'city' или '' (для getCurrentWeather fallback). Не удаляет: Твои методы (initLocation/getWeatherAdvice intact — if lat null, use city). Функциональность: String? async safe (prefs.getString), empty if no city — fallback 'Проверьте вручную'. Проверено: Prefs key 'city' new, no overwrite lat/lon; no конфликтов с savePlants (отдельные ключи).
  Future<String?> getCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('city');
  }

  // Новый метод: Сохраняет город в prefs (manual input из dialog). Меняет: Добавляет setCity(String city) — prefs.setString для fallback на desktop. Не удаляет: Твои методы (setDouble 'lat/lon' intact). Функциональность: Await safe, notifyListeners() for refresh UI (watering/plant_card советы). Проверено: String city OK, no null errors; notifyListeners() minimal (rebuild advice).
  Future<void> setCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', city);
    notifyListeners(); // Refresh UI (советы обновятся).
  }
// ==================== ЛОКАЛЬНЫЙ БЭКАП ====================

  Future<String> getBackupFilePath() async {
    final photosDir = await _getPhotosDirectory();
    return '$photosDir/plant_provider_backup.json';
  }

  Future<void> createLocalBackup() async {
    try {
      final backupPath = await getBackupFilePath();
      final backupData = {
        'plants': _plants.map((p) => p.toJson()).toList(),
        'globalWateringDates':
            _globalWateringDates.map((d) => d.toIso8601String()).toList(),
        'adultImages': _adultImages,
        'lastLocalUpdate': _lastLocalUpdate?.toIso8601String(),
        'winteringStartDate': _winteringStartDate?.toIso8601String(),
        'winteringEndDate': _winteringEndDate?.toIso8601String(),
        'winteringTemperature': _winteringTemperature,
        'winteringLogEntries':
            _winteringLogEntries.map((e) => e.toJson()).toList(),
      };

      final file = File(backupPath);
      await file.writeAsString(jsonEncode(backupData));
      print('✅ Локальный бэкап создан: $backupPath');
    } catch (e) {
      print('❌ Ошибка создания бэкапа: $e');
    }
  }

  Future<bool> restoreFromLocalBackup() async {
    try {
      final backupPath = await getBackupFilePath();
      final file = File(backupPath);
      if (!await file.exists()) {
        print('Бэкап-файл не найден');
        return false;
      }

      final backupJson = await file.readAsString();
      final data = jsonDecode(backupJson) as Map<String, dynamic>;

      loadFromCloudJson(data);

      // === НОВОЕ: Сбрасываем кэши после восстановления ===
      invalidateWateringDatesCache();
      invalidateFertilizationDatesCache();

      print('✅ Данные успешно восстановлены из локального бэкапа');
      await savePlants();
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Ошибка восстановления из бэкапа: $e');
      return false;
    }
  }

  // === ЛЕНИВОЕ СКАЧИВАНИЕ ФОТО БЕЗ ИЗМЕНЕНИЯ userPhotos ===
  Future<void> ensureLocalPhotosExist() async {
    if (_isEnsuringPhotos) {
      print('⏸️ ensureLocalPhotosExist уже выполняется, пропускаем');
      return;
    }
    
    _isEnsuringPhotos = true;
    try {
      final photosDir = await _getPhotosDirectory();
      int cachedCount = 0;

      print(
          '🔄 ensureLocalPhotosExist (prefetch cache) запущен для ${_plants.length} растений');

      for (final plant in _plants) {
        for (var photo in plant.userPhotos) {
          if (!photo.startsWith('http://') && !photo.startsWith('https://')) {
            continue;
          }
          try {
            final baseName = path.basename(photo.split('?').first);
            final cacheFileName = 'cloud_${photo.hashCode.abs()}_$baseName';
            final localPath = path.join(photosDir, cacheFileName);
            final cachedFile = File(localPath);
            if (await cachedFile.exists()) {
              continue;
            }
            
            // Валидируем доступность cloud URL перед скачиванием
            if (!await _validateCloudUrl(photo)) {
              print('⚠️ Cloud URL недоступен, пропускаем: $photo');
              continue;
            }
            
            // Используем retry механизм для скачивания
            await _downloadPhotoWithRetry(photo, localPath);
            cachedCount++;
          } catch (e) {
            print('⚠️ Не удалось закешировать облачное фото $photo: $e');
          }
        }
      }

      print('✅ Prefetch завершён, новых закешированных фото: $cachedCount');
      
      // Запускаем очистку старого кэша
      _cleanupOldCache();
    } finally {
      _isEnsuringPhotos = false;
    }
  }
  
  /// Очищает старый кэш фото (старше 30 дней)
  Future<void> _cleanupOldCache() async {
    try {
      final photosDir = await _getPhotosDirectory();
      final dir = Directory(photosDir);
      if (!await dir.exists()) return;
      
      final files = await dir.list().toList();
      int deletedCount = 0;
      
      for (var file in files) {
        if (file is File && file.path.contains('cloud_')) {
          final stat = await file.stat();
          // Удалять кэш старше 30 дней
          if (DateTime.now().difference(stat.modified).inDays > 30) {
            await file.delete();
            deletedCount++;
            print('🗑️ Удален старый кэш: ${file.path}');
          }
        }
      }
      
      if (deletedCount > 0) {
        print('🧹 Очистка кэша завершена: удалено $deletedCount старых файлов');
      }
    } catch (e) {
      print('⚠️ Ошибка очистки кэша: $e');
    }
  }
  
  /// Скачивает фото с retry механизмом
  Future<void> _downloadPhotoWithRetry(String url, String localPath) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await File(localPath).writeAsBytes(response.bodyBytes);
          return;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (attempt == 2) {
          rethrow;
        }
        print('🔄 Попытка ${attempt + 1} для скачивания $url не удалась: $e');
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }
  }
  
  /// Валидирует доступность cloud URL
  Future<bool> _validateCloudUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Автоматическая очистка локальных фото после загрузки из облака
  Future<void> cleanupLocalPhotosAfterCloudLoad() async {
    final photosDir = await _getPhotosDirectory();
    final dir = Directory(photosDir);
    if (!await dir.exists()) return;

    final usedPaths = <String>{};
    for (var plant in _plants) {
      for (var photo in plant.userPhotos) {
        if (!photo.startsWith('https://')) {
          usedPaths.add(photo);
        }
      }
    }

    int deletedCount = 0;
    final allFiles = await dir.list().toList();

    for (var entity in allFiles) {
      if (entity is! File) continue;
      final fileName = path.basename(entity.path);
      final isCloudCacheFile = fileName.startsWith('cloud_');
      if (!usedPaths.contains(entity.path) && !isCloudCacheFile) {
        try {
          await entity.delete();
          deletedCount++;
        } catch (e) {
          print('⚠️ Не удалось удалить старое фото: ${entity.path}');
        }
      }
    }

    if (deletedCount > 0) {
      print(
          '🧹 Автоочистка после синхронизации: удалено $deletedCount старых фото');
    }
  }

  // === НОВЫЙ МЕТОД: Очистка неиспользуемых фото (локально + облако) ===
  Future<void> cleanupUnusedPhotos(BuildContext context) async {
    await createLocalBackup(); // ОБЯЗАТЕЛЬНЫЙ БЭКАП

    final photosDir = await _getPhotosDirectory();
    final dir = Directory(photosDir);

    if (!await dir.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Папка с фото не найдена')),
        );
      }
      return;
    }

    final allLocalFiles = await dir.list().toList();
    final usedPaths = <String>{};

    // Собираем все используемые локальные пути
    for (var plant in _plants) {
      for (var photo in plant.userPhotos) {
        if (!photo.startsWith('https://')) {
          usedPaths.add(photo);
        }
      }
    }

    int deletedCount = 0;
    for (var fileEntity in allLocalFiles) {
      if (fileEntity is File && !usedPaths.contains(fileEntity.path)) {
        try {
          await fileEntity.delete();
          deletedCount++;
        } catch (e) {
          print('⚠️ Не удалось удалить файл ${fileEntity.path}: $e');
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑 Локально удалено фото: $deletedCount'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    notifyListeners();
  }

  // === ОЧЕНЬ ОПАСНЫЙ МЕТОД: Полная очистка ВСЕХ фото ===
  Future<void> deleteAllPhotos(BuildContext context) async {
    await createLocalBackup();

    // Очистка локальных файлов
    final photosDir = await _getPhotosDirectory();
    final dir = Directory(photosDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create();
    }

    // Очистка ссылок в растениях + adult кэш
    for (int i = 0; i < _plants.length; i++) {
      final plant = _plants[i];
      if (plant.userPhotos.isNotEmpty) {
        _plants[i] = plant.copyWith(userPhotos: []);
        _adultImages.remove(plant.permanentId); // сброс adult
      }
    }

    _hasUnsavedChanges = true;
    await savePlants();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑 Все фото удалены локально и из растений'),
          backgroundColor: Colors.red,
        ),
      );
    }

    notifyListeners();
  }

  // Очистка неиспользуемых фото только у выбранных растений
  Future<void> cleanupUnusedPhotosForSelected(
      Set<String> selectedIds, BuildContext context) async {
    await createLocalBackup();

    final photosDir = await _getPhotosDirectory();
    final dir = Directory(photosDir);
    if (!await dir.exists()) return;

    final usedPaths = <String>{};

    for (var plant in _plants) {
      if (selectedIds.contains(plant.permanentId)) {
        for (var photo in plant.userPhotos) {
          if (!photo.startsWith('https://')) {
            usedPaths.add(photo);
          }
        }
      }
    }

    int deletedCount = 0;
    final allLocalFiles = await dir.list().toList();

    for (var fileEntity in allLocalFiles) {
      if (fileEntity is File && !usedPaths.contains(fileEntity.path)) {
        try {
          await fileEntity.delete();
          deletedCount++;
        } catch (e) {
          print('⚠️ Не удалось удалить: ${fileEntity.path}');
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('🗑 У выбранных растений удалено фото: $deletedCount')),
      );
    }
  }

  // Полная очистка ВСЕХ фото у выбранных растений + сброс adult кэша
  Future<void> deleteAllPhotosForSelected(
      Set<String> selectedIds, BuildContext context) async {
    await createLocalBackup();

    for (var id in selectedIds) {
      final index = _plants.indexWhere((p) => p.permanentId == id);
      if (index != -1) {
        // Очищаем userPhotos
        _plants[index] = _plants[index].copyWith(userPhotos: []);

        // Сбрасываем adult image кэш для этого растения
        _adultImages.remove(id);
      }
    }

    _hasUnsavedChanges = true;
    await savePlants();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑 Все фото у выбранных растений удалены'),
          backgroundColor: Colors.red,
        ),
      );
    }

    notifyListeners();
  }

  // ==================== МЕТОДЫ ДЛЯ СИСТЕМЫ ПАРТИЙ ====================

  /// Находит следующий свободный номер для сеянца в партии
  int getNextSeedlingNumber(String batchDisplayId) {
    final existingNumbers = <int>{};
    for (var plant in _plants) {
      if (plant.parentId != null && plant.displayId.startsWith('$batchDisplayId-')) {
        final suffix = plant.displayId.substring(batchDisplayId.length + 1);
        final number = int.tryParse(suffix);
        if (number != null) existingNumbers.add(number);
      }
    }
    int nextNumber = 1;
    while (existingNumbers.contains(nextNumber)) {
      nextNumber++;
    }
    return nextNumber;
  }

  /// Преобразует растение в партию (витрину) с сеянцами
  /// Вызывается при нажатии кнопки "Преобразовать в партию"
  Future<void> convertToBatch(String plantId, BuildContext context) async {
    final batchIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (batchIndex == -1) return;

    final batch = _plants[batchIndex];
    final aliveCount = batch.getCurrentAliveCount;

    if (aliveCount < 2) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужно минимум 2 живых растения для создания партии')),
        );
      }
      return;
    }

    await createLocalBackup();

    final newChildrenIds = <String>[];

    // Создаём сеянцев
    for (int i = 0; i < aliveCount; i++) {
      final seedlingNumber = getNextSeedlingNumber(batch.displayId);
      final seedlingDisplayId = Plant.generateSeedlingDisplayId(batch.displayId, seedlingNumber);

      // Создаём сеянец с наследованием всех данных от витрины
      final seedling = Plant(
        latinName: batch.latinName,
        status: 'growing', // Сеянцы всегда в статусе "растёт"
        year: batch.year,
        customNumber: batch.customNumber,
        category: batch.category,
        country: batch.country,
        habitat: batch.habitat,
        description: batch.description,
        synonyms: batch.synonyms,
        careTips: batch.careTips,
        floweringPeriod: batch.floweringPeriod,
        countryFlag: batch.countryFlag,
        // Наследуем все истории и данные
        wateringDates: List<DateTime>.from(batch.wateringDates),
        customWateringDates: List<DateTime>.from(batch.customWateringDates),
        germinationHistory: batch.germinationHistory.map((g) => GerminationRecord(
          date: g.date,
          germinatedCount: g.germinatedCount,
          deadCount: g.deadCount,
        )).toList(),
        floweringHistory: batch.floweringHistory.map((f) => FloweringRecord(
          date: f.date,
          event: f.event,
        )).toList(),
        notes: batch.notes.map((n) => Note(
          id: n.id,
          title: n.title,
          text: n.text,
          createdAt: n.createdAt,
        )).toList(),
        userPhotos: List<String>.from(batch.userPhotos),
        lliflePhotoUrls: List<String>.from(batch.lliflePhotoUrls),
        gbifPhotoUrls: List<String>.from(batch.gbifPhotoUrls),
        gbifOccurrences: batch.gbifOccurrences.map((o) => GbifOccurrence(
          latitude: o.latitude,
          longitude: o.longitude,
          country: o.country,
          locality: o.locality,
          habitat: o.habitat,
          coordinateUncertainty: o.coordinateUncertainty,
          year: o.year,
          month: o.month,
          day: o.day,
        )).toList(),
        fieldNumber: batch.fieldNumber,
        seller: batch.seller,
        harvestYear: batch.harvestYear,
        lastFertilization: batch.lastFertilization,
        plannedFertilizationDate: batch.plannedTransplantDate,
        lastRepotting: batch.lastRepotting,
        plannedTransplantDate: batch.plannedTransplantDate,
        lastGbifUpdate: batch.lastGbifUpdate,
        aliveCount: 1, // У сеянца всегда 1 живое (сам он)
        parentId: batch.permanentId, // Ссылка на витрину
      );

      // Устанавливаем правильный displayId и добавляем в список
      seedling.displayId = seedlingDisplayId;
      _plants.add(seedling);
      newChildrenIds.add(seedling.permanentId);
    }

    // Обновляем витрину
    _plants[batchIndex] = batch.copyWith(
      isBatch: true,
      childrenIds: newChildrenIds,
      lastModified: DateTime.now(),
    );

    _hasUnsavedChanges = true;
    await savePlants();
    notifyListeners();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Создано партию с $aliveCount сеянцами')),
      );
    }
  }

  /// Получает список сеянцев для витрины
  List<Plant> getBatchSeedlings(String batchId) {
    final batch = _plants.firstWhere(
      (p) => p.permanentId == batchId,
      orElse: () => throw Exception('Batch not found'),
    );
    if (!batch.isBatch) return [];

    final seedlings = <Plant>[];
    for (var childId in batch.childrenIds) {
      final seedlingIndex = _plants.indexWhere((p) => p.permanentId == childId);
      if (seedlingIndex != -1) {
        final seedling = _plants[seedlingIndex];
        if (seedling.parentId == batchId) {
          seedlings.add(seedling);
        }
      }
    }
    // Сортируем по displayId
    seedlings.sort((a, b) => a.displayId.compareTo(b.displayId));
    return seedlings;
  }

  /// Удаляет сеянец из партии
  /// Если остаётся 1 сеянец — преобразует партию обратно в обычное растение
  Future<void> removeSeedlingFromBatch(String batchId, String seedlingId, BuildContext context) async {
    final batchIndex = _plants.indexWhere((p) => p.permanentId == batchId);
    if (batchIndex == -1) return;

    final batch = _plants[batchIndex];
    if (!batch.isBatch || !batch.childrenIds.contains(seedlingId)) return;

    await createLocalBackup();

    // Удаляем сеянец из списка
    final updatedChildrenIds = batch.childrenIds.where((id) => id != seedlingId).toList();
    final newAliveCount = updatedChildrenIds.length;

    // Удаляем запись сеянца
    _plants.removeWhere((p) => p.permanentId == seedlingId);

    if (newAliveCount == 1) {
      // Обратное преобразование: партия → одно растение
      if (context.mounted) {
        await _mergeBatchBackToPlant(batchId, updatedChildrenIds.first, context);
      }
    } else {
      // Обновляем витрину
      _plants[batchIndex] = batch.copyWith(
        childrenIds: updatedChildrenIds,
        aliveCount: newAliveCount,
        lastModified: DateTime.now(),
      );
      _hasUnsavedChanges = true;
      await savePlants();
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сеянец удалён. Осталось: $newAliveCount')),
        );
      }
    }
  }

  /// Обратное преобразование: партия → одно растение
  /// Вызывается автоматически когда остаётся 1 сеянец
  Future<void> _mergeBatchBackToPlant(String batchId, String remainingSeedlingId, BuildContext context) async {
    final batchIndex = _plants.indexWhere((p) => p.permanentId == batchId);
    if (batchIndex == -1) return;

    final batch = _plants[batchIndex];
    final seedlingIndex = _plants.indexWhere((p) => p.permanentId == remainingSeedlingId);
    if (seedlingIndex == -1) return;

    final seedling = _plants[seedlingIndex];

    // Сливаем данные сеянца в витрину
    // permanentId витрины остаётся старым (важно для синхронизации!)
    _plants[batchIndex] = batch.copyWith(
      isBatch: false,
      childrenIds: [],
      aliveCount: 1,
      // Наследуем данные от сеянца (они актуальнее)
      wateringDates: seedling.wateringDates,
      customWateringDates: seedling.customWateringDates,
      notes: seedling.notes,
      userPhotos: seedling.userPhotos,
      lastModified: DateTime.now(),
    );

    // Удаляем запись сеянца
    _plants.removeAt(seedlingIndex);

    _hasUnsavedChanges = true;
    await savePlants();
    notifyListeners();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Партия преобразована в обычное растение ${seedling.displayId}')),
      );
    }
  }

  /// Удаление витрины с отвязыванием сеянцев
  /// Сеянцы становятся обычными растениями (parentId = null)
  Future<void> deleteBatchWithOrphans(String batchId, BuildContext context) async {
    final batchIndex = _plants.indexWhere((p) => p.permanentId == batchId);
    if (batchIndex == -1) return;

    final batch = _plants[batchIndex];
    if (!batch.isBatch) return;

    await createLocalBackup();

    // Отвязываем всех сеянцев
    for (var childId in batch.childrenIds) {
      final seedlingIndex = _plants.indexWhere((p) => p.permanentId == childId);
      if (seedlingIndex != -1) {
        _plants[seedlingIndex] = _plants[seedlingIndex].copyWith(
          parentId: null,
          lastModified: DateTime.now(),
        );
      }
    }

    // Удаляем витрину
    _plants.removeAt(batchIndex);

    _hasUnsavedChanges = true;
    await savePlants();
    notifyListeners();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Витрина удалена. ${batch.childrenIds.length} сеянцев стали самостоятельными растениями'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Полная очистка всех кэшей после загрузки из облака
  void invalidateAllCaches() {
    print('🔄 Полный сброс всех кэшей после загрузки из облака');
    _individualWateringDatesCache = {};
    _customWateringDatesCache = {};
    _recommendedWateringDatesCache = [];
    _fertilizationDatesCache = {};
    _plannedFertilizationDatesCache = {};
    notifyListeners();
  }
}

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
      date: DateTime.parse(json['date']),
      description: json['description'],
    );
  }
}
