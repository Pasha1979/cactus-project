import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger/app_logger.dart';
import '../../data/datasources/local/hive_database.dart';
import '../../data/models/plant_dto.dart';
import '../../services/yandex_auth_service.dart';
import '../../services/yandex_disk_service.dart';

/// Сервис автоматического резервного копирования.
///
/// Создаёт бэкапы базы данных и загружает их в облако.
/// Хранит 30 последних версий с возможностью восстановления.
///
/// Использование:
/// ```dart
/// await AutoBackupService.initialize();
/// await AutoBackupService.performBackup();
/// ```
class AutoBackupService {
  static const String _tag = 'BACKUP';
  static const int _maxBackups = 30;
  static const String _prefsLastBackup = 'last_auto_backup';
  static const String _prefsBackupEnabled = 'auto_backup_enabled';
  static const String _prefsBackupFrequency = 'backup_frequency_hours';

  // ignore: sort_constructors_first
  static final AutoBackupService _instance = AutoBackupService._internal();
  // ignore: sort_constructors_first
  factory AutoBackupService() => _instance;
  // ignore: sort_constructors_first
  AutoBackupService._internal();

  Timer? _backupTimer;
  YandexAuthService? _authService;
  YandexDiskService? _diskService;

  /// Инициализация сервиса.
  ///
  /// Настраивает таймер для автоматического бэкапа.
  /// Вызывается из main.dart после инициализации Firebase.
  static Future<void> initialize() async {
    AppLogger.api('Инициализация AutoBackupService', tag: _tag);

    final isEnabled = await _isEnabledAsync();
    if (!isEnabled) {
      AppLogger.api('Автобэкап отключен в настройках', tag: _tag);
      return;
    }

    _instance._scheduleBackup();
    AppLogger.api('Автобэкап запланирован', tag: _tag);
  }

