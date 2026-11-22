import 'package:uuid/uuid.dart';

import '../../domain/repositories/plant_repository.dart';
import '../logger/app_logger.dart';
import '../models/photo_passport.dart';
import 'sync_outbox.dart';
import 'sync_state_store.dart';

/// Однократная миграция legacy-фото: userPhotos → архивные PhotoPassport
/// (этап 3.2, R-054/R-055).
///
/// Каждая строка userPhotos становится PhotoVersion (yandexFilePath =
/// строка как есть — старые ссылки сохраняются без потерь, R-024).
/// Все версии растения складываются в ОДИН архивный паспорт
/// (isArchived = true — согласовано с владельцем).
/// userPhotos НЕ очищается — обратная совместимость до конца этапа 3.
/// Идемпотентно по флагу sync_state['migration_photo_v1_done'].
class PhotoMigration {
  PhotoMigration({
    required PlantRepository plants,
    required SyncStateStore state,
    SyncOutbox? outbox,
  })  : _plants = plants,
        _state = state,
        _outbox = outbox;

  static const String doneKey = 'migration_photo_v1_done';

  final PlantRepository _plants;
  final SyncStateStore _state;
  final SyncOutbox? _outbox;

  bool get isDone => _state.getValue(doneKey) == 'true';

  /// Выполнить миграцию фото. Возвращает true, если флаг done установлен.
  Future<bool> run() async {
    if (isDone) {
      AppLogger.api('Фото-миграция уже выполнена — пропуск', tag: 'PHOTO_MIGRATION');
      return true;
    }

    var migratedPlants = 0;
    var migratedPhotos = 0;

    final plants = await _plants.getAllPlants();
    for (final plant in plants) {
      if (plant.userPhotos.isEmpty) continue;

      final versions = plant.userPhotos
          .map(
            (s) => PhotoVersion(
              versionId: const Uuid().v4(),
              yandexFilePath: s, // сохраняем как есть (старую ссылку или путь)
              createdAt: DateTime.now(),
              sizeBytes: 0, // размер legacy-файлов неизвестен
            ),
          )
          .toList();

      final passport = PhotoPassport(
        passportId: const Uuid().v4(),
        plantId: plant.permanentId,
        versions: versions,
        isArchived: true,
      );

      await _plants.updatePlant(
        plant.copyWith(
          photoPassports: [...plant.photoPassports, passport],
        ),
      );
      // Готовим растение к синхронизации (push нового поля photo_passports)
      await _outbox?.enqueue(plant.permanentId, SyncOutbox.opUpsert);

      migratedPlants++;
      migratedPhotos += versions.length;
    }

    await _state.setValue(doneKey, 'true');
    AppLogger.api(
      'Фото-миграция завершена: $migratedPlants растений, '
      '$migratedPhotos фото → архивные паспорта',
      tag: 'PHOTO_MIGRATION',
    );
    return true;
  }
}
