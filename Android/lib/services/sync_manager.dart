import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/logger/app_logger.dart';
import '../presentation/providers/plant_crud_provider.dart';
import 'photo_sync_service.dart';
import 'yandex_auth_service.dart';
import 'yandex_disk_service.dart';

/// Исключение отмены синхронизации пользователем.
class _SyncCancelledException implements Exception {
  @override
  String toString() => 'SyncCancelledException';
}

/// Сервис управления синхронизацией данных между локальным хранилищем и облаком
///
/// Отвечает за:
/// - Сравнение timestamps (lastLocalUpdate vs lastCloudUpdate)
/// - Решение конфликтов (кто новее — локальное или облачное)
/// - Оrcheстрацию upload/download
class SyncManager {

  SyncManager(this._authService, this._diskService, PhotoSyncService? photoSync)
      : _photoSyncService = photoSync ?? PhotoSyncService(_authService, _diskService);
  final YandexAuthService _authService;
  final YandexDiskService _diskService;
  final PhotoSyncService _photoSyncService;

  static const int _maxSyncRetries = 3;

  bool _isSyncing = false;
  DateTime? _lastCloudUpdate;
  bool _cancelRequested = false;

  /// 2.9.5: Прогресс синхронизации (0.0 – 1.0)
  final ValueNotifier<double> syncProgress = ValueNotifier(0.0);

  bool get isSyncing => _isSyncing;
  DateTime? get lastCloudUpdate => _lastCloudUpdate;

  /// 2.9.5: Запросить отмену текущей синхронизации.
  void cancelSync() {
    if (_isSyncing) {
      _cancelRequested = true;
      AppLogger.api('⏹️ Запрошена отмена синхронизации', tag: 'SYNC');
    }
  }

  /// Освобождение ресурсов.
  void dispose() {
    syncProgress.dispose();
  }

