import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_constants.dart';
import '../../models/qr_code_file.dart';
import '../datasources/local/hive_database.dart';
import '../datasources/local/plant_index_manager.dart';
import '../models/plant_dto.dart';
import '../models/qr_code_dto.dart';

/// Менеджер миграции данных
///
/// Отвечает за версионирование и выполнение миграций при запуске приложения.
/// Каждая миграция — это функция, которая преобразует данные из одного формата
/// в другой (например, SharedPreferences → Hive).
class DataMigrationManager {
  static const String _migrationVersionKey = 'data_migration_version';
  static const String _migrationBackupKey = 'data_migration_backup';

  /// Текущая версия схемы данных
  /// При добавлении новой миграции — увеличить на 1
  static const int currentVersion = 1;

  /// Проверяет необходимость миграции и выполняет её
  ///
  /// Возвращает [true] если миграция выполнена успешно или не требуется.
  /// Возвращает [false] если произошла ошибка и нужно показать пользователю.
  static Future<bool> runMigrationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final currentDbVersion = prefs.getInt(_migrationVersionKey) ?? 0;

    if (currentDbVersion >= currentVersion) {
      // Миграция не требуется
      return true;
    }

    print('🔄 Начинаем миграцию данных: v$currentDbVersion → v$currentVersion');

    // Шаг 1: Создать бэкап перед миграцией
    final backupSuccess = await _createBackup(prefs);
    if (!backupSuccess) {
      print('❌ Не удалось создать бэкап. Миграция отменена.');
      return false;
    }

