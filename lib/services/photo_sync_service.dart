// TODO(этап 3): переписать по спецификации R-004/R-005.
// Windows-вариант с cleanBrokenCloudUrls НЕ перенесён (удалял фото) — см. _archive/merge_1_2.
import 'dart:io';


import '../core/logger/app_logger.dart';
import '../core/models/photo_passport.dart';
import '../core/sync/photo_trash_service.dart';
import '../data/models/plant.dart';
import '../injection_container.dart';
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

  PhotoSyncService(this._authService, this._diskService, [PhotoTrashService? trash])
      : _trashOverride = trash;
  final YandexAuthService _authService;
  final YandexDiskService _diskService;
  final PhotoTrashService? _trashOverride;

  /// Корзина: из конструктора (тесты) или из DI (приложение).
  PhotoTrashService? get _trash {
    if (_trashOverride != null) return _trashOverride;
    try {
      return sl<PhotoTrashService>();
    } catch (_) {
      return null;
    }
  }

  // ==================== СИНХРОНИЗАЦИЯ ФОТО ====================

  Future<void> syncUserPhotos(PlantCrudProvider plantCrudProvider) async {
    if (!_authService.isConnected) {
      AppLogger.warning('Синхронизация фото невозможна: нет подключения', tag: 'PHOTO_SYNC');
      return;
    }

    try {
      await _diskService.createAppFolders();

      for (var plant in plantCrudProvider.plants) {
        // Аудит 4.2 (C2): единый источник истины — паспорта.
        // Legacy-загрузка userPhotos отключена: поле @Deprecated,
        // для отображения и загрузки не используется.
        if (plant.photoPassports.isNotEmpty) {
          await _uploadPassportVersions(plant, plantCrudProvider);
        }
      }

      // Корзина: удаляем пути из очереди photo_trash (C3).
      // Удачные вычёркиваются, упавшие остаются на повтор.
      final trash = _trash;
      if (trash != null) {
        await trash.processTrash(_deleteCloudPath);
      }

      await cleanDuplicatePhotos(plantCrudProvider);
      // R-004/R-005: cleanBrokenCloudUrls отключена — молча удаляла ссылки на фото при сетевом сбое.
      await _syncDeletedPhotos(plantCrudProvider);

      AppLogger.api('✅ Синхронизация фото завершена', tag: 'PHOTO_SYNC');
    } catch (e) {
      AppLogger.error('Ошибка синхронизации пользовательских фото: $e', tag: 'PHOTO_SYNC');
    }
  }

  /// Удалить путь на Диске — внутренний путь или старая публичная ссылка.
  /// Всегда permanently=false (Корзина Диска, откат 30 дней).
  Future<void> _deleteCloudPath(String pathOrUrl) async {
    if (pathOrUrl.startsWith('/')) {
      await _diskService.deleteCloudFile(pathOrUrl);
    } else {
      await _diskService.deletePhoto(pathOrUrl);
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

    // Аудит 4.2 (C3/M4): clearDeletedPhotos() вызывается ТОЛЬКО при полном
    // успехе. Упавшие пути остаются в очереди провайдера И дополнительно
    // ставятся в photo_trash — повтор при следующей синхронизации.
    final pending = plantCrudProvider.deletedUserPhotos;
    if (pending.isNotEmpty) {
      AppLogger.api('🗑️ Удаляем свои фото с облака: ${pending.length}', tag: 'PHOTO_SYNC');
      final succeeded = <String>{};
      for (var deletedUrl in List.of(pending)) {
        try {
          await _deleteCloudPath(deletedUrl);
          succeeded.add(deletedUrl);
          AppLogger.api('✅ Своё фото удалено с облака: $deletedUrl', tag: 'PHOTO_SYNC');
        } catch (e) {
          AppLogger.error('❌ Ошибка удаления своего фото (повтор позже): $e', tag: 'PHOTO_SYNC');
          await _trash?.enqueueDelete(
            'legacy_${deletedUrl.hashCode}',
            [deletedUrl],
          );
        }
      }
      // deletedUserPhotos — сырой Set: снимаем только успешные.
      pending.removeAll(succeeded);
    }

    if (pending.isEmpty) {
      // Всё удалено (или и не было) — полная очистка обеих очередей.
      plantCrudProvider.clearDeletedPhotos();
    }
    AppLogger.api('✅ Синхронизация удаленных фото завершена', tag: 'PHOTO_SYNC');
  }

  // ==================== ДЕДУПЛИКАЦИЯ ====================

  /// Дедупликация по паспортным путям (аудит 4.2, C2): повторяющиеся
  /// версии с одинаковым путём внутри паспорта вычищаются. userPhotos
  /// не трогается (@Deprecated). Паспорта целиком не удаляем —
  /// разные паспорта могут легально делить один путь.
  Future<void> cleanDuplicatePhotos(PlantCrudProvider plantCrudProvider) async {
    bool changed = false;

    for (var plant in List.from(plantCrudProvider.plants)) {
      var plantChanged = false;
      final passports = plant.photoPassports.map((pp) {
        final unique = <String>{};
        final cleanedVersions = pp.versions.where((v) {
          final keep = unique.add(_photoDedupKey(v.yandexFilePath));
          if (!keep) {
            AppLogger.api('🗑️ Дубликат версии в паспорте: ${v.yandexFilePath}',
                tag: 'PHOTO_SYNC');
            plantChanged = true;
          }
          return keep;
        }).toList();
        return plantChanged ? pp.copyWith(versions: cleanedVersions) : pp;
      }).toList();

      if (plantChanged) {
        plantCrudProvider.updatePlant(
          plant.permanentId,
          plant.copyWith(photoPassports: passports),
        );
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
