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

  static const int _maxSyncRetries = 3;

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

    // 2.9.1: Lock — предотвращаем параллельные вызовы syncData
    if (_isSyncing) {
      debugPrint('⏸️ Синхронизация уже выполняется, пропускаем');
      return;
    }
    _isSyncing = true;

    try {
      // 2.9.2: Exponential backoff retry для fetchLastCloudUpdate
      await _retryWithBackoff(
        () => fetchLastCloudUpdate(),
        operationName: 'fetchLastCloudUpdate',
      );

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
        await _retryWithBackoff(
          () => _uploadToCloud(plantCrudProvider),
          operationName: 'uploadToCloud',
        );
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

  /// 2.9.2: Повторные попытки с экспоненциальной задержкой.
  /// При сетевых ошибках: 1с → 2с → 4с (до 3 попыток).
  Future<void> _retryWithBackoff(
    Future<void> Function() operation, {
    required String operationName,
  }) async {
    for (int attempt = 0; attempt < _maxSyncRetries; attempt++) {
      try {
        await operation();
        return;
      } catch (e) {
        final isLastAttempt = attempt == _maxSyncRetries - 1;
        if (isLastAttempt) {
          debugPrint('❌ $operationName: исчерпаны все попытки ($_maxSyncRetries): $e');
          rethrow;
        }
        final delay = Duration(seconds: 1 << attempt); // 1с, 2с, 4с
        debugPrint('⚠️ $operationName: попытка ${attempt + 1}/$_maxSyncRetries не удалась, повтор через ${delay.inSeconds}с: $e');
        await Future.delayed(delay);
      }
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

      // 2.9.3: Валидация структуры входящих данных
      if (!_validateCloudData(data, plantCrudProvider)) {
        debugPrint('⛔ Данные из облака не прошли валидацию — локальные данные сохранены');
        return;
      }

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

  /// 2.9.3 + 2.9.4: Валидация данных из облака.
  ///
  /// Проверяет:
  /// - Наличие ключа 'plants'
  /// - Лимит количества растений (макс 10000)
  /// - 2.9.4: Защита от пустого списка — не перезаписывать если локально есть данные
  bool _validateCloudData(
    Map<String, dynamic> data,
    PlantCrudProvider plantCrudProvider,
  ) {
    if (!data.containsKey('plants')) {
      debugPrint('⛔ Валидация: отсутствует ключ plants');
      return false;
    }

    final plantsList = data['plants'];
    if (plantsList is! List) {
      debugPrint('⛔ Валидация: plants не является списком');
      return false;
    }

    if (plantsList.length > 10000) {
      debugPrint('⛔ Валидация: слишком много растений (${plantsList.length} > 10000)');
      return false;
    }

    // 2.9.4: Не перезаписывать локальные данные пустым списком
    if (plantsList.isEmpty && plantCrudProvider.plants.isNotEmpty) {
      debugPrint(
          '⛔ Валидация: облако вернуло пустой список, '
          'но локально есть ${plantCrudProvider.plants.length} растений — пропускаем',);
      return false;
    }

    debugPrint('✅ Валидация облачных данных прошла (${plantsList.length} растений)');
    return true;
  }
}
