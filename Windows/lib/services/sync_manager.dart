import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../presentation/providers/plant_crud_provider.dart';
import 'photo_sync_service.dart';
import 'yandex_auth_service.dart';
import 'yandex_disk_service.dart';

/// Сервис управления синхронизацией данных между локальным хранилищем и облаком
///
/// Отвечает за:
/// - Сравнение timestamps (lastLocalUpdate vs lastCloudUpdate)
/// - Решение конфликтов (кто новее — локальное или облачное)
/// - Оrcheстрацию upload/download
class SyncManager {
  final YandexAuthService _authService;
  final YandexDiskService _diskService;
  final PhotoSyncService _photoSyncService;

  bool _isSyncing = false;
  DateTime? _lastCloudUpdate;

  bool get isSyncing => _isSyncing;
  DateTime? get lastCloudUpdate => _lastCloudUpdate;

  SyncManager(this._authService, this._diskService, PhotoSyncService? photoSync)
      : _photoSyncService = photoSync ?? PhotoSyncService(_authService, _diskService);

  // ==================== FETCH ====================

  Future<void> fetchLastCloudUpdate() async {
    if (!_authService.isConnected) {
      _lastCloudUpdate = null;
      return;
    }

    DateTime? cloudDateFromServer;

    try {
      cloudDateFromServer =
          await _diskService.getFileModifiedDate('/MyCactus/plant_provider.json');
    } catch (e) {
      debugPrint('⚠️ Ошибка запроса файла: $e');
    }

    if (cloudDateFromServer != null) {
      if (_lastCloudUpdate == null ||
          cloudDateFromServer.isAfter(_lastCloudUpdate!)) {
        _lastCloudUpdate = cloudDateFromServer;
        debugPrint('✅ Дата обновлена из ФАЙЛА: $_lastCloudUpdate');
      } else {
        debugPrint(
            'ℹ️ Дата с сервера ($cloudDateFromServer) не новее текущей ($_lastCloudUpdate) — оставляем текущую',);
      }
    } else {
      // Fallback на папку
      try {
        final folderDate =
            await _diskService.getFolderModifiedDate('/MyCactus');
        if (folderDate != null &&
            (_lastCloudUpdate == null || folderDate.isAfter(_lastCloudUpdate!))) {
          _lastCloudUpdate = folderDate;
          debugPrint('⚠️ Файл не дал дату, взята дата папки: $_lastCloudUpdate');
        }
      } catch (e) {
        debugPrint('❌ Не удалось получить дату папки: $e');
      }
    }

    if (_lastCloudUpdate == null) {
      debugPrint('⚠️ Не удалось получить дату ни файла, ни папки');
    }
  }

  // ==================== SYNC ====================

  Future<void> syncData(PlantCrudProvider plantCrudProvider) async {
    if (!_authService.isConnected) {
      debugPrint('Синхронизация невозможна: нет подключения');
      return;
    }

    _isSyncing = true;

    try {
      await fetchLastCloudUpdate();
      final localUpdate = plantCrudProvider.lastLocalUpdate;
      final cloudUpdate = _lastCloudUpdate;

      final timeTolerance = const Duration(seconds: 2);

      if (cloudUpdate != null &&
          (localUpdate == null ||
              cloudUpdate.isAfter(localUpdate.add(timeTolerance)))) {
        debugPrint('☁️ Облако новее → загружаем из облака');
        await plantCrudProvider.createLocalBackup();
        await loadDataFromCloud(plantCrudProvider);
        await plantCrudProvider.savePlants();
        return;
      }

      if (plantCrudProvider.plants.isNotEmpty) {
        debugPrint('📤 Локальные данные новее → отправляем в облако');
        await _uploadToCloud(plantCrudProvider);
        await fetchLastCloudUpdate();
      } else if (cloudUpdate != null) {
        debugPrint('📥 Локально пусто → загружаем из облака');
        await plantCrudProvider.createLocalBackup();
        await loadDataFromCloud(plantCrudProvider);
        await plantCrudProvider.savePlants();
      }

      debugPrint('✅ Синхронизация успешно завершена');
    } catch (e) {
      debugPrint('❌ Ошибка синхронизации: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ==================== UPLOAD / DOWNLOAD ====================

  Future<void> _uploadToCloud(PlantCrudProvider plantCrudProvider) async {
    final now = DateTime.now().toUtc();
    plantCrudProvider.setLastLocalUpdate(now);

    // Перезагружаем legacy-данные из SharedPreferences
    await plantCrudProvider.reloadLegacyData();

    final plantProviderData =
        utf8.encode(jsonEncode(plantCrudProvider.toJson()));

    await _diskService.uploadJsonFile(plantProviderData);
    _lastCloudUpdate = now;

    // Синхронизируем фото после загрузки JSON
    await _photoSyncService.syncUserPhotos(plantCrudProvider);
  }

  /// Сброс состояния при отключении
  void disconnect() {
    _lastCloudUpdate = null;
  }

  Future<void> loadDataFromCloud(
      PlantCrudProvider plantCrudProvider,) async {
    await plantCrudProvider.createLocalBackup();

    try {
      final data = await _diskService.downloadJsonFile();

      debugPrint('📥 Загружено из облака: ${data['plants']?.length ?? 0} растений');

      await plantCrudProvider.loadFromCloudJson(data);

      await fetchLastCloudUpdate();
      if (_lastCloudUpdate != null) {
        plantCrudProvider.setLastLocalUpdate(_lastCloudUpdate!);
      }

      await plantCrudProvider.ensureLocalPhotosExist();
      await plantCrudProvider.cleanupLocalPhotosAfterCloudLoad();
      await _photoSyncService.cleanDuplicatePhotos(plantCrudProvider);

      debugPrint('✅ Данные загружены из облака + фото обработаны');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        await _diskService.createEmptyPlantProviderFile();
      } else {
        debugPrint('❌ Ошибка загрузки из облака: $e');
      }
    }
  }
}
