import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/models/photo_passport.dart';
import 'package:my_cactus/core/sync/photo_passport_manager.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';

// ==================== FAKES ====================

/// Репозиторий-шпион: записывает вызванные методы (для проверки p5 —
/// ни сети, ни удаления файлов, ни deletePlant).
class SpyRepo implements PlantRepository {
  final store = <String, Plant>{};
  final calls = <String>[];

  @override
  Future<Plant?> getPlantById(String id) async {
    calls.add('getPlantById');
    return store[id];
  }

  @override
  Future<void> addPlant(Plant p) async {
    calls.add('addPlant');
    store[p.permanentId] = p;
  }

  @override
  Future<void> updatePlant(Plant p) async {
    calls.add('updatePlant');
    store[p.permanentId] = p;
  }

  @override
  Future<void> deletePlant(String id) async {
    calls.add('deletePlant');
    store.remove(id);
  }

  @override
  Future<List<Plant>> getAllPlants() async {
    calls.add('getAllPlants');
    return store.values.toList();
  }

  @override
  Future<List<Plant>> getPlantsByStatus(String s) async => [];
  @override
  Future<List<Plant>> getPlantsByCategory(String c) async => [];
  @override
  Future<List<Plant>> searchPlants(String q) async => [];
}

Plant _plant(String id) => Plant(
      permanentId: id,
      latinName: 'Cactus $id',
      status: 'alive',
      year: 2024,
      customNumber: 1,
      category: 'sown',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpyRepo repo;
  late SyncOutbox outbox;
  late Box<String> outboxBox;
  late PhotoPassportManager manager;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('photo_passport_');
    Hive.init(dir.path);
  });

  setUp(() async {
    repo = SpyRepo()..store['p1'] = _plant('p1');
    outboxBox =
        await Hive.openBox<String>('ppo_${DateTime.now().microsecondsSinceEpoch}');
    outbox = SyncOutbox(outboxBox);
    manager = PhotoPassportManager(plants: repo, outbox: outbox);
  });

  tearDown(() async {
    await outboxBox.deleteFromDisk();
  });

  // p1: addPhotoVersion создаёт новый паспорт с одной версией
  test('p1: новый паспорт с одной версией', () async {
    final passport = await manager.addPhotoVersion(
      'p1',
      '/MyCactus/photos/v1.jpg',
      1024,
    );
    expect(passport.plantId, 'p1');
    expect(passport.versions.length, 1);
    expect(passport.versions.first.yandexFilePath, '/MyCactus/photos/v1.jpg');
    expect(passport.versions.first.sizeBytes, 1024);
    expect(passport.isArchived, isFalse);
    expect(passport.isDeleted, isFalse);
    // Сохранено в растении
    final plant = await repo.getPlantById('p1');
    expect(plant!.photoPassports.length, 1);
    // Растение поставлено в outbox на синхронизацию
    expect(outbox.contains('p1'), isTrue);
  });

  // p2: addPhotoVersion к существующему паспорту добавляет версию
  test('p2: вторая версия в том же паспорте (замена = версия)', () async {
    final passport = await manager.addPhotoVersion(
      'p1',
      '/MyCactus/photos/v1.jpg',
      1024,
    );
    final updated = await manager.addPhotoVersion(
      'p1',
      '/MyCactus/photos/v2.jpg',
      2048,
      passportId: passport.passportId,
    );
    expect(updated.versions.length, 2);
    expect(updated.versions[0].yandexFilePath, '/MyCactus/photos/v1.jpg');
    expect(updated.versions[1].yandexFilePath, '/MyCactus/photos/v2.jpg');
    // Паспортов по-прежнему один
    final plant = await repo.getPlantById('p1');
    expect(plant!.photoPassports.length, 1);
  });

  // p3: archivePassport → isArchived, исчезает из активных
  test('p3: архивация скрывает паспорт из активных', () async {
    final passport =
        await manager.addPhotoVersion('p1', '/path.jpg', 10);
    await manager.archivePassport(passport.passportId);
    final plant = await repo.getPlantById('p1');
    expect(plant!.photoPassports.first.isArchived, isTrue);
    expect(await manager.getActivePassports('p1'), isEmpty);
  });

  // p4: deletePassportEverywhere → isDeleted, исчезает из активных
  test('p4: удалить везде — флаг isDeleted, скрыт из активных', () async {
    final passport =
        await manager.addPhotoVersion('p1', '/path.jpg', 10);
    await manager.deletePassportEverywhere(passport.passportId);
    final plant = await repo.getPlantById('p1');
    expect(plant!.photoPassports.first.isDeleted, isTrue);
    // Данные НЕ удалены — только флаг
    expect(plant.photoPassports.first.versions.length, 1);
    expect(await manager.getActivePassports('p1'), isEmpty);
    // Растение подготовлено к синхронизации
    expect(outbox.contains('p1'), isTrue);
  });

  // p5: НЕТ сети/удаления файлов при deletePassportEverywhere
  test('p5: delete — только флаг и outbox, без сети и файлов', () async {
    final passport =
        await manager.addPhotoVersion('p1', '/path.jpg', 10);
    repo.calls.clear();

    await manager.deletePassportEverywhere(passport.passportId);

    // Только чтение + обновление данных — deletePlant не вызывался,
    // файловых операций в менеджере нет в принципе (нет File/IO зависимостей)
    expect(repo.calls, containsAll(['getAllPlants', 'updatePlant']));
    expect(repo.calls, isNot(contains('deletePlant')));
  });

  // p6: freeLocalSpace очищает localCachePath у всех версий
  test('p6: freeLocalSpace сбрасывает кэш-пути', () async {
    final passport =
        await manager.addPhotoVersion('p1', '/path.jpg', 10);
    // Имитируем кэш вручную
    final plant = await repo.getPlantById('p1');
    final withCache = plant!.photoPassports.first.copyWith(versions: [
      plant.photoPassports.first.versions.first
          .copyWith(localCachePath: '/tmp/cache.jpg'),
    ]);
    await repo.updatePlant(
        plant.copyWith(photoPassports: [withCache]));

    await manager.freeLocalSpace(passport.passportId);
    final after = (await repo.getPlantById('p1'))!.photoPassports.first;
    expect(after.versions.first.localCachePath, isNull);
  });

  // p7: JSON round-trip моделей
  test('p7: PhotoPassport/PhotoVersion toJson↔fromJson', () {
    final p = PhotoPassport(
      passportId: 'pp1',
      plantId: 'p1',
      isArchived: true,
      versions: [
        PhotoVersion(
          versionId: 'v1',
          yandexFilePath: '/a.jpg',
          createdAt: DateTime.utc(2026),
          sizeBytes: 42,
          localCachePath: '/c.jpg',
        ),
      ],
    );
    final back = PhotoPassport.fromJson(p.toJson());
    expect(back.passportId, 'pp1');
    expect(back.isArchived, isTrue);
    expect(back.isDeleted, isFalse);
    expect(back.versions.single.yandexFilePath, '/a.jpg');
    expect(back.versions.single.localCachePath, '/c.jpg');
    expect(back.versions.single.sizeBytes, 42);
  });
}