  /// Проверить, включен ли автобэкап (асинхронно).
  static Future<bool> _isEnabledAsync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsBackupEnabled) ?? true;
  }

  /// Проверить, включен ли автобэкап.
  static Future<bool> get isEnabled async {
    return await _isEnabledAsync();
  }

  /// Получить частоту бэкапа (в часах).
  static Future<int> get backupFrequencyHours async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsBackupFrequency) ?? 24;
  }

  /// Получить дату последнего бэкапа.
  static Future<DateTime?> get lastBackupDate async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_prefsLastBackup);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Включить/выключить автобэкап.
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsBackupEnabled, enabled);

    if (enabled) {
      _instance._scheduleBackup();
    } else {
      _instance._cancelBackup();
    }

    AppLogger.api('Автобэкап ${enabled ? 'включен' : 'отключен'}', tag: _tag);
  }

  /// Установить частоту бэкапа.
  static Future<void> setBackupFrequency(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsBackupFrequency, hours);

    // Перепланировать с новой частотой
    _instance._cancelBackup();
    final enabled = await isEnabled;
    if (enabled) {
      _instance._scheduleBackup();
    }

    AppLogger.api('Частота бэкапа: каждые $hours часов', tag: _tag);
  }

  /// Выполнить бэкап прямо сейчас.
  ///
  /// Возвращает результат операции.
  static Future<BackupResult> performBackup() async {
    return await _instance._doBackup();
  }

  /// Получить список доступных бэкапов из облака.
  static Future<List<BackupInfo>> getAvailableBackups() async {
    return await _instance._listCloudBackups();
  }

  /// Восстановить данные из бэкапа.
  ///
  /// Использует существующий механизм загрузки из облака.
  static Future<BackupResult> restoreFromCloud() async {
    return await _instance._doRestoreFromCloud();
  }

  // ==================== ПРИВАТНЫЕ МЕТОДЫ ====================

  void _scheduleBackup() {
    _cancelBackup();

    // Проверяем каждый час, но бэкапим только по расписанию
    _backupTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      await _checkAndBackup();
    });

    // Проверяем сразу при запуске
    _checkAndBackup();
  }

  void _cancelBackup() {
    _backupTimer?.cancel();
    _backupTimer = null;
  }

  Future<void> _checkAndBackup() async {
    final lastBackup = await lastBackupDate;
    final frequency = await backupFrequencyHours;
    final now = DateTime.now();

    // Проверяем, прошло ли достаточно времени
    if (lastBackup != null) {
      final nextBackup = lastBackup.add(Duration(hours: frequency));
      if (now.isBefore(nextBackup)) {
        // Ещё рано для бэкапа
        return;
      }
    }

    // Выполняем бэкап
    await _doBackup();
  }

  Future<BackupResult> _doBackup() async {
    try {
      AppLogger.api('Начало создания бэкапа', tag: _tag);

      // 1. Проверяем подключение к Яндекс.Диск
      _authService ??= YandexAuthService();
      _diskService ??= YandexDiskService(_authService!);

      if (!_authService!.isConnected) {
        AppLogger.warning('Нет подключения к Яндекс.Диск, бэкап отменен', tag: _tag);
        return BackupResult.notConnected();
      }

      // 2. Создаём папки приложения если нужно
      await _diskService!.createAppFolders();

      // 3. Экспортируем данные в JSON
      final backupData = await _exportData();
      final jsonBytes = utf8.encode(jsonEncode(backupData));

      // 4. Загружаем как резервную копию с временной меткой
      final now = DateTime.now();
      final versionedName = 'plant_backup_'
          '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}_'
          '${_twoDigits(now.hour)}${_twoDigits(now.minute)}.json';
      await _diskService!.uploadVersionedBackup(jsonBytes, versionedName);

      // Также обновляем основной plant_provider.json для совместимости
      await _diskService!.uploadJsonFile(jsonBytes);

      // 5. Удаляем старые версии если превышен лимит
      await _cleanupOldBackups();

      // 6. Сохраняем время бэкапа
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsLastBackup, now.millisecondsSinceEpoch);

      AppLogger.api('Бэкап успешно создан: $versionedName', tag: _tag);
      return BackupResult.success(now, versionedName);

    } catch (e, stack) {
      AppLogger.error('Ошибка при создании бэкапа', error: e, stackTrace: stack, tag: _tag);
      return BackupResult.failed(e.toString());
    }
  }

  Future<Map<String, dynamic>> _exportData() async {
    final box = HiveDatabase.plantsBox;
    final plants = box.values.toList();

    // Конвертируем PlantDto в Map вручную
    final plantsList = plants.map((p) => _plantDtoToMap(p)).toList();

    return {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'count': plants.length,
      'plants': plantsList,
    };
  }

  /// Конвертирует PlantDto в Map для JSON сериализации.
  Map<String, dynamic> _plantDtoToMap(PlantDto plant) {
    return {
      'permanentId': plant.permanentId,
      'displayId': plant.displayId,
      'latinName': plant.latinName,
      'status': plant.status,
      'year': plant.year,
      'customNumber': plant.customNumber,
      'category': plant.category,
      'seedsCount': plant.seedsCount,
      'germinatedCount': plant.germinatedCount,
      'userPhotos': plant.userPhotos,
      'lastFertilization': plant.lastFertilization?.toIso8601String(),
      'plannedFertilizationDate': plant.plannedFertilizationDate?.toIso8601String(),
      'lliflePhotoUrls': plant.lliflePhotoUrls,
      'lastModified': plant.lastModified?.toIso8601String(),
      'fieldNumber': plant.fieldNumber,
      'seller': plant.seller,
      'harvestYear': plant.harvestYear,
      'country': plant.country,
      'habitat': plant.habitat,
      'description': plant.description,
      'synonyms': plant.synonyms,
      'careTips': plant.careTips,
      'floweringPeriod': plant.floweringPeriod,
      'countryFlag': plant.countryFlag,
      'wateringDates': plant.wateringDates.map((d) => d.toIso8601String()).toList(),
      'customWateringDates': plant.customWateringDates.map((d) => d.toIso8601String()).toList(),
      'hasUnreadNotification': plant.hasUnreadNotification,
      'lastRepotting': plant.lastRepotting?.toIso8601String(),
      'plannedTransplantDate': plant.plannedTransplantDate?.toIso8601String(),
      'germinationHistoryJson': plant.germinationHistoryJson,
      'floweringHistoryJson': plant.floweringHistoryJson,
      'notesJson': plant.notesJson,
      'gbifPhotoUrls': plant.gbifPhotoUrls,
      'gbifOccurrencesJson': plant.gbifOccurrencesJson,
      'lastGbifUpdate': plant.lastGbifUpdate?.toIso8601String(),
      'aliveCount': plant.aliveCount,
      'isBatch': plant.isBatch,
      'childrenIds': plant.childrenIds,
      'parentId': plant.parentId,
      'qrCodeJson': plant.qrCodeJson,
    };
  }

  Future<List<BackupInfo>> _listCloudBackups() async {
    _authService ??= YandexAuthService();
    _diskService ??= YandexDiskService(_authService!);

    if (!_authService!.isConnected) return [];

    final files = await _diskService!.listVersionedBackups();
    return files.map((f) {
      final date = DateTime.tryParse(f['modified'] as String? ?? '') ??
          DateTime.now();
      return BackupInfo(
        fileName: f['name'] as String,
        date: date,
        size: f['size'] as int? ?? 0,
      );
    }).toList();
  }

  /// Удаляет старые версии бэкапов, оставляя не более [_maxBackups] файлов.
  Future<void> _cleanupOldBackups() async {
    try {
      final files = await _diskService!.listVersionedBackups();

      if (files.length <= _maxBackups) {
        AppLogger.api(
          'Бэкапов: ${files.length}/$_maxBackups — очистка не нужна',
          tag: _tag,
        );
        return;
      }

      // Файлы уже отсортированы по дате (API возвращает sort=-modified)
      // Удаляем всё что превышает лимит
      final toDelete = files.sublist(_maxBackups);
      for (final file in toDelete) {
        await _diskService!.deleteCloudFile(file['path'] as String);
        AppLogger.api('Удалён старый бэкап: ${file['name']}', tag: _tag);
      }

      AppLogger.api(
        'Очистка бэкапов: удалено ${toDelete.length}, осталось $_maxBackups',
        tag: _tag,
      );
    } catch (e, stack) {
      AppLogger.error('Ошибка очистки старых бэкапов', error: e, stackTrace: stack, tag: _tag);
    }
  }

  String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';

  Future<BackupResult> _doRestoreFromCloud() async {
    try {
      AppLogger.api('Начало восстановления из облака', tag: _tag);

      _authService ??= YandexAuthService();
      _diskService ??= YandexDiskService(_authService!);

      if (!_authService!.isConnected) {
        return BackupResult.notConnected();
      }

      // Используем существующий механизм загрузки
      final cloudData = await _diskService!.downloadJsonFile();

      if (cloudData.isEmpty) {
        return BackupResult.failed('Нет данных в облаке');
      }

      // Восстанавливаем данные
      await _importData(cloudData);

      AppLogger.api('Восстановление завершено успешно', tag: _tag);
      return BackupResult.success(DateTime.now(), 'plant_provider.json');

    } catch (e, stack) {
      AppLogger.error('Ошибка при восстановлении', error: e, stackTrace: stack, tag: _tag);
      return BackupResult.failed(e.toString());
    }
  }

  Future<void> _importData(Map<String, dynamic> backupData) async {
    final plantsData = backupData['plants'] as List<dynamic>?;
    if (plantsData == null) return;

    final box = HiveDatabase.plantsBox;

    // Очищаем текущие данные
    await box.clear();

    // Импортируем новые
    for (final plantData in plantsData) {
      final plant = _mapToPlantDto(plantData as Map<String, dynamic>);
      await box.put(plant.permanentId, plant);
    }

    AppLogger.api('Импортировано ${plantsData.length} растений', tag: _tag);
  }

  /// Конвертирует Map в PlantDto.
  PlantDto _mapToPlantDto(Map<String, dynamic> map) {
    return PlantDto(
      permanentId: map['permanentId'] ?? '',
      displayId: map['displayId'] ?? '',
      latinName: map['latinName'] ?? '',
      status: map['status'] ?? 'alive',
      year: map['year'] ?? DateTime.now().year,
      customNumber: map['customNumber'] ?? 0,
      category: map['category'] ?? 'Cactus',
      seedsCount: map['seedsCount'] ?? 0,
      germinatedCount: map['germinatedCount'] ?? 0,
      userPhotos: List<String>.from(map['userPhotos'] ?? []),
      lliflePhotoUrls: List<String>.from(map['lliflePhotoUrls'] ?? []),
      wateringDates: (map['wateringDates'] as List<dynamic>?)
          ?.map((d) => DateTime.parse(d as String))
          .toList() ?? [],
      customWateringDates: (map['customWateringDates'] as List<dynamic>?)
          ?.map((d) => DateTime.parse(d as String))
          .toList() ?? [],
      hasUnreadNotification: map['hasUnreadNotification'] ?? false,
      germinationHistoryJson: List<String>.from(map['germinationHistoryJson'] ?? []),
      floweringHistoryJson: List<String>.from(map['floweringHistoryJson'] ?? []),
      notesJson: List<String>.from(map['notesJson'] ?? []),
      gbifPhotoUrls: List<String>.from(map['gbifPhotoUrls'] ?? []),
      gbifOccurrencesJson: List<String>.from(map['gbifOccurrencesJson'] ?? []),
      isBatch: map['isBatch'] ?? false,
      childrenIds: List<String>.from(map['childrenIds'] ?? []),
    );
  }
}

