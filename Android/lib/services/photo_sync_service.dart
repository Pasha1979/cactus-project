import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/logger/app_logger.dart';
import '../presentation/providers/plant_crud_provider.dart';
import 'yandex_auth_service.dart';
import 'yandex_disk_service.dart';

/// Сервис синхронизации фотографий с облаком
///
/// Отвечает за:
/// - Загрузку локальных фото в облако
/// - Удаление фото из облака (при удалении в приложении)
/// - Дедупликацию фото
/// - Валидацию cloud URL
class PhotoSyncService {

  PhotoSyncService(this._authService, this._diskService);
  final YandexAuthService _authService;
  final YandexDiskService _diskService;

  // ==================== СИНХРОНИЗАЦИЯ ФОТО ====================

  Future<void> syncUserPhotos(PlantCrudProvider plantCrudProvider) async {
    if (!_authService.isConnected) {
      AppLogger.warning('Синхронизация фото невозможна: нет подключения', tag: 'PHOTO_SYNC');
      return;
    }

    try {
      await _diskService.createAppFolders();
      int uploadedCount = 0;

      for (var plant in plantCrudProvider.plants) {
        final localPhotos = plant.userPhotos
            .where((photo) =>
                !photo.startsWith('https://') && !photo.startsWith('http://'),)
            .toList();

        if (localPhotos.isEmpty) continue;

        final updatedPhotos = List<String>.from(plant.userPhotos);

        for (var localPhoto in localPhotos) {
          if ((localPhoto.startsWith('/data/user/0/') && !Platform.isAndroid) ||
              ((localPhoto.startsWith('C:\\') ||
                      localPhoto.contains(':\\')) &&
                  Platform.isAndroid)) {
            continue;
          }

          final file = File(localPhoto);
          if (!await file.exists()) continue;

          AppLogger.api('📤 Загружаем фото: $localPhoto', tag: 'PHOTO_SYNC');

          try {
            final fileUrl = await _diskService.uploadPhoto(localPhoto);

            if (!await _validateCloudUrl(fileUrl)) {
              AppLogger.error('❌ Cloud URL недоступен: $fileUrl', tag: 'PHOTO_SYNC');
              continue;
            }

            final index = updatedPhotos.indexOf(localPhoto);
            if (index != -1) {
              updatedPhotos[index] = fileUrl;
              uploadedCount++;
              AppLogger.api('✅ Фото заменено на cloud URL: $fileUrl', tag: 'PHOTO_SYNC');
            }
          } catch (e) {
            AppLogger.error('❌ Ошибка загрузки $localPhoto: $e', tag: 'PHOTO_SYNC');
          }
        }

        if (updatedPhotos != plant.userPhotos) {
          final updatedPlant = plant.copyWith(userPhotos: updatedPhotos);
          plantCrudProvider.updatePlant(plant.permanentId, updatedPlant);
        }
      }

      await cleanDuplicatePhotos(plantCrudProvider);
      await _syncDeletedPhotos(plantCrudProvider);

      AppLogger.api('✅ Синхронизация фото завершена. Загружено: $uploadedCount фото', tag: 'PHOTO_SYNC');
    } catch (e) {
      AppLogger.error('Ошибка синхронизации пользовательских фото: $e', tag: 'PHOTO_SYNC');
    }
  }

  // ==================== УДАЛЁННЫЕ ФОТО ====================

  Future<void> _syncDeletedPhotos(PlantCrudProvider plantCrudProvider) async {
    AppLogger.api('🔄 Начинаем синхронизацию удаленных фото...', tag: 'PHOTO_SYNC');

    if (plantCrudProvider.deletedUserPhotos.isNotEmpty) {
      AppLogger.api('🗑️ Удаляем свои фото с облака: ${plantCrudProvider.deletedUserPhotos.length}', tag: 'PHOTO_SYNC');
      for (var deletedUrl in plantCrudProvider.deletedUserPhotos) {
        try {
          await _diskService.deletePhoto(deletedUrl);
          AppLogger.api('✅ Своё фото удалено с облака: $deletedUrl', tag: 'PHOTO_SYNC');
        } catch (e) {
          AppLogger.error('❌ Ошибка удаления своего фото: $e', tag: 'PHOTO_SYNC');
        }
      }
    }

    // Llifle фото — только из локальных данных (внешние URL)
    if (plantCrudProvider.deletedLliflePhotos.isNotEmpty) {
      AppLogger.api('🗑️ Убираем Llifle фото из данных: ${plantCrudProvider.deletedLliflePhotos.length}', tag: 'PHOTO_SYNC');
    }

    plantCrudProvider.clearDeletedPhotos();
    AppLogger.api('✅ Синхронизация удаленных фото завершена', tag: 'PHOTO_SYNC');
  }

  // ==================== ДЕДУПЛИКАЦИЯ ====================

  Future<void> cleanDuplicatePhotos(PlantCrudProvider plantCrudProvider) async {
    bool changed = false;

    for (var plant in List.from(plantCrudProvider.plants)) {
      final unique = <String>{};
      final cleaned = <String>[];

      for (var photo in plant.userPhotos) {
        final dedupeKey = _photoDedupKey(photo);
        if (unique.add(dedupeKey)) {
          cleaned.add(photo);
        } else {
          AppLogger.api('🗑️ Удалён дубликат: $photo', tag: 'PHOTO_SYNC');
          changed = true;
        }
      }

      if (cleaned.length != plant.userPhotos.length) {
        final updatedPlant = plant.copyWith(userPhotos: cleaned);
        plantCrudProvider.updatePlant(plant.permanentId, updatedPlant);
        changed = true;
      }
    }

    if (changed) {
      await plantCrudProvider.savePlants();
      AppLogger.api('✅ Дублей фото очищено', tag: 'PHOTO_SYNC');
    }
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

  // ==================== ВАЛИДАЦИЯ ====================

  Future<bool> _validateCloudUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
