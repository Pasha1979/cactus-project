import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/auth/auth_repository.dart';
import 'package:my_cactus/core/auth/auth_state.dart';
import 'package:my_cactus/core/sync/sync_engine.dart';
import 'package:my_cactus/core/sync/sync_engine_push.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/data/datasources/remote/plant_remote_datasource.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:my_cactus/injection_container.dart';
import 'package:my_cactus/presentation/providers/plant_crud_provider.dart';

// ==================== FAKES (без живой сети) ====================

class FakeAuthRepository implements AuthRepository {
  AuthUser? user;

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthStatus> get authStatusStream => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class FakeRemote implements PlantRemoteDataSource {
  final uploaded = <Map<String, dynamic>>[];
  final deleted = <String>[];
  var lastSyncUpdated = false;
  var failNext = false;

  @override
  Future<List<Map<String, dynamic>>> fetchPlants() async => [];

  @override
  Future<void> uploadPlant(Map<String, dynamic> plant) async {
    if (failNext) {
      failNext = false;
      throw Exception('network down');
    }
    uploaded.add(plant);
  }

  @override
  Future<void> deletePlant(String plantId) async {
    if (failNext) {
      failNext = false;
      throw Exception('network down');
    }
    deleted.add(plantId);
  }

  @override
  Future<void> updateLastSync() async => lastSyncUpdated = true;
}

class FakePlantRepository implements PlantRepository {
  final store = <String, Plant>{};

  @override
  Future<Plant?> getPlantById(String id) async => store[id];

  @override
  Future<void> addPlant(Plant plant) async => store[plant.permanentId] = plant;

  @override
  Future<void> updatePlant(Plant plant) async =>
      store[plant.permanentId] = plant;

  @override
  Future<void> deletePlant(String id) async => store.remove(id);

  @override
  Future<List<Plant>> getAllPlants() async => store.values.toList();

  @override
  Future<List<Plant>> getPlantsByStatus(String status) async => [];

  @override
  Future<List<Plant>> getPlantsByCategory(String category) async => [];

  @override
  Future<List<Plant>> searchPlants(String query) async => [];
}

// ==================== HELPERS ====================

Plant _plant() => Plant(
      latinName: 'Mammillaria test',
      status: 'alive',
      year: 2024,
      customNumber: 1,
      category: 'sown',
    );

AuthUser _user() => AuthUser(
      id: 'u1',
      email: 'test@example.com',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late Box<String> box;
  late SyncOutbox outbox;
  late FakeAuthRepository auth;
  late FakeRemote remote;
  late FakePlantRepository repo;
  late PushSyncEngine engine;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('push_test_');
    Hive.init(dir.path);
  });

  setUp(() async {
    box = await Hive.openBox<String>('outbox_${DateTime.now().microsecondsSinceEpoch}');
    outbox = SyncOutbox(box);
    auth = FakeAuthRepository()..user = _user();
    remote = FakeRemote();
    repo = FakePlantRepository();
    engine = PushSyncEngine(
      outbox: outbox,
      remote: remote,
      plants: repo,
      auth: auth,
    );
    await sl.reset();
  });

  tearDown(() async => box.deleteFromDisk());

  // t1: enqueue при add/update/delete через провайдер
  test('t1: enqueue при add/update/delete', () async {
    sl.registerSingleton<PlantRepository>(repo);
    sl.registerSingleton<SyncOutbox>(outbox);
    final provider = PlantCrudProvider();

    final p = _plant();
    await provider.addPlant(p);
    var ops = outbox.pending().map((e) => e.op).toList();
    expect(ops, [SyncOutbox.opUpsert]);

    await provider.updatePlant(p.permanentId, p.copyWith(status: 'flower'));
    ops = outbox.pending().map((e) => e.op).toList();
    expect(ops, [SyncOutbox.opUpsert]);

    await provider.deletePlant(p.permanentId);
    ops = outbox.pending().map((e) => e.op).toList();
    expect(ops, [SyncOutbox.opDelete]);
  });

  // t2: push отправляет upsert с user_id и БЕЗ client last_modified
  test('t2: upsert с user_id и без last_modified', () async {
    final p = _plant();
    await repo.addPlant(p);
    await outbox.enqueue(p.permanentId, SyncOutbox.opUpsert);

    await engine.pushLocalChanges();

    expect(remote.uploaded, hasLength(1));
    final row = remote.uploaded.single;
    expect(row['user_id'], 'u1');
    expect(row['permanent_id'], p.permanentId);
    expect(row.containsKey('last_modified'), isFalse);
    expect(outbox.length, 0);
    expect(remote.lastSyncUpdated, isTrue);
    expect(engine.currentStatus, SyncStatus.idle);
  });

  // t3: push отправляет tombstone при delete
  test('t3: tombstone при delete', () async {
    final p = _plant();
    await outbox.enqueue(p.permanentId, SyncOutbox.opDelete);

    await engine.pushLocalChanges();

    expect(remote.deleted, [p.permanentId]);
    expect(remote.uploaded, isEmpty);
    expect(outbox.length, 0);
  });

  // t4: ошибка сети → запись остаётся в outbox, статус error
  test('t4: ошибка → запись остаётся, статус error', () async {
    final p = _plant();
    await repo.addPlant(p);
    await outbox.enqueue(p.permanentId, SyncOutbox.opUpsert);
    remote.failNext = true;

    await engine.pushLocalChanges();

    expect(outbox.length, 1);
    expect(engine.currentStatus, SyncStatus.error);
    expect(remote.lastSyncUpdated, isFalse);

    // Повторная попытка успешна
    await engine.pushLocalChanges();
    expect(remote.uploaded, hasLength(1));
    expect(outbox.length, 0);
    expect(engine.currentStatus, SyncStatus.idle);
  });

  // t5: без аккаунта → no-op, outbox не трогается
  test('t5: без аккаунта — no-op', () async {
    auth.user = null;
    final p = _plant();
    await outbox.enqueue(p.permanentId, SyncOutbox.opUpsert);

    await engine.pushLocalChanges();

    expect(remote.uploaded, isEmpty);
    expect(remote.deleted, isEmpty);
    expect(remote.lastSyncUpdated, isFalse);
    expect(outbox.length, 1); // очередь не тронута
    expect(engine.currentStatus, SyncStatus.idle);
  });

  // t6: delete приоритетнее повторного upsert
  test('t6: delete не отменяется upsert', () async {
    await outbox.enqueue('p1', SyncOutbox.opDelete);
    await outbox.enqueue('p1', SyncOutbox.opUpsert);

    final entries = outbox.pending();
    expect(entries, hasLength(1));
    expect(entries.single.op, SyncOutbox.opDelete);
  });
}
