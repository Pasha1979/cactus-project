import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_constants.dart';
import '../../core/ui/ui_state.dart';
import '../../domain/repositories/plant_repository.dart';
import '../../injection_container.dart';
import '../../models/gbif_occurrence.dart';
import '../../models/plant.dart';
import '../../models/qr_code.dart';
import 'photo_provider.dart';
import 'wintering_provider.dart' show WinteringLogEntry;

/// Провайдер для CRUD операций с растениями
///
/// Отвечает за:
/// - Загрузку/сохранение списка растений
/// - Добавление/обновление/удаление растений
/// - Выбор растений (multi-select)
/// - Уникальные номера и валидацию
/// - Базовую статистику
class PlantCrudProvider with ChangeNotifier {
  final PlantRepository _repository = sl<PlantRepository>();

  List<Plant> _plants = [];
  final Set<String> _selectedIds = {};
  UiState<List<Plant>> _plantsState = const UiLoading();
  DateTime? _lastLocalUpdate;
  final Set<String> _deletedUserPhotos = {};
  final Set<String> _deletedLliflePhotos = {};
  Map<String, String?> _adultImages = {};
  bool _hasUnsavedChanges = false;

  // Legacy-поля для обратной совместимости облачной синхронизации
  // (хранятся здесь для toJson/loadFromCloudJson, UI использует специализированные провайдеры)
  List<DateTime> _globalWateringDates = [];
  DateTime? _winteringStartDate;
  DateTime? _winteringEndDate;
  double? _winteringTemperature;
  List<WinteringLogEntry> _winteringLogEntries = [];

  // ==================== ГЕТТЕРЫ ====================
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  List<Plant> get plants => List.unmodifiable(_plants);
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  bool get isLoading => _plantsState is UiLoading;
  UiState<List<Plant>> get plantsState => _plantsState;
  bool get hasSelection => _selectedIds.isNotEmpty;
  int get plantCount => _plants.length;
  DateTime? get lastLocalUpdate => _lastLocalUpdate;
  Set<String> get deletedUserPhotos => _deletedUserPhotos;
  Set<String> get deletedLliflePhotos => _deletedLliflePhotos;
  String? getAdultImage(String plantId) => _adultImages[plantId];

  // Legacy-геттеры для обратной совместимости
  List<DateTime> get globalWateringDates => List.unmodifiable(_globalWateringDates);
  Map<String, String?> get adultImages => Map.unmodifiable(_adultImages);
  DateTime? get winteringStartDate => _winteringStartDate;
  DateTime? get winteringEndDate => _winteringEndDate;
  double? get winteringTemperature => _winteringTemperature;
  List<WinteringLogEntry> get winteringLogEntries => List.unmodifiable(_winteringLogEntries);

  // ==================== ОБЛАЧНАЯ СИНХРОНИЗАЦИЯ (legacy) ====================

  void setLastLocalUpdate(DateTime date) {
    _lastLocalUpdate = date;
    notifyListeners();
  }

  void markUserPhotoAsDeleted(String photoUrl) {
    _deletedUserPhotos.add(photoUrl);
  }

  void markLliflePhotoAsDeleted(String photoUrl) {
    _deletedLliflePhotos.add(photoUrl);
  }

  void clearDeletedPhotos() {
    _deletedUserPhotos.clear();
    _deletedLliflePhotos.clear();
  }

  Future<String> getBackupFilePath() async {
    final photosDir = await _getPhotosDirectory();
    return '$photosDir/plant_provider_backup.json';
  }

  Future<void> createLocalBackup() async {
    try {
      final backupPath = await getBackupFilePath();
      final backupData = {
        'plants': _plants.map((p) => p.toJson()).toList(),
        'lastLocalUpdate': _lastLocalUpdate?.toIso8601String(),
      };
      final file = File(backupPath);
      await file.writeAsString(jsonEncode(backupData));
      debugPrint('✅ Локальный бэкап создан: $backupPath');
    } catch (e) {
      debugPrint('❌ Ошибка создания бэкапа: $e');
    }
  }

