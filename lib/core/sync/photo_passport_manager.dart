import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../data/models/plant.dart';
import '../../domain/repositories/plant_repository.dart';
import '../models/photo_passport.dart';
import 'photo_trash_service.dart';
import 'sync_outbox.dart';

/// Локальный менеджер фото-паспортов (этап 3.1, R-004/R-005/R-054).
///
/// Только локальная логика: НИКАКИХ сетевых вызовов и удалений файлов.
/// «Удалить везде» = флаг isDeleted + запись растения в outbox на
/// синхронизацию; файл с Яндекс.Диска на этом шаге не трогается.
/// При сбое сети фото из данных не удаляется — удалять может только
/// явное действие пользователя.
class PhotoPassportManager {
  PhotoPassportManager({
    required PlantRepository plants,
    SyncOutbox? outbox,
    PhotoTrashService? trash,
  })  : _plants = plants,
        _outbox = outbox,
        _trash = trash;

  final PlantRepository _plants;
  final SyncOutbox? _outbox;
  final PhotoTrashService? _trash;

  /// Добавить версию фото. Если [passportId] передан — версия добавляется
  /// в этот паспорт (замена = новая версия, R-004); иначе создаётся новый
  /// паспорт с одной версией. Сеть не проверяется.
  Future<PhotoPassport> addPhotoVersion(
    String plantId,
    String yandexFilePath,
    int sizeBytes, {
    String? passportId,
  }) async {
    final plant = await _plants.getPlantById(plantId);
    if (plant == null) {
      throw StateError('Растение $plantId не найдено');
    }

    final version = PhotoVersion(
      versionId: const Uuid().v4(),
      yandexFilePath: yandexFilePath,
      createdAt: DateTime.now(),
      sizeBytes: sizeBytes,
    );

    PhotoPassport passport;
    final passports = List<PhotoPassport>.from(plant.photoPassports);
    if (passportId != null) {
      final idx = passports.indexWhere((p) => p.passportId == passportId);
      if (idx < 0) {
        throw StateError('Паспорт $passportId не найден');
      }
      passport = passports[idx].copyWith(
        versions: [...passports[idx].versions, version],
      );
      passports[idx] = passport;
    } else {
      passport = PhotoPassport(
        passportId: const Uuid().v4(),
        plantId: plantId,
        versions: [version],
      );
      passports.add(passport);
    }

    await _save(plant, passports);
    return passport;
  }

  /// Архивировать паспорт (скрыть, не удаляя).
  Future<void> archivePassport(String passportId) =>
      _mutate(passportId, (p) => p.copyWith(isArchived: true));

  /// Вернуть паспорт из архива в галерею (снять isArchived).
  Future<void> unarchivePassport(String passportId) =>
      _mutate(passportId, (p) => p.copyWith(isArchived: false));

  /// «Удалить везде»: ставит isDeleted, готовит запись к синхронизации
  /// через outbox и ставит пути версий в корзину photo_trash —
  /// физическое удаление с Диска делает синк (permanently=false, R-005).
  /// Файл на этом шаге НЕ удаляется.
  Future<void> deletePassportEverywhere(String passportId) async {
    await _mutate(passportId, (p) => p.copyWith(isDeleted: true));
    final trash = _trash;
    if (trash == null) return;
    try {
      final plant = await _findPlantOfPassport(passportId);
      final passport = plant?.photoPassports
          .where((p) => p.passportId == passportId)
          .firstOrNull;
      if (passport == null) return;
      final paths = passport.versions
          .map((v) => v.yandexFilePath)
          .where((p) => p.startsWith('/MyCactus/'))
          .toList();
      await trash.enqueueDelete(passportId, paths);
    } catch (_) {
      // Корзина недоступна — не ломаем операцию; удаление повторится позже.
    }
  }

  /// Освободить место: удалить локальный файл кэша с диска (если есть)
  /// и сбросить localCachePath у всех версий паспорта (аудит 4.2, H1).
  Future<void> freeLocalSpace(String passportId) => _mutate(
        passportId,
        (p) => p.copyWith(
          versions: p.versions.map((v) {
            final cache = v.localCachePath;
            if (cache != null) {
              try {
                final f = File(cache);
                if (f.existsSync()) f.deleteSync();
              } catch (_) {
                // Файл недоступен/занят — просто сбрасываем ссылку.
              }
            }
            return v.copyWith(clearCache: true);
          }).toList(),
        ),
      );

  /// Активные паспорта растения: не удалённые и не архивные.
  Future<List<PhotoPassport>> getActivePassports(String plantId) async {
    final plant = await _plants.getPlantById(plantId);
    if (plant == null) return [];
    return plant.photoPassports
        .where((p) => !p.isDeleted && !p.isArchived)
        .toList();
  }

  /// Архивные паспорта растения (не удалённые) — для «Показать архивные».
  Future<List<PhotoPassport>> getArchivedPassports(String plantId) async {
    final plant = await _plants.getPlantById(plantId);
    if (plant == null) return [];
    return plant.photoPassports
        .where((p) => p.isArchived && !p.isDeleted)
        .toList();
  }

  /// Все живые паспорта растения (активные + архивные, без удалённых).
  Future<List<PhotoPassport>> getAllPassports(String plantId) async {
    final plant = await _plants.getPlantById(plantId);
    if (plant == null) return [];
    return plant.photoPassports.where((p) => !p.isDeleted).toList();
  }

  // ==================== internals ====================

  /// Найти паспорт по id (по всем растениям, владельцу — по полю plantId).
  Future<void> _mutate(
    String passportId,
    PhotoPassport Function(PhotoPassport) update,
  ) async {
    final plant = await _findPlantOfPassport(passportId);
    if (plant == null) {
      throw StateError('Паспорт $passportId не найден');
    }
    final passports = plant.photoPassports
        .map((p) => p.passportId == passportId ? update(p) : p)
        .toList();
    await _save(plant, passports);
  }

  Future<Plant?> _findPlantOfPassport(String passportId) async {
    final all = await _plants.getAllPlants();
    for (final plant in all) {
      if (plant.photoPassports.any((p) => p.passportId == passportId)) {
        return plant;
      }
    }
    return null;
  }

  /// Сохранить растение + подготовить к синхронизации (upsert в outbox).
  Future<void> _save(Plant plant, List<PhotoPassport> passports) async {
    await _plants.updatePlant(plant.copyWith(photoPassports: passports));
    await _outbox?.enqueue(plant.permanentId, SyncOutbox.opUpsert);
  }
}
