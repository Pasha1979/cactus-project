import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/auth/auth_repository.dart';
import 'package:my_cactus/core/auth/auth_state.dart';
import 'package:my_cactus/core/sync/settings_sync_adapter.dart';
import 'package:my_cactus/core/sync/sync_conflicts.dart';
import 'package:my_cactus/core/sync/sync_engine_full.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/core/sync/sync_state_store.dart';
import 'package:my_cactus/data/datasources/remote/plant_remote_datasource.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== IN-MEMORY SERVER ====================

/// In-memory «Supabase»: разделяется двумя устройствами, ведёт серверное
/// время монотонным счётчиком (как триггер set_last_modified на сервере).
/// Хранит tombstones — фильтра по is_deleted в fetchChangesSince нет.
class InMemoryServer implements PlantRemoteDataSource {
  final Map<String, Map<String, dynamic>> _plants = {};
  final Map<String, Map<String, dynamic>> _settings = {};
  int _tick = 0;

  DateTime _now() => DateTime.utc(2026).add(Duration(seconds: ++_tick));

  @override
  Future<void> uploadPlant(Map<String, dynamic> plant) async {
    final id = plant['permanent_id'] as String;
    _plants[id] = Map<String, dynamic>.from(plant)
      ..['last_modified'] = _now().toIso8601String()
      ..['is_deleted'] = plant['is_deleted'] ?? false;
  }

  @override
  Future<void> deletePlant(String plantId) async {
    final row = _plants[plantId] ?? {'permanent_id': plantId};
    row['is_deleted'] = true;
    row['last_modified'] = _now().toIso8601String();
    _plants[plantId] = row;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlants() async =>
      _plants.values.where((r) => r['is_deleted'] != true).toList();

  @override
  Future<RemoteChangesPage> fetchChangesSince(
    DateTime? cursor, {
    int limit = 1000,
  }) async =>
      _since(_plants.values, cursor, limit);

  @override
  Future<void> upsertSetting(Map<String, dynamic> row) async {
    final key = row['key'] as String;
    _settings[key] = Map<String, dynamic>.from(row)
      ..['last_modified'] = _now().toIso8601String();
  }

  @override
  Future<RemoteChangesPage> fetchSettingsSince(
    DateTime? cursor, {
    int limit = 1000,
  }) async =>
      _since(_settings.values, cursor, limit);

  @override
  Future<DateTime?> updateLastSync() async => _now();

  RemoteChangesPage _since(
    Iterable<Map<String, dynamic>> rows,
    DateTime? cursor,
    int limit,
  ) {
    final filtered = rows.where((r) {
      if (cursor == null) return true;
      final lm = DateTime.tryParse(r['last_modified']?.toString() ?? '');
      return lm != null && lm.isAfter(cursor);
    }).toList()
      ..sort((a, b) => (a['last_modified'] as String)
          .compareTo(b['last_modified'] as String));
    final page = filtered.take(limit).toList();
    return RemoteChangesPage(
      rows: page,
      newCursor: page.isEmpty
          ? null
          : DateTime.tryParse(page.last['last_modified']?.toString() ?? ''),
    );
  }

  bool isDeletedOnServer(String id) => _plants[id]?['is_deleted'] == true;
}

// ==================== FAKES ====================

class FakeAuth implements AuthRepository {
  @override
  AuthUser? get currentUser =>
      AuthUser(id: 'u1', email: 't@t.t', createdAt: DateTime(2026));
  @override
  Stream<AuthStatus> get authStatusStream => const Stream.empty();
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String email, String password) async {}
  @override
  Future<void> signOut() async {}
}

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

/// Одно «устройство»: собственные Hive-боксы + репозиторий + движок.
class Device {
  Device._(this.repo, this.outbox, this.state, this.conflicts, this.engine);

  final FakeRepo repo;
  final SyncOutbox outbox;
  final SyncStateStore state;
  final SyncConflictStore conflicts;
  final FullSyncEngine engine;

  static Future<Device> create(
    String tag,
    InMemoryServer server,
    AuthRepository auth,
    SettingsSyncAdapter settings,
  ) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final repo = FakeRepo();
    final outbox = SyncOutbox(await Hive.openBox<String>('cdo_${tag}_$ts'));
    final state =
        SyncStateStore(await Hive.openBox<String>('cds_${tag}_$ts'));
    final conflicts =
        SyncConflictStore(await Hive.openBox<String>('cdc_${tag}_$ts'));
    final engine = FullSyncEngine(
      outbox: outbox,
      remote: server,
      plants: repo,
      auth: auth,
      state: state,
      conflicts: conflicts,
      settings: settings,
    );
    return Device._(repo, outbox, state, conflicts, engine);
  }
}