    // Шаг 2: Выполнить миграции по очереди
    try {
      if (currentDbVersion < 1) {
        await _migrateV1SharedPrefsToHive(prefs);
      }

      // Будущие миграции:
      // if (currentDbVersion < 2) { await _migrateV2_...(); }

      // Шаг 3: Обновить версию
      await prefs.setInt(_migrationVersionKey, currentVersion);
      print('✅ Миграция завершена. Версия: $currentVersion');

      return true;
    } catch (e, stack) {
      print('❌ Ошибка миграции: $e');
      print(stack);
      return false;
    }
  }

  /// Создаёт бэкап всех данных SharedPreferences перед миграцией
  static Future<bool> _createBackup(SharedPreferences prefs) async {
    try {
      final allData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        // Не бэкапим бэкап и версию миграции
        if (key == _migrationBackupKey || key == _migrationVersionKey) continue;

        final value = prefs.get(key);
        if (value != null) {
          allData[key] = value;
        }
      }

      final backupJson = jsonEncode(allData);
      await prefs.setString(_migrationBackupKey, backupJson);
      print('💾 Бэкап создан: ${backupJson.length} символов');
      return true;
    } catch (e) {
      print('❌ Ошибка создания бэкапа: $e');
      return false;
    }
  }

  /// Откат миграции — восстановление данных из бэкапа
  static Future<bool> rollback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupJson = prefs.getString(_migrationBackupKey);

      if (backupJson == null) {
        print('⚠️ Бэкап не найден. Откат невозможен.');
        return false;
      }

      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;

      // Восстанавливаем данные
      for (final entry in backupData.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.cast<String>());
        }
      }

      // Сбрасываем версию миграции
      await prefs.remove(_migrationVersionKey);

      print('✅ Откат выполнен. Данные восстановлены из бэкапа.');
      return true;
    } catch (e, stack) {
      print('❌ Ошибка отката: $e');
      print(stack);
      return false;
    }
  }

  /// V1: Миграция SharedPreferences to Hive
  static Future<void> _migrateV1SharedPrefsToHive(SharedPreferences prefs) async {
    print('🔄 Миграция V1: SharedPreferences to Hive');

    await _migratePlants(prefs);
    await _migrateQRCodeFiles(prefs);
    await _migrateScanHistory(prefs);
    await _migrateGlobalWateringDates(prefs);
    await _migrateWinteringSettings(prefs);
    await _migrateAdultImages(prefs);
    await _migrateSearchHistory(prefs);

    print('✅ Миграция V1 завершена');
  }

  /// Миграция растений: `List<String>` JSON to Hive `PlantDto`
  static Future<void> _migratePlants(SharedPreferences prefs) async {
    final plantsJson = prefs.getStringList(PrefsKeys.plants);
    if (plantsJson == null || plantsJson.isEmpty) {
      print('⚠️ Растения не найдены в SharedPreferences');
      return;
    }

    final box = HiveDatabase.plantsBox;
    int migratedCount = 0;

    for (final plantJson in plantsJson) {
      try {
        final plantMap = jsonDecode(plantJson) as Map<String, dynamic>;
        final dto = _convertPlantMapToDto(plantMap);
        await box.put(dto.permanentId, dto);
        migratedCount++;
      } catch (e) {
        print('⚠️ Ошибка миграции растения: $e');
      }
    }

    print('✅ Перенесено растений: $migratedCount/${plantsJson.length}');

    // Перестроить индексы после массовой миграции
    final indexManager = PlantIndexManager(HiveDatabase.plantIndexBox);
    await indexManager.rebuildIndex(box);
    print('✅ Индексы перестроены после миграции');
  }

  /// Конвертирует Map from JSON в PlantDto
  static PlantDto _convertPlantMapToDto(Map<String, dynamic> json) {
    // Парсинг списков JSON-строк (germinationHistory, floweringHistory, notes, gbifOccurrences)
    List<String> encodeJsonList(dynamic field) {
      if (field == null) return [];
      if (field is List) {
        return field.map((e) => jsonEncode(e)).cast<String>().toList();
      }
      return [];
    }

    // Парсинг DateTime из ISO8601 или null
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    // Парсинг List<DateTime>
    List<DateTime> parseDateTimeList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((d) => d is String ? DateTime.tryParse(d) : null)
            .whereType<DateTime>()
            .toList();
      }
      return [];
    }

    // Парсинг QRCode в JSON-строку
    String? encodeQrCode(dynamic qrCode) {
      if (qrCode == null) return null;
      if (qrCode is Map) {
        return jsonEncode(qrCode);
      }
      return null;
    }

    return PlantDto(
      permanentId: json['permanentId'] as String? ?? '',
      displayId: json['displayId'] as String? ?? '',
      latinName: json['latinName'] as String? ?? '',
      status: json['status'] as String? ?? 'sown',
      year: json['year'] as int? ?? DateTime.now().year,
      customNumber: json['customNumber'] as int? ?? 0,
      category: json['category'] as String? ?? 'sown',
      seedsCount: json['seedsCount'] as int? ?? 0,
      germinatedCount: json['germinatedCount'] as int? ?? 0,
      userPhotos: (json['userPhotos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      lastFertilization: parseDateTime(json['lastFertilization']),
      plannedFertilizationDate: parseDateTime(json['plannedFertilizationDate']),
      lliflePhotoUrls: (json['lliflePhotoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      lastModified: parseDateTime(json['lastModified']) ?? DateTime.now(),
      fieldNumber: json['fieldNumber'] as String?,
      seller: json['seller'] as String?,
      harvestYear: json['harvestYear'] as int?,
      country: json['country'] as String?,
      habitat: json['habitat'] as String?,
      description: json['description'] as String?,
      synonyms: json['synonyms'] as String?,
      careTips: json['careTips'] as String?,
      floweringPeriod: json['floweringPeriod'] as String?,
      countryFlag: json['countryFlag'] as String?,
      wateringDates: parseDateTimeList(json['wateringDates']),
      customWateringDates: parseDateTimeList(json['customWateringDates']),
      hasUnreadNotification: json['hasUnreadNotification'] as bool? ?? false,
      lastRepotting: parseDateTime(json['lastRepotting']),
      plannedTransplantDate: parseDateTime(json['plannedTransplantDate']),
      germinationHistoryJson: encodeJsonList(json['germinationHistory']),
      floweringHistoryJson: encodeJsonList(json['floweringHistory']),
      notesJson: encodeJsonList(json['notes']),
      gbifPhotoUrls: (json['gbifPhotoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      gbifOccurrencesJson: encodeJsonList(json['gbifOccurrences']),
      lastGbifUpdate: parseDateTime(json['lastGbifUpdate']),
      aliveCount: json['aliveCount'] as int?,
      isBatch: json['isBatch'] as bool? ?? false,
      childrenIds: (json['childrenIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      parentId: json['parentId'] as String?,
      qrCodeJson: encodeQrCode(json['qrCode']),
    );
  }

  /// Миграция QR-кодов: encoded string → Hive [QRCodeDto]
  static Future<void> _migrateQRCodeFiles(SharedPreferences prefs) async {
    final qrJson = prefs.getString(PrefsKeys.qrCodeFiles);
    if (qrJson == null || qrJson.isEmpty) {
      print('⚠️ QR-коды не найдены в SharedPreferences');
      return;
    }

    try {
      final files = QRCodeFile.decodeList(qrJson);
      final box = HiveDatabase.qrCodesBox;

      for (final file in files) {
        final dto = QRCodeDto(
          plantId: file.id,
          plantName: file.fileName,
          permanentId: file.plantIds.isNotEmpty ? file.plantIds.first : file.id,
          createdAt: file.createdAt,
          isActive: true,
          filePath: file.filePath.isNotEmpty ? file.filePath : null,
        );
        await box.put(dto.plantId, dto);
      }

      print('✅ Перенесено QR-кодов: ${files.length}');
    } catch (e) {
      print('⚠️ Ошибка миграции QR-кодов: $e');
    }
  }

  /// Миграция истории сканирований: JSON string → Hive (string list)
  static Future<void> _migrateScanHistory(SharedPreferences prefs) async {
    final historyJson = prefs.getString(PrefsKeys.qrScanHistory);
    if (historyJson == null || historyJson.isEmpty) {
      print('⚠️ История сканирований не найдена');
      return;
    }

    try {
      final history = List<String>.from(jsonDecode(historyJson));
      final box = await Hive.openBox<String>('scan_history_box');

      for (int i = 0; i < history.length; i++) {
        await box.put(i.toString(), history[i]);
      }

      print('✅ Перенесено записей истории: ${history.length}');
    } catch (e) {
      print('⚠️ Ошибка миграции истории: $e');
    }
  }

  /// Миграция глобальных дат полива
  static Future<void> _migrateGlobalWateringDates(SharedPreferences prefs) async {
    final json = prefs.getString(PrefsKeys.globalWateringDates);
    if (json == null || json.isEmpty) return;

    try {
      final dates = (jsonDecode(json) as List<dynamic>)
          .map((d) => d is String ? DateTime.tryParse(d) : null)
          .whereType<DateTime>()
          .toList();

      final box = await Hive.openBox<DateTime>('settings_box');
      for (int i = 0; i < dates.length; i++) {
        await box.put('watering_$i', dates[i]);
      }

      print('✅ Перенесено дат полива: ${dates.length}');
    } catch (e) {
      print('⚠️ Ошибка миграции дат полива: $e');
    }
  }

  /// Миграция настроек зимовки
  static Future<void> _migrateWinteringSettings(SharedPreferences prefs) async {
    final box = await Hive.openBox<String>('settings_box');

    final start = prefs.getString(PrefsKeys.winteringStart);
    final end = prefs.getString(PrefsKeys.winteringEnd);
    final temp = prefs.getString(PrefsKeys.winteringTemp);
    final log = prefs.getString(PrefsKeys.winteringLog);

    if (start != null) await box.put('wintering_start', start);
    if (end != null) await box.put('wintering_end', end);
    if (temp != null) await box.put('wintering_temp', temp);
    if (log != null) await box.put('wintering_log', log);

    print('✅ Настройки зимовки перенесены');
  }

  /// Миграция adult images
  static Future<void> _migrateAdultImages(SharedPreferences prefs) async {
    final json = prefs.getString(PrefsKeys.adultImages);
    if (json == null || json.isEmpty) return;

    try {
      final box = await Hive.openBox<String>('settings_box');
      await box.put('adult_images', json);
      print('✅ Adult images перенесены');
    } catch (e) {
      print('⚠️ Ошибка миграции adult images: $e');
    }
  }

  /// Миграция истории поиска
  static Future<void> _migrateSearchHistory(SharedPreferences prefs) async {
    final history = prefs.getStringList(PrefsKeys.searchHistory);
    if (history == null || history.isEmpty) return;

    final box = await Hive.openBox<String>('settings_box');
    await box.put('search_history', jsonEncode(history));
    print('✅ История поиска перенесена');
  }
}