  /// Очистить неиспользуемые фото у выбранных растений.
  /// Делегирует к PhotoProvider.cleanupUnusedPhotosForSelected.
  Future<void> cleanupUnusedPhotosForSelected(
      Set<String> selectedIds, BuildContext context) async {
    await createLocalBackup();

    final photoProvider = sl<PhotoProvider>();
    final deletedCount = await photoProvider.cleanupUnusedPhotosForSelected(
      _plants,
      selectedIds,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('🗑 У выбранных растений удалено фото: $deletedCount')),
      );
    }
  }

  /// Удалить все фото у выбранных растений.
  /// Делегирует удаление файлов к PhotoProvider, обновляет Plant модели.
  Future<void> deleteAllPhotosForSelected(
      Set<String> selectedIds, BuildContext context) async {
    await createLocalBackup();

    final photoProvider = sl<PhotoProvider>();
    final updatedIds = await photoProvider.deleteAllPhotosForSelected(
      _plants,
      selectedIds,
    );

    for (var id in updatedIds) {
      final index = _plants.indexWhere((p) => p.permanentId == id);
      if (index == -1) continue;
      _plants[index] = _plants[index].copyWith(userPhotos: []);
      _adultImages.remove(id);
      try {
        await _repository.updatePlant(_plants[index]);
      } catch (e) {
        debugPrint('Ошибка удаления фото: $e');
      }
    }

    if (updatedIds.isNotEmpty) {
      _hasUnsavedChanges = true;
      notifyListeners();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑 Все фото у выбранных растений удалены'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
          debugPrint('⚠️ Не удалось удалить старое фото: ${entity.path}');
        }
      }
    }
    if (deletedCount > 0) {
      debugPrint('🧹 Автоочистка: удалено $deletedCount старых фото');
    }
  }

  void invalidateAllCaches() {
    _individualWateringDatesCache = {};
    _customWateringDatesCache = {};
    _fertilizationDatesCache = {};
    _plannedFertilizationDatesCache = {};
    notifyListeners();
  }

  /// Сериализация для облачной синхронизации (legacy — содержит
  /// поля из разных провайдеров для обратной совместимости)
  Map<String, dynamic> toJson() => {
        'plants': _plants.map((p) => p.toJson()).toList(),
        'lastLocalUpdate': _lastLocalUpdate?.toIso8601String(),
        'globalWateringDates': _globalWateringDates.map((d) => d.toIso8601String()).toList(),
        'adultImages': _adultImages,
        'winteringStartDate': _winteringStartDate?.toIso8601String(),
        'winteringEndDate': _winteringEndDate?.toIso8601String(),
        'winteringTemperature': _winteringTemperature,
        'winteringLogEntries': _winteringLogEntries.map((e) => e.toJson()).toList(),
      };

  /// Загрузка из облачного JSON с полным слиянием данных
  Future<void> loadFromCloudJson(Map<String, dynamic> data) async {
    debugPrint(
        '🔄 loadFromCloudJson — загружаем ${data['plants']?.length ?? 0} растений из облака');

    final plantsJson = data['plants'] as List<dynamic>? ?? [];
    final cloudPlants = <Plant>[];

    for (var json in plantsJson) {
      try {
        final plant = Plant.fromJson(json as Map<String, dynamic>);
        cloudPlants.add(plant);
      } catch (e) {
        debugPrint('❌ Ошибка загрузки растения из облака: $e');
      }
    }

    // Сливаем с локальными данными
    final mergedPlants = <Plant>[];

    for (var cloudPlant in cloudPlants) {
      final localIndex = _plants.indexWhere((p) => p.permanentId == cloudPlant.permanentId);
      if (localIndex != -1) {
        final merged = _mergePlantData(_plants[localIndex], cloudPlant);
        mergedPlants.add(merged);
        debugPrint('✅ Слияние: ${merged.latinName}');
      } else {
        mergedPlants.add(cloudPlant);
        debugPrint('➕ Новое из облака: ${cloudPlant.latinName}');
      }
    }

    for (var localPlant in _plants) {
      final existsInCloud = cloudPlants.any((p) => p.permanentId == localPlant.permanentId);
      if (!existsInCloud) {
        mergedPlants.add(localPlant);
        debugPrint('💾 Только локальное: ${localPlant.latinName}');
      }
    }

    // Сохраняем mergedPlants в Hive ДО обновления _plants
    // (если сохранение упадёт, _plants останется в согласованном состоянии)
    for (final plant in mergedPlants) {
      try {
        await _repository.updatePlant(plant);
      } catch (e) {
        debugPrint('❌ Ошибка сохранения растения в Hive после merge: $e');
      }
    }

    _plants = mergedPlants;

    _globalWateringDates = (data['globalWateringDates'] as List<dynamic>?)
            ?.map((d) => DateTime.tryParse(d as String))
            .whereType<DateTime>()
            .toList() ??
        [];

    _adultImages = Map<String, String?>.from(data['adultImages'] ?? {});

    _lastLocalUpdate = data['lastLocalUpdate'] != null
        ? DateTime.tryParse(data['lastLocalUpdate'] as String)
        : null;

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

    // Сохраняем legacy-поля в SharedPreferences
    await _saveLegacyData();

    debugPrint('✅ Загружено и сохранено ${_plants.length} растений из облака');

    await sl<PhotoProvider>().ensureLocalPhotosExist(_plants);
    cleanupLocalPhotosAfterCloudLoad();
    invalidateAllCaches();
    notifyListeners();
  }

  // ==================== LEGACY PERSISTENCE ====================
  /// Перезагрузка legacy-полей из SharedPreferences перед облачной синхронизацией.
  ///
  /// Необходима потому что WateringProvider, WinteringProvider и PhotoProvider
  /// сохраняют свои данные независимо в SharedPreferences.
  Future<void> reloadLegacyData() async => _loadLegacyData();

  /// Загрузка legacy-полей из SharedPreferences
  Future<void> _loadLegacyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Global watering dates
      final gwJson = prefs.getStringList(PrefsKeys.globalWateringDates);
      if (gwJson != null) {
        _globalWateringDates = gwJson
            .map((s) => DateTime.tryParse(s))
            .whereType<DateTime>()
            .toList();
      } else {
        _globalWateringDates = [];
      }

      // Adult images
      final adultJson = prefs.getString(PrefsKeys.adultImages);
      if (adultJson != null) {
        final decoded = jsonDecode(adultJson) as Map<String, dynamic>?;
        if (decoded != null) {
          _adultImages = decoded.map((k, v) => MapEntry(k, v as String?));
        }
      } else {
        _adultImages = {};
      }

      // Wintering
      final ws = prefs.getString(PrefsKeys.winteringStart);
      _winteringStartDate = ws != null ? DateTime.tryParse(ws) : null;

      final we = prefs.getString(PrefsKeys.winteringEnd);
      _winteringEndDate = we != null ? DateTime.tryParse(we) : null;

      _winteringTemperature = prefs.getDouble(PrefsKeys.winteringTemp);

      final wlJson = prefs.getStringList(PrefsKeys.winteringLog);
      if (wlJson != null) {
        _winteringLogEntries = wlJson
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
        _winteringLogEntries = [];
      }

      debugPrint('✅ Legacy-данные загружены: '
          'поливов=${_globalWateringDates.length}, '
          'adultImages=${_adultImages.length}, '
          'зимовка=$_winteringStartDate–$_winteringEndDate');
    } catch (e) {
      debugPrint('❌ Ошибка загрузки legacy-данных: $e');
      _globalWateringDates = [];
      _adultImages = {};
      _winteringStartDate = null;
      _winteringEndDate = null;
      _winteringTemperature = null;
      _winteringLogEntries = [];
    }
  }

  /// Сохранение legacy-полей в SharedPreferences
  Future<void> _saveLegacyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setStringList(
        PrefsKeys.globalWateringDates,
        _globalWateringDates.map((d) => d.toIso8601String()).toList(),
      );

      await prefs.setString(
        PrefsKeys.adultImages,
        jsonEncode(_adultImages),
      );

      await prefs.setString(
        PrefsKeys.winteringStart,
        _winteringStartDate?.toIso8601String() ?? '',
      );
      await prefs.setString(
        PrefsKeys.winteringEnd,
        _winteringEndDate?.toIso8601String() ?? '',
      );
      if (_winteringTemperature != null) {
        await prefs.setDouble(PrefsKeys.winteringTemp, _winteringTemperature!);
      } else {
        await prefs.remove(PrefsKeys.winteringTemp);
      }

      await prefs.setStringList(
        PrefsKeys.winteringLog,
        _winteringLogEntries.map((e) => jsonEncode(e.toJson())).toList(),
      );

      debugPrint('✅ Legacy-данные сохранены');
    } catch (e) {
      debugPrint('❌ Ошибка сохранения legacy-данных: $e');
    }
  }

  // ==================== CRUD ====================
  Future<void> loadPlants() async {
    _plantsState = const UiLoading();
    notifyListeners();

    try {
      _plants = await _repository.getAllPlants();
      await _loadLegacyData();
      _plantsState = UiSuccess(List.unmodifiable(_plants));
    } catch (e) {
      debugPrint('Ошибка загрузки растений: $e');
      _plants = [];
      _plantsState = UiError(
        'Ошибка загрузки растений: $e',
        onRetry: loadPlants,
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> addPlant(Plant plant) async {
    final plantWithTime = plant.copyWith(lastModified: DateTime.now());
    try {
      await _repository.addPlant(plantWithTime);
      _plants.add(plantWithTime);
      _plantsState = UiSuccess(List.unmodifiable(_plants));
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка добавления растения: $e');
    }
  }

  Future<void> updatePlant(String id, Plant updatedPlant) async {
    final index = _plants.indexWhere((p) => p.permanentId == id);
    if (index == -1) return;

    try {
      await _repository.updatePlant(updatedPlant);
      _plants[index] = updatedPlant;
      _plantsState = UiSuccess(List.unmodifiable(_plants));
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка обновления растения: $e');
    }
  }

  Future<void> deletePlant(String id) async {
    try {
      await _repository.deletePlant(id);
      _plants.removeWhere((p) => p.permanentId == id);
      _plantsState = UiSuccess(List.unmodifiable(_plants));
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка удаления растения: $e');
    }
  }

  List<Plant> getPlantsWithQRCode() {
    return _plants.where((p) => p.qrCode != null && p.qrCode!.isActive).toList();
  }

  List<Plant> getPlantsWithoutQRCode() {
    return _plants.where((p) => p.qrCode == null || !p.qrCode!.isActive).toList();
  }

  Plant? getPlantById(String permanentId) {
    try {
      return _plants.firstWhere((p) => p.permanentId == permanentId);
    } catch (_) {
      return null;
    }
  }

  // ==================== ВЫБОР ====================
  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    _selectedIds.addAll(ids);
    notifyListeners();
  }

  void clearSelections() {
    _selectedIds.clear();
    notifyListeners();
  }

  // ==================== ПОМОЩНИКИ ====================
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

  List<int> getUniqueSowingYears() {
    return _plants
        .where((p) => p.category == 'sown')
        .map((p) => p.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  int getPlantCountForYear(int year) {
    return _plants
        .where((p) => p.category == 'sown' && p.year == year)
        .length;
  }

  Map<String, int> get statusDistribution {
    return {
      'В коллекции': _plants.where((p) => p.status == 'in_collection').length,
      'Растёт': _plants.where((p) => p.status == 'growing').length,
      'Погиб': _plants.where((p) => p.status == 'dead').length,
      'Не взошел': _plants.where((p) => p.status == 'failed').length,
    };
  }

  /// Сохранение legacy-данных в SharedPreferences
  ///
  /// В новой архитектуре растения сохраняются в Hive автоматически,
  /// но globalWateringDates, adultImages, wintering* — пока ещё в SharedPreferences.
  Future<void> savePlants() async {
    try {
      await _saveLegacyData();
      _plantsState = UiSuccess(List.unmodifiable(_plants));
    } catch (e) {
      debugPrint('Ошибка сохранения данных: $e');
      _plantsState = UiError(
        'Ошибка сохранения данных: $e',
        onRetry: savePlants,
      );
    } finally {
      notifyListeners();
    }
  }

  /// Есть ли непрочитанные уведомления
  bool get hasUnreadNotifications {
    return _plants.any((plant) => plant.hasUnreadNotification);
  }

  /// Очистить все уведомления
  Future<void> clearNotifications() async {
    for (var i = 0; i < _plants.length; i++) {
      if (_plants[i].hasUnreadNotification) {
        final updated = _plants[i].copyWith(hasUnreadNotification: false);
        _plants[i] = updated;
        try {
          await _repository.updatePlant(updated);
        } catch (e) {
          debugPrint('Ошибка очистки уведомления: $e');
        }
      }
    }
    notifyListeners();
  }

  /// Создать QR-код для одного растения
  Future<void> createQRCode(String plantId) async {
    final index = _plants.indexWhere((p) => p.permanentId == plantId);
    if (index == -1) return;
    final plant = _plants[index];
    if (plant.qrCode != null) return;

    final qrCode = QRCode(
      plantId: plant.displayId,
      plantName: plant.latinName,
      permanentId: plant.permanentId,
      createdAt: DateTime.now(),
    );
    final updated = plant.copyWith(qrCode: qrCode);
    _plants[index] = updated;
    try {
      await _repository.updatePlant(updated);
    } catch (e) {
      debugPrint('Ошибка создания QR-кода: $e');
    }
    notifyListeners();
  }

  /// Массовое создание QR-кодов для выбранных растений
  Future<void> createQRCodeBatch(Set<String> plantIds) async {
    for (final plantId in plantIds) {
      final index = _plants.indexWhere((p) => p.permanentId == plantId);
      if (index == -1) continue;

      final plant = _plants[index];
      if (plant.qrCode == null || !plant.qrCode!.isActive) {
        final newQRCode = QRCode.createNew(
          plantId: plant.displayId,
          plantName: plant.latinName,
        );
        final updated = plant.copyWith(qrCode: newQRCode);
        _plants[index] = updated;
        try {
          await _repository.updatePlant(updated);
        } catch (e) {
          debugPrint('Ошибка обновления QR-кода: $e');
        }
      }
    }
    notifyListeners();
  }

  // ==================== ГРУППОВЫЕ ОПЕРАЦИИ ====================
  Future<void> updateMultipleStatus(String newStatus) async {
    final updated = _plants.map((plant) {
      return _selectedIds.contains(plant.permanentId)
          ? plant.copyWith(
              status: newStatus,
              lastModified: DateTime.now(),
            )
          : plant;
    }).toList();
    _plants = updated;
    notifyListeners();

    for (final plant in _plants.where((p) => _selectedIds.contains(p.permanentId))) {
      await _repository.updatePlant(plant);
    }
  }

  Future<void> deleteMultiplePlants() async {
    for (final id in List<String>.from(_selectedIds)) {
      await deletePlant(id);
    }
    _selectedIds.clear();
  }

  // ==================== КЭШИ ПОЛИВОВ (для care_calendar) ====================

  Map<DateTime, List<Plant>> _individualWateringDatesCache = {};
  Map<DateTime, int> _customWateringDatesCache = {};

  Map<DateTime, List<Plant>> get individualWateringDates {
    if (_individualWateringDatesCache.isEmpty) {
      _individualWateringDatesCache = {};
      for (var plant in _plants) {
        for (var date in plant.wateringDates) {
          final normalized = DateTime(date.year, date.month, date.day);
          _individualWateringDatesCache[normalized] ??= [];
          _individualWateringDatesCache[normalized]!.add(plant);
        }
      }
    }
    return _individualWateringDatesCache;
  }

  Map<DateTime, int> get customWateringDates {
    if (_customWateringDatesCache.isEmpty) {
      _customWateringDatesCache = {};
      for (var plant in _plants) {
        for (var date in plant.customWateringDates) {
          final normalized = DateTime(date.year, date.month, date.day);
          _customWateringDatesCache[normalized] =
              (_customWateringDatesCache[normalized] ?? 0) + 1;
        }
      }
    }
    return _customWateringDatesCache;
  }

  /// Обновить рекомендованные даты поливов (legacy — в новой архитектуре
  /// рекомендации управляются WateringProvider)
  void updateRecommendedWateringDates() {
    // No-op: рекомендации теперь в WateringProvider
    notifyListeners();
  }

  // ==================== УДОБРЕНИЯ ====================

  /// Запланировать подкормку для группы растений
  Future<void> planGroupFertilization(Set<String> plantIds, DateTime date) async {
    for (var plantId in plantIds) {
      final index = _plants.indexWhere((p) => p.permanentId == plantId);
      if (index == -1) continue;
      final updated = _plants[index].copyWith(
        plannedFertilizationDate: date,
        lastModified: DateTime.now(),
      );
      _plants[index] = updated;
      try {
        await _repository.updatePlant(updated);
      } catch (e) {
        debugPrint('Ошибка обновления plannedFertilizationDate: $e');
      }
    }
    notifyListeners();
  }

  Map<DateTime, List<Plant>> _fertilizationDatesCache = {};
  Map<DateTime, List<Plant>> _plannedFertilizationDatesCache = {};

  Map<DateTime, List<Plant>> get fertilizationDates {
    if (_fertilizationDatesCache.isEmpty) {
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
      _plannedFertilizationDatesCache = {};
      for (var plant in _plants) {
        if (plant.plannedFertilizationDate != null) {
          final date = DateTime(plant.plannedFertilizationDate!.year,
              plant.plannedFertilizationDate!.month,
              plant.plannedFertilizationDate!.day);
          _plannedFertilizationDatesCache[date] ??= [];
          _plannedFertilizationDatesCache[date]!.add(plant);
        }
      }
    }
    return _plannedFertilizationDatesCache;
  }

  /// Сброс кэша дат удобрений
  void invalidateFertilizationDatesCache() {
    _fertilizationDatesCache = {};
    _plannedFertilizationDatesCache = {};
    notifyListeners();
  }

  // ==================== ПОЛИВЫ ====================

  /// Очистить данные поливов за конкретную дату
  Future<void> clearWateringDataForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    for (var i = 0; i < _plants.length; i++) {
      final plant = _plants[i];
      final updatedWatering = plant.wateringDates
          .where((d) => !_isSameDay(d, normalized))
          .toList();
      final updatedCustom = plant.customWateringDates
          .where((d) => !_isSameDay(d, normalized))
          .toList();
      if (updatedWatering.length != plant.wateringDates.length ||
          updatedCustom.length != plant.customWateringDates.length) {
        final updated = plant.copyWith(
          wateringDates: updatedWatering,
          customWateringDates: updatedCustom,
        );
        _plants[i] = updated;
        try {
          await _repository.updatePlant(updated);
        } catch (e) {
          debugPrint('Ошибка очистки поливов: $e');
        }
      }
    }
    notifyListeners();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Добавить дату полива для конкретного растения
  Future<void> addIndividualWateringDate(String plantId, DateTime date) async {
    final index = _plants.indexWhere((p) => p.permanentId == plantId);
    if (index == -1) return;
    final plant = _plants[index];
    final updated = plant.copyWith(
      wateringDates: [...plant.wateringDates, date],
    );
    _plants[index] = updated;
    try {
      await _repository.updatePlant(updated);
    } catch (e) {
      debugPrint('Ошибка добавления даты полива: $e');
    }
    notifyListeners();
  }

  /// Добавить Llifle фото к растению
  Future<void> addLliflePhoto(String plantId, String photoUrl) async {
    final index = _plants.indexWhere((p) => p.permanentId == plantId);
    if (index == -1) return;
    final updatedPhotos = List<String>.from(_plants[index].lliflePhotoUrls);
    if (updatedPhotos.contains(photoUrl)) return;
    updatedPhotos.add(photoUrl);
    final updated = _plants[index].copyWith(
      lliflePhotoUrls: updatedPhotos,
      lastModified: DateTime.now(),
    );
    _plants[index] = updated;
    try {
      await _repository.updatePlant(updated);
    } catch (e) {
      debugPrint('Ошибка добавления Llifle фото: $e');
    }
    notifyListeners();
  }

  // ==================== ЦВЕТЕНИЕ ====================

  /// Добавить событие цветения
  Future<void> addFloweringEvent(String plantId, DateTime date, String event) async {
    final index = _plants.indexWhere((p) => p.permanentId == plantId);
    if (index == -1) return;
    final updatedHistory =
        List<FloweringRecord>.from(_plants[index].floweringHistory)
          ..add(FloweringRecord(date: date, event: event));
    final updated = _plants[index].copyWith(
      floweringHistory: updatedHistory,
      lastModified: DateTime.now(),
    );
    _plants[index] = updated;
    try {
      await _repository.updatePlant(updated);
    } catch (e) {
      debugPrint('Ошибка добавления события цветения: $e');
    }
    notifyListeners();
  }

  /// Очистить данные о цветении
  Future<void> clearFloweringData(String plantId) async {
    final index = _plants.indexWhere((p) => p.permanentId == plantId);
    if (index == -1) return;
    final updated = _plants[index].copyWith(
      floweringHistory: [],
      lastModified: DateTime.now(),
    );
    _plants[index] = updated;
    try {
      await _repository.updatePlant(updated);
    } catch (e) {
      debugPrint('Ошибка очистки данных о цветении: $e');
    }
    notifyListeners();
  }

  /// Отметить группу растений как удобренную
  Future<void> markGroupAsFertilized(Set<String> plantIds, {DateTime? date}) async {
    for (final permanentId in plantIds) {
      await markAsFertilized(permanentId, date: date);
    }
  }

  /// Отметить растение как удобренное
  Future<void> markAsFertilized(String permanentId, {DateTime? date}) async {
    final index = _plants.indexWhere((p) => p.permanentId == permanentId);
    if (index == -1) return;
    final plant = _plants[index];
    final fertilizationDate = date ?? DateTime.now();
    final updated = plant.copyWith(
      lastFertilization: fertilizationDate,
      plannedFertilizationDate: null,
      lastModified: DateTime.now(),
    );
    _plants[index] = updated;
    try {
      await _repository.updatePlant(updated);
    } catch (e) {
      debugPrint('Ошибка отметки удобрения: $e');
    }
    notifyListeners();
  }

  // ==================== ПАРТИИ (BATCH) ====================

  /// Получить список сеянцев для витрины
  List<Plant> getBatchSeedlings(String batchId) {
    final batch = _plants.firstWhere(
      (p) => p.permanentId == batchId,
      orElse: () => Plant(
        permanentId: '',
        displayId: '',
        latinName: '',
        status: '',
        year: 0,
        customNumber: 0,
        category: '',
        isBatch: false,
      ),
    );
    if (!batch.isBatch || batch.permanentId.isEmpty) return [];

    final seedlings = <Plant>[];
    for (var childId in batch.childrenIds) {
      final index = _plants.indexWhere((p) => p.permanentId == childId);
      if (index == -1) continue;
      final seedling = _plants[index];
      if (seedling.parentId == batchId) {
        seedlings.add(seedling);
      }
    }
    seedlings.sort((a, b) => a.displayId.compareTo(b.displayId));
    return seedlings;
  }

  /// Удалить сеянец из партии
  Future<void> removeSeedlingFromBatch(String batchId, String seedlingId) async {
    final batchIndex = _plants.indexWhere((p) => p.permanentId == batchId);
    if (batchIndex == -1) return;

    final batch = _plants[batchIndex];
    if (!batch.isBatch || !batch.childrenIds.contains(seedlingId)) return;

    final updatedChildrenIds = batch.childrenIds.where((id) => id != seedlingId).toList();
    final newAliveCount = updatedChildrenIds.length;

    // Удаляем запись сеянца
    _plants.removeWhere((p) => p.permanentId == seedlingId);

    if (newAliveCount == 1) {
      // Обратное преобразование: партия → одно растение
      final remainingId = updatedChildrenIds.first;
      final remainingIndex = _plants.indexWhere((p) => p.permanentId == remainingId);
      if (remainingIndex != -1) {
        final remaining = _plants[remainingIndex];
        _plants[batchIndex] = batch.copyWith(
          isBatch: false,
          childrenIds: [],
          aliveCount: 1,
          lastModified: DateTime.now(),
        );
        _plants[remainingIndex] = remaining.copyWith(
          displayId: batch.displayId,
          parentId: null,
        );
        await _repository.updatePlant(_plants[batchIndex]);
        await _repository.updatePlant(_plants[remainingIndex]);
      }
    } else {
      _plants[batchIndex] = batch.copyWith(
        childrenIds: updatedChildrenIds,
        aliveCount: newAliveCount,
        lastModified: DateTime.now(),
      );
      await _repository.updatePlant(_plants[batchIndex]);
    }
    notifyListeners();
  }

  // ==================== ФОТО ====================

  /// Добавить пользовательское фото к растению
  Future<void> addUserPhoto(String plantId, String photoPath) async {
    final index = _plants.indexWhere((p) => p.permanentId == plantId);
    if (index == -1) return;
    try {
      final newPhotoPath = await _copyPhotoToAppStorage(photoPath);
      final updatedPhotos = List<String>.from(_plants[index].userPhotos)
        ..add(newPhotoPath);
      final updated = _plants[index].copyWith(
        userPhotos: updatedPhotos,
        lastModified: DateTime.now(),
      );
      _plants[index] = updated;
      await _repository.updatePlant(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка добавления фото: $e');
      rethrow;
    }
  }

  Future<String> _copyPhotoToAppStorage(String originalPath) async {
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
  }

  /// Преобразовать растение в партию (витрину) с сеянцами
  /// Возвращает количество созданных сеянцев или 0 если не удалось
  int convertToBatch(String plantId) {
    final batchIndex = _plants.indexWhere((p) => p.permanentId == plantId);
    if (batchIndex == -1) return 0;

    final batch = _plants[batchIndex];
    final aliveCount = batch.getCurrentAliveCount;

    if (aliveCount < 2) return 0;

    final newChildrenIds = <String>[];

    for (int i = 0; i < aliveCount; i++) {
      final seedlingNumber = _getNextSeedlingNumber(batch.displayId);
      final seedlingDisplayId = Plant.generateSeedlingDisplayId(batch.displayId, seedlingNumber);

      final seedling = Plant(
        latinName: batch.latinName,
        status: 'growing',
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
        plannedFertilizationDate: batch.plannedFertilizationDate,
        lastRepotting: batch.lastRepotting,
        plannedTransplantDate: batch.plannedTransplantDate,
        lastGbifUpdate: batch.lastGbifUpdate,
        aliveCount: 1,
        parentId: batch.permanentId,
      );

      seedling.displayId = seedlingDisplayId;
      _plants.add(seedling);
      newChildrenIds.add(seedling.permanentId);
    }

    _plants[batchIndex] = batch.copyWith(
      isBatch: true,
      childrenIds: newChildrenIds,
      lastModified: DateTime.now(),
    );

    notifyListeners();
    return aliveCount;
  }

  int _getNextSeedlingNumber(String batchDisplayId) {
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

  /// Удалить дату индивидуального полива
  Future<void> removeIndividualWateringDate(String plantId, DateTime date) async {
    final index = _plants.indexWhere((p) => p.permanentId == plantId);
    if (index == -1) return;
    final updatedDates = _plants[index]
        .wateringDates
        .where((d) =>
            d.year != date.year || d.month != date.month || d.day != date.day)
        .toList();
    final updated = _plants[index].copyWith(
      wateringDates: updatedDates,
    );
    _plants[index] = updated;
    try {
      await _repository.updatePlant(updated);
    } catch (e) {
      debugPrint('Ошибка удаления даты полива: $e');
    }
    notifyListeners();
  }

  /// Удалить пользовательское фото
  Future<void> removeUserPhoto(String plantId, String photoPath) async {
    final index = _plants.indexWhere((p) => p.permanentId == plantId);
    if (index == -1) return;
    final updatedPhotos = List<String>.from(_plants[index].userPhotos)
      ..remove(photoPath);
    final updated = _plants[index].copyWith(
      userPhotos: updatedPhotos,
      lastModified: DateTime.now(),
    );
    _plants[index] = updated;
    try {
      await _repository.updatePlant(updated);
      await _deletePhotoFromStorage(photoPath);
    } catch (e) {
      debugPrint('Ошибка удаления фото: $e');
    }
    notifyListeners();
  }

  /// Удалить Llifle фото
  Future<void> removeLliflePhoto(String plantId, String photoUrl) async {
    final index = _plants.indexWhere((p) => p.permanentId == plantId);
    if (index == -1) return;
    final updatedPhotos = List<String>.from(_plants[index].lliflePhotoUrls)
      ..remove(photoUrl);
    final updated = _plants[index].copyWith(
      lliflePhotoUrls: updatedPhotos,
      lastModified: DateTime.now(),
    );
    _plants[index] = updated;
    try {
      await _repository.updatePlant(updated);
    } catch (e) {
      debugPrint('Ошибка удаления Llifle фото: $e');
    }
    notifyListeners();
  }

  /// Делегирует prefetch облачных фото к PhotoProvider.
  Future<void> ensureLocalPhotosExist() async {
    await sl<PhotoProvider>().ensureLocalPhotosExist(_plants);
  }

  Future<void> _deletePhotoFromStorage(String photoPath) async {
    final file = File(photoPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> _getPhotosDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${directory.path}/plant_photos');
    if (!await photosDir.exists()) {
      await photosDir.create();
    }
    return photosDir.path;
  }

  /// Экспорт выбранных растений в CSV
  Future<void> exportSelectedToCSV(BuildContext context) async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите растения для экспорта')),
      );
      return;
    }

    try {
      final selectedPlants = _plants
          .where((p) => _selectedIds.contains(p.permanentId))
          .toList();

      final buffer = StringBuffer();
      buffer.writeln(
          'permanentId,displayId,latinName,status,year,customNumber,category');
      for (final plant in selectedPlants) {
        buffer.writeln(
            '${plant.permanentId},${plant.displayId},${plant.latinName},${plant.status},${plant.year},${plant.customNumber},${plant.category}');
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'plant_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(buffer.toString(), encoding: utf8);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📄 Экспортировано ${selectedPlants.length} растений'),
            action: SnackBarAction(
              label: 'Открыть',
              onPressed: () async {
                // Показываем путь пользователю
                debugPrint('CSV сохранён: $filePath');
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Ошибка экспорта CSV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    }
  }

  /// Проверить уникальность номера
  bool isCustomNumberUnique(int year, int number, String category,
      {String? excludeId}) {
    return !_plants.any((p) =>
        p.category == category &&
        p.year == year &&
        p.customNumber == number &&
        p.permanentId != excludeId);
  }

  /// Получить следующий свободный номер
  int getNextCustomNumber(int year, String category) {
    final numbers = _plants
        .where((p) => p.category == category && p.year == year)
        .map((p) => p.customNumber)
        .whereType<int>()
        .toList();
    if (numbers.isEmpty) return 1;
    return numbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  // ==================== MERGE HELPERS (облачная синхронизация) ====================

  Plant _mergePlantData(Plant local, Plant cloud) {
    final useCloudAsBase = cloud.lastModified != null &&
        local.lastModified != null &&
        cloud.lastModified!.isAfter(local.lastModified!);

    final base = useCloudAsBase ? cloud : local;
    final other = useCloudAsBase ? local : cloud;

    debugPrint(
        '🔄 Слияние ${base.latinName}: ${useCloudAsBase ? "облако > локальное" : "локальное > облако"}');

    final mergedPhotos = _mergePhotoLists(base.userPhotos, other.userPhotos, _deletedUserPhotos);
    final mergedLliflePhotos = _mergePhotoLists(base.lliflePhotoUrls, other.lliflePhotoUrls, _deletedLliflePhotos);

    return base.copyWith(
      userPhotos: mergedPhotos,
      lliflePhotoUrls: mergedLliflePhotos,
      lastModified: DateTime.now(),
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

  List<String> _mergePhotoLists(List<String> base, List<String> other, Set<String> deletedPhotos) {
    final allPhotos = <String>{};
    final orderedPhotos = <String>[];

    final filteredBase = base.where((photo) {
      final dedupeKey = _photoDedupKey(photo);
      return !deletedPhotos.contains(dedupeKey);
    }).toList();

    final filteredOther = other.where((photo) {
      final dedupeKey = _photoDedupKey(photo);
      return !deletedPhotos.contains(dedupeKey);
    }).toList();

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

  String _photoDedupKey(String photo) {
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      final uri = Uri.tryParse(photo);
      if (uri != null) {
        return '${uri.scheme}://${uri.host}${uri.path}'.toLowerCase();
      }
    }
    return photo;
  }

  List<Note> _mergeNotes(List<Note> base, List<Note> other) {
    final allNotes = <Note>[];
    final seenIds = <String>{};
    for (final note in [...base, ...other]) {
      if (!seenIds.contains(note.id)) {
        allNotes.add(note);
        seenIds.add(note.id);
      }
    }
    return allNotes..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<DateTime> _mergeWateringDates(List<DateTime> base, List<DateTime> other) {
    final allDates = <DateTime>{};
    final orderedDates = <DateTime>[];
    for (final date in [...base, ...other]) {
      final dateKey = DateTime(date.year, date.month, date.day);
      if (!allDates.contains(dateKey)) {
        allDates.add(dateKey);
        orderedDates.add(date);
      }
    }
    return orderedDates..sort((a, b) => a.compareTo(b));
  }

  List<DateTime> _mergeCustomWateringDates(List<DateTime> base, List<DateTime> other) {
    final allDates = <DateTime>{};
    final orderedDates = <DateTime>[];
    for (final date in [...base, ...other]) {
      final dateKey = DateTime(date.year, date.month, date.day);
      if (!allDates.contains(dateKey)) {
        allDates.add(dateKey);
        orderedDates.add(date);
      }
    }
    return orderedDates..sort((a, b) => a.compareTo(b));
  }

  List<FloweringRecord> _mergeFloweringHistory(List<FloweringRecord> base, List<FloweringRecord> other) {
    final allRecords = <FloweringRecord>[];
    final seenKeys = <String>{};
    for (final record in [...base, ...other]) {
      final key = '${record.date.year}-${record.date.month}-${record.date.day}_${record.event}';
      if (!seenKeys.contains(key)) {
        allRecords.add(record);
        seenKeys.add(key);
      }
    }
    return allRecords..sort((a, b) => a.date.compareTo(b.date));
  }

  List<GerminationRecord> _mergeGerminationHistory(List<GerminationRecord> base, List<GerminationRecord> other) {
    final allRecords = <GerminationRecord>[];
    final seenDates = <DateTime>{};
    for (final record in [...base, ...other]) {
      final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
      if (!seenDates.contains(dateKey)) {
        allRecords.add(record);
        seenDates.add(dateKey);
      }
    }
    return allRecords..sort((a, b) => a.date.compareTo(b.date));
  }
}