// ==================== HELPERS ====================

Plant _plant(String id, {String status = 'alive'}) => Plant(
      permanentId: id,
      latinName: 'Cactus $id',
      status: status,
      year: 2024,
      customNumber: 1,
      category: 'sown',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryServer server;
  late Device a;
  late Device b;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('cross_device_');
    Hive.init(dir.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = InMemoryServer();
    final auth = FakeAuth();
    final settings = SettingsSyncAdapter(await SharedPreferences.getInstance());
    a = await Device.create('a', server, auth, settings);
    b = await Device.create('b', server, auth, settings);
  });

  // c1: A добавляет → B pull → растение на B
  test('c1: добавление на A появляется на B', () async {
    final p = _plant('p1');
    await a.repo.addPlant(p);
    await a.outbox.enqueue('p1', SyncOutbox.opUpsert);
    await a.engine.sync();

    await b.engine.sync();

    final onB = await b.repo.getPlantById('p1');
    expect(onB, isNotNull);
    expect(onB!.latinName, 'Cactus p1');
  });

  // c2: A обновляет статус → B pull → статус обновлён
  test('c2: обновление статуса на A приезжает на B', () async {
    await a.repo.addPlant(_plant('p1'));
    await a.outbox.enqueue('p1', SyncOutbox.opUpsert);
    await a.engine.sync();
    await b.engine.sync();
    expect((await b.repo.getPlantById('p1'))!.status, 'alive');

    final updated = _plant('p1', status: 'dormant');
    await a.repo.updatePlant(updated);
    await a.outbox.enqueue('p1', SyncOutbox.opUpsert);
    await a.engine.sync();

    await b.engine.sync();

    expect((await b.repo.getPlantById('p1'))!.status, 'dormant');
  });

  // c3: tombstone не «воскрешает» растение
  test('c3: удаление на A → tombstone, B удаляет и не воскрешает', () async {
    await a.repo.addPlant(_plant('p1'));
    await a.outbox.enqueue('p1', SyncOutbox.opUpsert);
    await a.engine.sync();
    await b.engine.sync();
    expect(await b.repo.getPlantById('p1'), isNotNull);

    // A удаляет → tombstone на сервере
    await a.repo.deletePlant('p1');
    await a.outbox.enqueue('p1', SyncOutbox.opDelete);
    await a.engine.sync();
    expect(server.isDeletedOnServer('p1'), isTrue);

    // B pull → удалено локально
    await b.engine.sync();
    expect(await b.repo.getPlantById('p1'), isNull);
    expect(b.outbox.length, 0); // петли нет — pull не enqueues

    // Повторный sync с B: растение НЕ воскресает ни на сервере, ни локально
    await b.engine.sync();
    expect(await b.repo.getPlantById('p1'), isNull);
    expect(server.isDeletedOnServer('p1'), isTrue);

    // A тоже не воскрешает
    await a.engine.sync();
    expect(await a.repo.getPlantById('p1'), isNull);
  });

  // c4: конфликт LWW — B новее, A принимает версию B, локальная — в архив
  test('c4: LWW-конфликт: версия B побеждает на A, версия A в архиве',
      () async {
    // Базовое состояние: растение синхронизировано на обоих устройствах
    await a.repo.addPlant(_plant('p1', status: 'alive'));
    await a.outbox.enqueue('p1', SyncOutbox.opUpsert);
    await a.engine.sync();
    await b.engine.sync();

    // A меняет локально, но ещё НЕ пушил (запись dirty в outbox)
    await a.repo.updatePlant(_plant('p1', status: 'a_version'));
    await a.outbox.enqueue('p1', SyncOutbox.opUpsert);

    // B меняет ПОЗЖЕ и пушит → серверный last_modified новее штампа A
    await b.repo.updatePlant(_plant('p1', status: 'b_version'));
    await b.outbox.enqueue('p1', SyncOutbox.opUpsert);
    await b.engine.sync();

    // A подтягивает изменения: remote новее stored stamp + local dirty →
    // конфликт, remote (B) применяется, локальная версия A → архив
    await a.engine.pullRemoteChanges();

    expect((await a.repo.getPlantById('p1'))!.status, 'b_version');
    final conflicts = a.conflicts.listConflicts();
    expect(conflicts.length, 1);
    expect(conflicts.first.type, 'edit_vs_edit');
    expect(
      (conflicts.first.localJson?['status']) as String?,
      'a_version',
    );
    // Outbox на A очищен — версия A не перезапишет победившую B
    expect(a.outbox.contains('p1'), isFalse);
  });
}
