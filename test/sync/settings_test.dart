import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/auth/auth_repository.dart';
import 'package:my_cactus/core/auth/auth_state.dart';
import 'package:my_cactus/core/config/app_constants.dart';
import 'package:my_cactus/core/sync/settings_sync_adapter.dart';
import 'package:my_cactus/core/sync/sync_conflicts.dart';
import 'package:my_cactus/core/sync/sync_engine_full.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/core/sync/sync_state_store.dart';
import 'package:my_cactus/data/datasources/remote/plant_remote_datasource.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final settingsRows = <Map<String, dynamic>>[];
  final settingsUploaded = <Map<String, dynamic>>[];
  var settingsFetches = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPlants() async => [];
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
  }) async =>
      RemoteChangesPage(rows: [], newCursor: null);

  @override
  Future<void> upsertSetting(Map<String, dynamic> row) async =>
      settingsUploaded.add(row);

  @override
  Future<RemoteChangesPage> fetchSettingsSince(
    DateTime? cursor, {
    int limit = 1000,
  }) async {
    settingsFetches++;
    final filtered = settingsRows
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

AuthUser _user() =>
    AuthUser(id: 'u1', email: 't@t.t', createdAt: DateTime(2026));

Map<String, dynamic> _srow(
  String key, {
  dynamic value,
  String stamp = '2026-01-01T00:00:00Z',
  bool deleted = false,
}) =>
    {
      'key': key,
      'value': value,
      'last_modified': stamp,
      'is_deleted': deleted,
      'user_id': 'u1',
    };

void main() {
  late Box<String> outboxBox;
  late Box<String> stateBox;
  late Box<String> conflictsBox;
  late SyncOutbox outbox;
  late SyncStateStore state;
  late SyncConflictStore conflicts;
  late SharedPreferences prefs;
  late SettingsSyncAdapter adapter;
  late FakeAuthRepository auth;
  late FakeRemote remote;
  late FakePlantRepository repo;
  late FullSyncEngine engine;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('settings_test_');
    Hive.init(dir.path);
  });

  setUp(() async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    outboxBox = await Hive.openBox<String>('so_$ts');
    stateBox = await Hive.openBox<String>('ss_$ts');
    conflictsBox = await Hive.openBox<String>('sc_$ts');
    outbox = SyncOutbox(outboxBox);
    state = SyncStateStore(stateBox);
    conflicts = SyncConflictStore(conflictsBox);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    adapter = SettingsSyncAdapter(prefs);
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
      settings: adapter,
    );
  });

  tearDown(() async {
    await outboxBox.deleteFromDisk();
    await stateBox.deleteFromDisk();
    await conflictsBox.deleteFromDisk();
  });

  // s1: push — изменение полива → строка user_settings с user_id, без client time
  test('s1: push настройки → user_settings row', () async {
    await prefs.setStringList(
        PrefsKeys.globalWateringDates, ['2026-11-18T08:00:00']);
    await outbox.enqueue(
        'settings:${PrefsKeys.globalWateringDates}', SyncOutbox.opUpsert);

    await engine.pushLocalChanges();

    expect(remote.settingsUploaded, hasLength(1));
    final row = remote.settingsUploaded.single;
    expect(row['user_id'], 'u1');
    expect(row['key'], PrefsKeys.globalWateringDates);
    expect(row['value'], ['2026-11-18T08:00:00']);
    expect(row.containsKey('last_modified'), isFalse);
    expect(outbox.length, 0);
  });

  // s2: pull — remote значение → применено в prefs
  test('s2: pull настройки → prefs обновлены', () async {
    remote.settingsRows.add(
        _srow(PrefsKeys.winteringTemp, value: 4.5, stamp: '2026-07-01T00:00:00Z'));

    await engine.pullRemoteChanges();

    expect(prefs.getDouble(PrefsKeys.winteringTemp), 4.5);
    expect(state.settingsCursor, DateTime.parse('2026-07-01T00:00:00Z'));
  });

  // s3: tombstone настройки → ключ удалён из prefs
  test('s3: tombstone настройки удаляет ключ', () async {
    await prefs.setDouble(PrefsKeys.winteringTemp, 4.5);
    remote.settingsRows.add(_srow(PrefsKeys.winteringTemp, deleted: true));

    await engine.pullRemoteChanges();

    expect(prefs.containsKey(PrefsKeys.winteringTemp), isFalse);
  });

  // s4: без аккаунта → no-op
  test('s4: без аккаунта — no-op', () async {
    auth.user = null;
    remote.settingsRows.add(_srow(PrefsKeys.winteringTemp, value: 9.0));
    await outbox.enqueue(
        'settings:${PrefsKeys.winteringTemp}', SyncOutbox.opUpsert);

    await engine.sync();

    expect(remote.settingsUploaded, isEmpty);
    expect(remote.settingsFetches, 0);
    expect(prefs.containsKey(PrefsKeys.winteringTemp), isFalse);
    expect(outbox.length, 1);
  });

  // s5: курсор настроек = серверный last_modified (не client time)
  test('s5: settings_cursor только серверный', () async {
    remote.settingsRows.addAll([
      _srow(PrefsKeys.winteringStart,
          value: '2026-11-01T00:00:00', stamp: '2026-08-01T00:00:00Z'),
      _srow(PrefsKeys.adultImages,
          value: {'p1': 'img.png'}, stamp: '2026-08-03T00:00:00Z'),
    ]);

    await engine.pullRemoteChanges();

    expect(state.settingsCursor, DateTime.parse('2026-08-03T00:00:00Z'));
    expect(prefs.getString(PrefsKeys.winteringStart), '2026-11-01T00:00:00');
    expect(prefs.getString(PrefsKeys.adultImages), '{"p1":"img.png"}');
  });

  // s6: onPullComplete вызван после pull настроек
  test('s6: onPullComplete после pull настроек', () async {
    var called = 0;
    engine.onPullComplete = () async => called++;
    remote.settingsRows.add(_srow(PrefsKeys.winteringTemp, value: 1.0));

    await engine.pullRemoteChanges();

    expect(called, 1);
  });
}
