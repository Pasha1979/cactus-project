import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/sync/photo_migration.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/core/sync/sync_state_store.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';

// ==================== FAKES ====================

class FakeRepo implements PlantRepository {
  final store = <String, Plant>{};
  @override
  Future<Plant?> getPlantById(String id) async => store[id];
  @override
  Future<void> addPlant(Plant p) async => store[p.permanentId] = p;
  @override
  Future<void> updatePlant(Plant p) async => store[p.permanentId] = p;
  @override
  Future<void> deletePlant(String id) async => store.remove(id);
  @override
  Future<List<Plant>> getAllPlants() async => store.values.toList();
  @override
  Future<List<Plant>> getPlantsByStatus(String s) async => [];
  @override
  Future<List<Plant>> getPlantsByCategory(String c) async => [];
  @override
  Future<List<Plant>> searchPlants(String q) async => [];
}

Plant _plant(String id, List<String> userPhotos) => Plant(
      permanentId: id,
      latinName: 'Cactus $id',
      status: 'alive',
      year: 2024,
      customNumber: 1,
      category: 'sown',
      userPhotos: userPhotos,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRepo repo;
  late SyncStateStore state;
  late SyncOutbox outbox;
  late Box<String> stateBox;
  late Box<String> outboxBox;
  late PhotoMigration migration;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('photo_migration_');
    Hive.init(dir.path);
  });

  setUp(() async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    stateBox = await Hive.openBox<String>('pms_$ts');
    outboxBox = await Hive.openBox<String>('pmo_$ts');
    state = SyncStateStore(stateBox);
    outbox = SyncOutbox(outboxBox);
    repo = FakeRepo();
    migration =
        PhotoMigration(plants: repo, state: state, outbox: outbox);
  });

  tearDown(() async {
    await stateBox.deleteFromDisk();
    await outboxBox.deleteFromDisk();
  });

  // pm1: миграция создаёт архивные паспорта из userPhotos
  test('pm1: userPhotos → архивные паспорта', () async {
    repo.store['p1'] =
        _plant('p1', ['/old/photo1.jpg', 'https://yandex/photo2.jpg']);
    repo.store['p2'] = _plant('p2', []); // без фото — пропуск

    await migration.run();

    final plant = await repo.getPlantById('p1');
    expect(plant!.photoPassports.length, 1);
    final passport = plant.photoPassports.first;
    expect(passport.isArchived, isTrue);
    expect(passport.isDeleted, isFalse);
    expect(passport.versions.length, 2);
    expect(passport.versions[0].yandexFilePath, '/old/photo1.jpg');
    expect(passport.versions[1].yandexFilePath, 'https://yandex/photo2.jpg');
    // userPhotos НЕ очищен — обратная совместимость
    expect(plant.userPhotos.length, 2);
    // p2 без фото — паспортов нет
    expect((await repo.getPlantById('p2'))!.photoPassports, isEmpty);
    // p1 подготовлен к синхронизации
    expect(outbox.contains('p1'), isTrue);
    expect(state.getValue('migration_photo_v1_done'), 'true');
  });

  // pm2: идемпотентность
  test('pm2: повторный run ничего не меняет', () async {
    repo.store['p1'] = _plant('p1', ['/old/photo1.jpg']);
    await migration.run();
    final first =
        (await repo.getPlantById('p1'))!.photoPassports.length;

    await migration.run(); // повтор

    final plant = await repo.getPlantById('p1');
    expect(plant!.photoPassports.length, first);
    expect(plant.photoPassports.first.versions.length, 1);
  });
}