/// Результат операции бэкапа.
// ignore: sort_constructors_first
class BackupResult {
  // ignore: sort_constructors_first
  final bool success;
  // ignore: sort_constructors_first
  final DateTime? timestamp;
  // ignore: sort_constructors_first
  final String? fileName;
  // ignore: sort_constructors_first
  final String? error;
  // ignore: sort_constructors_first
  final bool isConnected;

  // ignore: sort_constructors_first
  const BackupResult({
    required this.success,
    this.timestamp,
    this.fileName,
    this.error,
    this.isConnected = true,
  });

  // ignore: sort_constructors_first
  // ignore: sort_constructors_first
  // ignore: sort_constructors_first
  // ignore: sort_constructors_first
  // ignore: sort_constructors_first
  factory BackupResult.success(DateTime timestamp, String fileName) {
    // ignore: sort_constructors_first
    // ignore: sort_constructors_first
    // ignore: sort_constructors_first
    // ignore: sort_constructors_first
    // ignore: sort_constructors_first
    return BackupResult(
      success: true,
      timestamp: timestamp,
      fileName: fileName,
    );
  }

  // ignore: sort_constructors_first
  factory BackupResult.failed(String error) {
    return BackupResult(success: false, error: error);
  }

  // ignore: sort_constructors_first
  factory BackupResult.notConnected() {
    return BackupResult(
      success: false,
      error: 'Нет подключения к Яндекс.Диск',
      isConnected: false,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'BackupResult(success, $fileName, $timestamp)';
    }
    return 'BackupResult(failed, error: $error)';
  }
}

/// Информация о бэкапе.
// ignore: sort_constructors_first
class BackupInfo {
  // ignore: sort_constructors_first
  final String fileName;
  // ignore: sort_constructors_first
  final DateTime date;
  // ignore: sort_constructors_first
  final int size;

  // ignore: sort_constructors_first
  const BackupInfo({
    required this.fileName,
    required this.date,
    required this.size,
  });

  String get formattedDate {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