  void _checkCancelled() {
    if (_cancelRequested) {
      throw _SyncCancelledException();
    }
  }

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
      AppLogger.warning('⚠️ Ошибка запроса файла: $e', tag: 'SYNC');
    }

    if (cloudDateFromServer != null) {
      if (_lastCloudUpdate == null ||
          cloudDateFromServer.isAfter(_lastCloudUpdate!)) {
        _lastCloudUpdate = cloudDateFromServer;
        AppLogger.api('✅ Дата обновлена из ФАЙЛА: $_lastCloudUpdate', tag: 'SYNC');
      } else {
        AppLogger.api('ℹ️ Дата с сервера ($cloudDateFromServer) не новее текущей ($_lastCloudUpdate) — оставляем текущую', tag: 'SYNC');
      }
    } else {
      // Fallback на папку
      try {
        final folderDate =
            await _diskService.getFolderModifiedDate('/MyCactus');
        if (folderDate != null &&
            (_lastCloudUpdate == null || folderDate.isAfter(_lastCloudUpdate!))) {
          _lastCloudUpdate = folderDate;
          AppLogger.warning('⚠️ Файл не дал дату, взята дата папки: $_lastCloudUpdate', tag: 'SYNC');
        }
      } catch (e) {
        AppLogger.error('❌ Не удалось получить дату папки: $e', tag: 'SYNC');
      }
    }

    if (_lastCloudUpdate == null) {
      AppLogger.warning('⚠️ Не удалось получить дату ни файла, ни папки', tag: 'SYNC');
    }
  }

  // ==================== SYNC ====================

  Future<void> syncData(PlantCrudProvider plantCrudProvider) async {
    if (!_authService.isConnected) {
      AppLogger.warning('Синхронизация невозможна: нет подключения', tag: 'SYNC');
      return;
    }

    // 2.9.1: Lock — предотвращаем параллельные вызовы syncData
    if (_isSyncing) {
      AppLogger.api('⏸️ Синхронизация уже выполняется, пропускаем', tag: 'SYNC');
      return;
    }
    _cancelRequested = false;
    syncProgress.value = 0.0;
    _isSyncing = true;

    try {
      // 2.9.2: Exponential backoff retry для fetchLastCloudUpdate
      syncProgress.value = 0.1;
      await _retryWithBackoff(
        () => fetchLastCloudUpdate(),
        operationName: 'fetchLastCloudUpdate',
      );
      _checkCancelled();

      final localUpdate = plantCrudProvider.lastLocalUpdate;
      final cloudUpdate = _lastCloudUpdate;

      final timeTolerance = const Duration(seconds: 2);

      if (cloudUpdate != null &&
          (localUpdate == null ||
              cloudUpdate.isAfter(localUpdate.add(timeTolerance)))) {
        AppLogger.api('☁️ Облако новее → загружаем из облака', tag: 'SYNC');
        syncProgress.value = 0.2;
        await plantCrudProvider.createLocalBackup();
        _checkCancelled();
        syncProgress.value = 0.3;
        await loadDataFromCloud(plantCrudProvider);
        _checkCancelled();
        syncProgress.value = 0.5;
        await plantCrudProvider.savePlants();
        syncProgress.value = 1.0;
        AppLogger.api('✅ Синхронизация успешно завершена (загрузка из облака)', tag: 'SYNC');
        return;
      }

      if (plantCrudProvider.plants.isNotEmpty) {
        AppLogger.api('📤 Локальные данные новее → отправляем в облако', tag: 'SYNC');
        syncProgress.value = 0.3;
        await _retryWithBackoff(
          () => _uploadToCloud(plantCrudProvider),
          operationName: 'uploadToCloud',
        );
        _checkCancelled();
        syncProgress.value = 0.8;
        await fetchLastCloudUpdate();
        syncProgress.value = 1.0;
        AppLogger.api('✅ Синхронизация успешно завершена (выгрузка в облако)', tag: 'SYNC');
      } else if (cloudUpdate != null) {
        AppLogger.api('📥 Локально пусто → загружаем из облака', tag: 'SYNC');
        syncProgress.value = 0.2;
        await plantCrudProvider.createLocalBackup();
        _checkCancelled();
        syncProgress.value = 0.3;
        await loadDataFromCloud(plantCrudProvider);
        _checkCancelled();
        syncProgress.value = 0.5;
        await plantCrudProvider.savePlants();
        syncProgress.value = 1.0;
        AppLogger.api('✅ Синхронизация успешно завершена (загрузка из облака)', tag: 'SYNC');
      } else {
        syncProgress.value = 1.0;
        AppLogger.api('✅ Синхронизация: нет данных для передачи', tag: 'SYNC');
      }
    } on _SyncCancelledException {
      AppLogger.api('⏹️ Синхронизация отменена пользователем', tag: 'SYNC');
    } catch (e) {
      AppLogger.error('❌ Ошибка синхронизации: $e', tag: 'SYNC');
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
      _checkCancelled();
      try {
        await operation();
        return;
      } catch (e) {
        if (e is _SyncCancelledException) rethrow;
        final isLastAttempt = attempt == _maxSyncRetries - 1;
        if (isLastAttempt) {
          AppLogger.error('❌ $operationName: исчерпаны все попытки ($_maxSyncRetries): $e', tag: 'SYNC');
          rethrow;
        }
        final delay = Duration(seconds: 1 << attempt); // 1с, 2с, 4с
        AppLogger.warning('⚠️ $operationName: попытка ${attempt + 1}/$_maxSyncRetries не удалась, повтор через ${delay.inSeconds}с: $e', tag: 'SYNC');
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
        AppLogger.warning('⛔ Данные из облака не прошли валидацию — локальные данные сохранены', tag: 'SYNC');
        return;
      }

      AppLogger.api('📥 Загружено из облака: ${data['plants']?.length ?? 0} растений', tag: 'SYNC');

      _checkCancelled();
      await plantCrudProvider.loadFromCloudJson(data);

      await fetchLastCloudUpdate();
      if (_lastCloudUpdate != null) {
        plantCrudProvider.setLastLocalUpdate(_lastCloudUpdate!);
      }

      await plantCrudProvider.ensureLocalPhotosExist();
      await plantCrudProvider.cleanupLocalPhotosAfterCloudLoad();
      await _photoSyncService.cleanDuplicatePhotos(plantCrudProvider);

      AppLogger.api('✅ Данные загружены из облака + фото обработаны', tag: 'SYNC');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        await _diskService.createEmptyPlantProviderFile();
      } else {
        AppLogger.error('❌ Ошибка загрузки из облака: $e', tag: 'SYNC');
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
      AppLogger.warning('⛔ Валидация: отсутствует ключ plants', tag: 'SYNC');
      return false;
    }

    final plantsList = data['plants'];
    if (plantsList is! List) {
      AppLogger.warning('⛔ Валидация: plants не является списком', tag: 'SYNC');
      return false;
    }

    if (plantsList.length > 10000) {
      AppLogger.warning('⛔ Валидация: слишком много растений (${plantsList.length} > 10000)', tag: 'SYNC');
      return false;
    }

    // 2.9.4: Не перезаписывать локальные данные пустым списком
    if (plantsList.isEmpty && plantCrudProvider.plants.isNotEmpty) {
      AppLogger.warning('⛔ Валидация: облако вернуло пустой список, но локально есть ${plantCrudProvider.plants.length} растений — пропускаем', tag: 'SYNC');
      return false;
    }

    // 2.9.3: Валидация обязательных полей каждого растения
    for (int i = 0; i < plantsList.length; i++) {
      final plantData = plantsList[i];
      if (plantData is! Map<String, dynamic>) {
        AppLogger.warning('⛔ Валидация: элемент $i не является Map', tag: 'SYNC');
        return false;
      }
      if (!_validatePlantJson(plantData)) {
        AppLogger.warning('⛔ Валидация: растение $i не прошло проверку полей', tag: 'SYNC');
        return false;
      }
    }

    AppLogger.api('✅ Валидация облачных данных прошла (${plantsList.length} растений)', tag: 'SYNC');
    return true;
  }

  /// 2.9.3: Проверка обязательных полей растения.
  ///
  /// Проверяет:
  /// - permanentId: не null, не пустой, строка
  /// - latinName: не null, не пустой, строка
  /// - year: целое число в диапазоне 1900–2100
  static bool _validatePlantJson(Map<String, dynamic> json) {
    final permanentId = json['permanentId'];
    if (permanentId is! String || permanentId.isEmpty) {
      return false;
    }

    final latinName = json['latinName'];
    if (latinName is! String || latinName.isEmpty) {
      return false;
    }

    final year = json['year'];
    if (year is! int || year < 1900 || year > 2100) {
      return false;
    }

    return true;
  }
}
