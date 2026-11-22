// TODO(этап 3): переписать по спецификации R-004/R-005.
// Windows-вариант с cleanBrokenCloudUrls НЕ перенесён (удалял фото) — см. _archive/merge_1_2.
import 'dart:io';


import '../core/logger/app_logger.dart';
import '../core/models/photo_passport.dart';
import '../data/models/plant.dart';
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
            final cloudPath = await _diskService.uploadPhoto(localPhoto);

            // Заменяем локальный путь на внутренний путь Диска (R-004/R-055)
            final index = updatedPhotos.indexOf(localPhoto);
            if (index != -1) {
              updatedPhotos[index] = cloudPath;
              uploadedCount++;
              AppLogger.api('✅ Фото заменено на путь Диска: $cloudPath', tag: 'PHOTO_SYNC');
            }
          } catch (e) {
            AppLogger.error('❌ Ошибка загрузки $localPhoto: $e', tag: 'PHOTO_SYNC');
            // Сохраняем локальный фото как fallback - не удаляем его
          }
        }

        if (updatedPhotos != plant.userPhotos) {
          final updatedPlant = plant.copyWith(userPhotos: updatedPhotos);
          plantCrudProvider.updatePlant(plant.permanentId, updatedPlant);
        }

        // Этап 3 (R-055): версии фото-паспортов с локальными путями
        // загружаем через uploadPassportPhoto → внутренний путь Диска.
        if (plant.photoPassports.isNotEmpty) {
          await _uploadPassportVersions(plant, plantCrudProvider);
        }
      }

      await cleanDuplicatePhotos(plantCrudProvider);
      // R-004/R-005: cleanBrokenCloudUrls отключена — молча удаляла ссылки на фото при сетевом сбое.
      await _syncDeletedPhotos(plantCrudProvider);

      AppLogger.api('✅ Синхронизация фото завершена. Загружено: $uploadedCount фото', tag: 'PHOTO_SYNC');
    } catch (e) {
      AppLogger.error('Ошибка синхронизации пользовательских фото: $e', tag: 'PHOTO_SYNC');
    }
  }

  // ==================== ФОТО-ПАСПОРТА (этап 3) ====================

  /// Загрузить локальные версии паспортов на Диск по внутреннему пути
  /// `/MyCactus/photos/{passportId}_{versionId}.{ext}` (R-004/R-055).
  /// Локальный путь файла переезжает в localCachePath.
  Future<void> _uploadPassportVersions(
    Plant plant,
    PlantCrudProvider plantCrudProvider,
  ) async {
    var changed = false;
    final passports = List.of(plant.photoPassports);

    for (var pi = 0; pi < passports.length; pi++) {
      final pp = passports[pi];
      if (pp.isDeleted) continue;
      final versions = List.of(pp.versions);
      var vChanged = false;

      for (var vi = 0; vi < versions.length; vi++) {
        final v = versions[vi];
        final p = v.yandexFilePath;
        final isCloudOrUrl = p.startsWith('/MyCactus/') ||
            p.startsWith('http://') ||
            p.startsWith('https://');
        if (isCloudOrUrl) continue; // уже облачный путь или legacy-ссылка

        final file = File(p);
        if (!await file.exists()) continue;

        try {
          final cloudPath = await _diskService.uploadPassportPhoto(
            p,
            passportId: pp.passportId,
            versionId: v.versionId,
          );
          versions[vi] = PhotoVersion(
            versionId: v.versionId,
            yandexFilePath: cloudPath,
            createdAt: v.createdAt,
            sizeBytes: v.sizeBytes,
            localCachePath: p, // локальный файл = кэш
          );
          vChanged = true;
        } catch (e) {
          AppLogger.error(
            '❌ Ошибка загрузки версии паспорта $p: $e',
            tag: 'PHOTO_SYNC',
          );
        }
      }

      if (vChanged) {
        passports[pi] = pp.copyWith(versions: versions);
        changed = true;
      }
    }

    if (changed) {
      plantCrudProvider.updatePlant(
        plant.permanentId,
        plant.copyWith(photoPassports: passports),
      );
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

  // cleanBrokenCloudUrls/_validateCloudUrlWithRetry удалены при слиянии (R-004/R-005).
  // Спецификация правильной очистки — задача этапа 3.
}
