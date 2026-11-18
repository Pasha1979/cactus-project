import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/auth/auth_repository.dart';
import 'package:my_cactus/core/auth/auth_state.dart';
import 'package:my_cactus/core/sync/sync_conflicts.dart';
import 'package:my_cactus/core/sync/sync_engine.dart';
import 'package:my_cactus/core/sync/sync_engine_full.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/core/sync/sync_state_store.dart';
import 'package:my_cactus/data/datasources/remote/plant_remote_datasource.dart';
import 'package:my_cactus/data/mappers/plant_sync_mapper.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';

// ==================== FAKES ====================

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
  final rows = <Map<String, dynamic>>[]; // «таблица» plants на сервере
  var fetchCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPlants() async => rows;

  @override
  Future<void> uploadPlant(Map<String, dynamic> plant) async {}

  @override
  Future<void> deletePlant(String plantId) async {}

  @override
  Future<DateTime?> updateLastSync() async => null;

  @override
  Future<RemoteChangesPage> fetchChangesSince(
    DateTime? cursor, {
    int limit = 1000,
  }) async {
    fetchCalls++;
    final filtered = rows
        .where((r) =>
            cursor == null ||
            DateTime.parse(r['last_modified'] as String).isAfter(cursor))
        .toList()
      ..sort((a, b) => (a['last_modified'] as String)
          .compareTo(b['last_modified'] as String));
    final page = filtered.take(limit).toList();
    return RemoteChangesPage(
      rows: page,
      newCursor: page.isEmpty
          ? null
          : DateTime.parse(page.last['last_modified'] as String),
    );
  }
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

AuthUser _user() => AuthUser(
      id: 'u1',
      email: 't@t.t',
      createdAt: DateTime(2026),
    );

Plant _local(String id, {String status = 'alive'}) => Plant(
      permanentId: id,
      latinName: 'Local $id',
      status: status,
      year: 2024,
      customNumber: 1,
      category: 'sown',
    );

Map<String, dynamic> _row(
  String id, {
  String stamp = '2026-01-01T00:00:00Z',
  bool deleted = false,
  String status = 'alive',
}) =>
    plantToSyncRow(
      _local(id, status: status),
      'u1',
    )
      ..addAll({
        'last_modified': stamp,
        'is_deleted': deleted,
        'created_at': '2026-01-01T00:00:00Z',
        'id': 'srv-$id',
      });

