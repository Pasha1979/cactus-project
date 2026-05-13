import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  final YandexAuthService _authService;
  final YandexDiskService _diskService;

  PhotoSyncService(this._authService, this._diskService);

  // ==================== СИНХРОНИЗАЦИЯ ФОТО ====================

  Future<void> syncUserPhotos(PlantCrudProvider plantCrudProvider) async {
    if (!_authService.isConnected) {
      debugPrint('Синхронизация фото невозможна: нет подключения');
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

          debugPrint('📤 Загружаем фото: $localPhoto');

          try {
            final fileUrl = await _diskService.uploadPhoto(localPhoto);

            if (!await _validateCloudUrl(fileUrl)) {
              debugPrint('❌ Cloud URL недоступен: $fileUrl');
              continue;
            }

            final index = updatedPhotos.indexOf(localPhoto);
            if (index != -1) {
              updatedPhotos[index] = fileUrl;
              uploadedCount++;
              debugPrint('✅ Фото заменено на cloud URL: $fileUrl');
            }
          } catch (e) {
            debugPrint('❌ Ошибка загрузки $localPhoto: $e');
          }
        }

        if (updatedPhotos != plant.userPhotos) {
          final updatedPlant = plant.copyWith(userPhotos: updatedPhotos);
          plantCrudProvider.updatePlant(plant.permanentId, updatedPlant);
        }
      }

      await cleanDuplicatePhotos(plantCrudProvider);
      await _syncDeletedPhotos(plantCrudProvider);

      debugPrint('✅ Синхронизация фото завершена. Загружено: $uploadedCount фото');
    } catch (e) {
      debugPrint('Ошибка синхронизации пользовательских фото: $e');
    }
  }

  // ==================== УДАЛЁННЫЕ ФОТО ====================

  Future<void> _syncDeletedPhotos(PlantCrudProvider plantCrudProvider) async {
    debugPrint('🔄 Начинаем синхронизацию удаленных фото...');

    if (plantCrudProvider.deletedUserPhotos.isNotEmpty) {
      debugPrint(
          '🗑️ Удаляем свои фото с облака: ${plantCrudProvider.deletedUserPhotos.length}',);
      for (var deletedUrl in plantCrudProvider.deletedUserPhotos) {
        try {
          await _diskService.deletePhoto(deletedUrl);
          debugPrint('✅ Своё фото удалено с облака: $deletedUrl');
        } catch (e) {
          debugPrint('❌ Ошибка удаления своего фото: $e');
        }
      }
    }

    // Llifle фото — только из локальных данных (внешние URL)
    if (plantCrudProvider.deletedLliflePhotos.isNotEmpty) {
      debugPrint(
          '🗑️ Убираем Llifle фото из данных: ${plantCrudProvider.deletedLliflePhotos.length}',);
    }

    plantCrudProvider.clearDeletedPhotos();
    debugPrint('✅ Синхронизация удаленных фото завершена');
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
          debugPrint('🗑️ Удалён дубликат: $photo');
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
      debugPrint('✅ Дублей фото очищено');
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
