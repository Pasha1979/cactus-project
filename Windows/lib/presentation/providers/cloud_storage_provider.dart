import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../routers/app_router.dart' show navigatorKey;
import 'plant_crud_provider.dart';
import '../../services/photo_sync_service.dart';
import '../../services/sync_manager.dart';
import '../../services/yandex_auth_service.dart';
import '../../services/yandex_disk_service.dart';

/// Провайдер для управления облачным хранилищем (фасад).
///
/// Делегирует работу специализированным сервисам:
/// - [YandexAuthService] — OAuth2, токены, подключение
/// - [YandexDiskService] — HTTP-операции с Яндекс.Диск
/// - [SyncManager] — синхронизация данных (conflict resolution)
/// - [PhotoSyncService] — синхронизация фотографий
///
/// Сохраняет публичный API для обратной совместимости с UI.
class CloudStorageProvider with ChangeNotifier {
  late final YandexAuthService _authService;
  late final YandexDiskService _diskService;
  late final SyncManager _syncManager;
  late final PhotoSyncService _photoSyncService;

  CloudStorageProvider() {
    _authService = YandexAuthService();
    _diskService = YandexDiskService(_authService);
    _photoSyncService = PhotoSyncService(_authService, _diskService);
    _syncManager = SyncManager(_authService, _diskService, _photoSyncService);
  }

  // ==================== ГЕТТЕРЫ ====================

  bool get isConnected => _authService.isConnected;
  bool get isSyncing => _syncManager.isSyncing;
  String? get currentStorageType => _authService.currentStorageType;
  DateTime? get lastCloudUpdate => _syncManager.lastCloudUpdate;

  // ==================== АВТОРИЗАЦИЯ ====================

  Future<void> handleDeepLink(Uri uri) async {
    await _authService.handleDeepLink(uri);

    // После успешной авторизации — автозагрузка данных из облака
    if (_authService.isConnected) {
      await _diskService.createAppFolders();
      await _syncManager.fetchLastCloudUpdate();

      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final plantCrudProvider =
            Provider.of<PlantCrudProvider>(context, listen: false);
        await _syncManager.syncData(plantCrudProvider);
        debugPrint('🔄 Полная синхронизация после авторизации выполнена');
      }
    }

    notifyListeners();
  }

  Future<void> connectToYandexDisk(BuildContext context) async {
    await _authService.connectToYandexDisk(context);
    notifyListeners();
  }

  Future<void> connectToYandexDiskSilently() async {
    await _authService.connectToYandexDiskSilently();
    if (_authService.isConnected) {
      await _diskService.createAppFolders();
      await _syncManager.fetchLastCloudUpdate();
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _authService.disconnect();
    _syncManager.disconnect(); // сбрасывает _lastCloudUpdate
    notifyListeners();
  }

  // ==================== СИНХРОНИЗАЦИЯ ====================

  Future<void> syncData(PlantCrudProvider plantCrudProvider) async {
    notifyListeners(); // isSyncing = true — обновляем UI немедленно
    await _syncManager.syncData(plantCrudProvider);
    notifyListeners(); // isSyncing = false
  }

  Future<void> loadFromCloud(BuildContext context) async {
    if (!context.mounted) return;
    final plantCrudProvider =
        Provider.of<PlantCrudProvider>(context, listen: false);
    // Загружаем данные из облака без conflict resolution
    // (пользователь явно запросил загрузку)
    await _syncManager.loadDataFromCloud(plantCrudProvider);
    notifyListeners();
  }

  // ==================== ФОТО ====================

  Future<String> uploadPhotoToYandexDisk(String filePath) async {
    return _diskService.uploadPhoto(filePath);
  }

  Future<List<String>> getCloudPhotos() async {
    return _diskService.getCloudPhotos();
  }

  Future<void> deletePhotoFromYandexDisk(String fileUrl) async {
    await _diskService.deletePhoto(fileUrl);
  }

  // ==================== ОБРАТНАЯ СОВМЕСТИМОСТЬ (алиасы) ====================

  Future<void> loadCredentials() async {
    await _authService.loadCredentials();
    if (_authService.isConnected) {
      await _diskService.createAppFolders();
      await _syncManager.fetchLastCloudUpdate();
    }
    notifyListeners();
  }

  Future<void> fetchLastCloudUpdate() async {
    await _syncManager.fetchLastCloudUpdate();
    notifyListeners();
  }

  Future<void> loadDataFromCloud(PlantCrudProvider plantCrudProvider) async {
    await _syncManager.loadDataFromCloud(plantCrudProvider);
    notifyListeners();
  }

  Future<void> syncUserPhotos(PlantCrudProvider plantCrudProvider) async {
    await _photoSyncService.syncUserPhotos(plantCrudProvider);
    notifyListeners();
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ ====================

  void invalidateAllCaches(PlantCrudProvider plantCrudProvider) {
    plantCrudProvider.invalidateAllCaches();
  }
}