void main() {
  late Box<String> outboxBox;
  late Box<String> stateBox;
  late Box<String> conflictsBox;
  late SyncOutbox outbox;
  late SyncStateStore state;
  late SyncConflictStore conflicts;
  late FakeAuthRepository auth;
  late FakeRemote remote;
  late FakePlantRepository repo;
  late FullSyncEngine engine;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('pull_test_');
    Hive.init(dir.path);
  });

  setUp(() async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    outboxBox = await Hive.openBox<String>('po_$ts');
    stateBox = await Hive.openBox<String>('ps_$ts');
    conflictsBox = await Hive.openBox<String>('pc_$ts');
    outbox = SyncOutbox(outboxBox);
    state = SyncStateStore(stateBox);
    conflicts = SyncConflictStore(conflictsBox);
    auth = FakeAuthRepository()..user = _user();
    remote = FakeRemote();
    repo = FakePlantRepository();
    engine = FullSyncEngine(
      outbox: outbox,
      remote: remote,
      plants: repo,
      auth: auth,
      state: state,
      conflicts: conflicts,
    );
  });

  tearDown(() async {
    await outboxBox.deleteFromDisk();
    await stateBox.deleteFromDisk();
    await conflictsBox.deleteFromDisk();
  });

  // p1: remote новая запись → применена локально
  test('p1: новая запись применена', () async {
    remote.rows.add(_row('p1', stamp: '2026-02-01T10:00:00Z'));

    await engine.pullRemoteChanges();

    expect(repo.store.containsKey('p1'), isTrue);
    expect(repo.store['p1']!.status, 'alive');
    expect(state.pullCursor, DateTime.parse('2026-02-01T10:00:00Z'));
    expect(engine.currentStatus, SyncStatus.idle);
  });

  // p2: tombstone → локальное удаление, outbox НЕ пополняется
  test('p2: tombstone удаляет локально, петли нет', () async {
    repo.store['p2'] = _local('p2');
    remote.rows.add(_row('p2', deleted: true));

    await engine.pullRemoteChanges();

    expect(repo.store.containsKey('p2'), isFalse);
    expect(outbox.length, 0); // guard: удаление не ушло в outbox
  });

  // p3: local не dirty + remote новее → перезапись
  test('p3: чистый local перезаписан remote', () async {
    repo.store['p3'] = _local('p3', status: 'alive');
    remote.rows.add(_row('p3', status: 'flower'));

    await engine.pullRemoteChanges();

    expect(repo.store['p3']!.status, 'flower');
  });

  // p4: local dirty + remote не менялся → local сохранён
  test('p4: dirty local сохранён при старом remote', () async {
    repo.store['p4'] = _local('p4', status: 'flower');
    await outbox.enqueue('p4', SyncOutbox.opUpsert);
    await state.setStamp('p4', DateTime.parse('2026-03-01T00:00:00Z'));
    // remote тот же штамп — не новее сохранённого
    remote.rows.add(_row('p4', stamp: '2026-03-01T00:00:00Z', status: 'dead'));

    await engine.pullRemoteChanges();

    expect(repo.store['p4']!.status, 'flower'); // local не перезаписан
    expect(outbox.length, 1); // остаётся в очереди на push
  });

  // p5: local dirty + remote новее → конфликт в архиве, remote применён
  test('p5: конфликт → архив + remote применён', () async {
    repo.store['p5'] = _local('p5', status: 'flower');
    await outbox.enqueue('p5', SyncOutbox.opUpsert);
    await state.setStamp('p5', DateTime.parse('2026-03-01T00:00:00Z'));
    remote.rows.add(_row('p5', stamp: '2026-04-01T00:00:00Z', status: 'dead'));

    await engine.pullRemoteChanges();

    expect(repo.store['p5']!.status, 'dead'); // remote победил (LWW)
    expect(outbox.length, 0); // push не нужен — remote применён
    final list = conflicts.listConflicts();
    expect(list, hasLength(1));
    expect(list.single.type, 'edit_vs_edit');
    expect(list.single.permanentId, 'p5');
    expect(list.single.localJson!['status'], 'flower'); // копия сохранена
    expect(state.stampFor('p5'), DateTime.parse('2026-04-01T00:00:00Z'));
  });

  // p6: курсор двигается только серверными значениями (проверка кода —
  // в pullRemoteChanges cursor берётся из page.newCursor/row.last_modified)
  test('p6: курсор = серверный last_modified последней строки', () async {
    remote.rows.addAll([
      _row('a', stamp: '2026-05-01T00:00:00Z'),
      _row('b', stamp: '2026-05-03T00:00:00Z'),
      _row('c', stamp: '2026-05-02T00:00:00Z'),
    ]);

    await engine.pullRemoteChanges();

    expect(state.pullCursor, DateTime.parse('2026-05-03T00:00:00Z'));
  });

  // p7: пагинация — >limit строк тянется несколькими страницами
  test('p7: пагинация несколькими страницами', () async {
    for (var i = 0; i < 5; i++) {
      remote.rows.add(_row('pg$i', stamp: '2026-06-0${i + 1}T00:00:00Z'));
    }
    // limit=3 вставим через подкласс — тут проверяем логику движка:
    // эмулируем лимит 2 через обёртку remote
    final limitedRemote = _LimitedFakeRemote(remote.rows, 2);
    final eng = FullSyncEngine(
      outbox: outbox,
      remote: limitedRemote,
      plants: repo,
      auth: auth,
      state: state,
      conflicts: conflicts,
      pageLimit: 2,
    );

    await eng.pullRemoteChanges();

    expect(limitedRemote.fetchCalls, greaterThanOrEqualTo(3));
    expect(repo.store.length, 5); // все строки доехали
    expect(state.pullCursor, DateTime.parse('2026-06-05T00:00:00Z'));
  });

  // p8: post-sync callback вызван после pull
  test('p8: onPullComplete вызван', () async {
    var called = 0;
    engine.onPullComplete = () async => called++;
    remote.rows.add(_row('x'));

    await engine.pullRemoteChanges();

    expect(called, 1);
  });
}

/// Fake с уменьшенным лимитом страниц для теста пагинации.
class _LimitedFakeRemote extends FakeRemote {
  _LimitedFakeRemote(this._rows, this._limit);

  final List<Map<String, dynamic>> _rows;
  final int _limit;

  @override
  int get fetchCalls => _calls;
  int _calls = 0;

  @override
  set fetchCalls(int v) => _calls = v;

  @override
  Future<RemoteChangesPage> fetchChangesSince(
    DateTime? cursor, {
    int limit = 1000,
  }) async {
    _calls++;
    final filtered = _rows
        .where((r) =>
            cursor == null ||
            DateTime.parse(r['last_modified'] as String).isAfter(cursor))
        .toList()
      ..sort((a, b) => (a['last_modified'] as String)
          .compareTo(b['last_modified'] as String));
    final page = filtered.take(_limit).toList();
    return RemoteChangesPage(
      rows: page,
      newCursor: page.isEmpty
          ? null
          : DateTime.parse(page.last['last_modified'] as String),
    );
  }
}
