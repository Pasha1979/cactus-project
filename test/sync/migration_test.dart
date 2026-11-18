import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/auth/auth_repository.dart';
import 'package:my_cactus/core/auth/auth_state.dart';
import 'package:my_cactus/core/config/app_constants.dart';
import 'package:my_cactus/core/sync/initial_migration.dart';
import 'package:my_cactus/core/sync/migration_backup.dart';
import 'package:my_cactus/core/sync/settings_sync_adapter.dart';
import 'package:my_cactus/core/sync/sync_engine.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/core/sync/sync_state_store.dart';
import 'package:my_cactus/data/datasources/remote/plant_remote_datasource.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== FAKES ====================

class FakeAuth implements AuthRepository {
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

class FakeRemote implements PlantRemoteDataSource {
  List<Map<String, dynamic>> plants = [];
  List<Map<String, dynamic>> settings = [];
  DateTime serverNow = DateTime.utc(2026, 1, 1, 12);

  @override
  Future<List<Map<String, dynamic>>> fetchPlants() async => plants;
  @override
  Future<void> uploadPlant(Map<String, dynamic> plant) async {}
  @override
  Future<void> deletePlant(String plantId) async {}
  @override
  Future<DateTime?> updateLastSync() async => serverNow;
  @override
  Future<RemoteChangesPage> fetchChangesSince(DateTime? cursor,
          {int limit = 1000}) async =>
      RemoteChangesPage(rows: const [], newCursor: null);
  @override
  Future<void> upsertSetting(Map<String, dynamic> row) async {}
  @override
  Future<RemoteChangesPage> fetchSettingsSince(DateTime? cursor,
          {int limit = 1000}) async =>
      RemoteChangesPage(rows: settings, newCursor: null);
}

/// Движок, записывающий порядок вызовов и «сливающий» outbox при успехе.
class RecordingEngine implements SyncEngine {
  RecordingEngine(this.calls, {this.drainOutbox, this.leaveOutbox = false});

  final List<String> calls;
  final SyncOutbox? drainOutbox;
  bool leaveOutbox;
  List<String> pendingAtSync = [];

  @override
  Stream<SyncStatus> get syncStatusStream => const Stream.empty();

  @override
  Future<void> sync() async {
    calls.add('engine.sync');
    pendingAtSync = drainOutbox == null
        ? []
        : drainOutbox!.pending().map((e) => e.recordId).toList();
    if (drainOutbox != null && !leaveOutbox) {
      for (final e in drainOutbox!.pending()) {
        await drainOutbox!.remove(e.recordId);
      }
    }
  }

  @override
  Future<void> pushLocalChanges() async {}
  @override
  Future<void> pullRemoteChanges() async {}
}

/// Бэкап со шпионом порядка вызовов.
class SpyBackup extends MigrationBackup {
  SpyBackup(this.calls, {required super.plants, required super.settings,
      required super.state, super.docsDir});

  final List<String> calls;

  @override
  Future<String> createBackup() async {
    calls.add('backup');
    return super.createBackup();
  }
}

// ==================== HELPERS ====================

Plant _plant(String id) => Plant(
      permanentId: id,
      latinName: 'Cactus $id',
      status: 'alive',
      year: 2024,
      customNumber: 1,
      category: 'sown',
    );

AuthUser _user() =>
    AuthUser(id: 'u1', email: 't@t.t', createdAt: DateTime(2026));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late Box<String> outboxBox;
  late Box<String> stateBox;
  late SyncOutbox outbox;
  late SyncStateStore state;
  late SettingsSyncAdapter adapter;
  late FakeAuth auth;
  late FakeRepo repo;
  late FakeRemote remote;
  late List<String> calls;
  late RecordingEngine engine;
  late SpyBackup backup;
  late InitialMigration migration;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('migration_test_');
    Hive.init(tmpDir.path);
  });

  setUp(() async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    outboxBox = await Hive.openBox<String>('mo_$ts');
    stateBox = await Hive.openBox<String>('ms_$ts');
    outbox = SyncOutbox(outboxBox);
    state = SyncStateStore(stateBox);
    SharedPreferences.setMockInitialValues({
      PrefsKeys.globalWateringDates: ['2026-01-10'],
      PrefsKeys.winteringTemp: 5.0,
    });
    adapter = SettingsSyncAdapter(await SharedPreferences.getInstance());
    auth = FakeAuth()..user = _user();
    repo = FakeRepo()
      ..store['p1'] = _plant('p1')
      ..store['p2'] = _plant('p2');
    remote = FakeRemote();
    calls = [];
    engine = RecordingEngine(calls, drainOutbox: outbox);
    backup = SpyBackup(
      calls,
      plants: repo,
      settings: adapter,
      state: state,
      docsDir: () async => tmpDir,
    );
    migration = InitialMigration(
      auth: auth,
      plants: repo,
      outbox: outbox,
      state: state,
      engine: engine,
      remote: remote,
      backup: backup,
      settings: adapter,
    );
  });

  tearDown(() async {
    await outboxBox.deleteFromDisk();
    await stateBox.deleteFromDisk();
  });

  // m1: bulk enqueue всех локальных plants + 6 ключей
  test('m1: bulk enqueue plants + 6 legacy-ключей', () async {
    await migration.run();
    expect(engine.pendingAtSync, containsAll(['p1', 'p2']));
    expect(
      engine.pendingAtSync.where((i) => i.startsWith('settings:')).length,
      SettingsSyncAdapter.syncedKeys.length,
    );
    expect(state.getValue('migration_v1_done'), 'true');
  });

  // m2: push проставляет серверные stamps в sync_state
  test('m2: серверные stamps записаны в sync_state', () async {
    final lm = DateTime.utc(2026, 2, 2, 10);
    remote.plants = [
      {'permanent_id': 'p1', 'last_modified': lm.toIso8601String()},
      {'permanent_id': 'p2', 'last_modified': lm.toIso8601String()},
    ];
    await migration.run();
    expect(state.stampFor('p1'), lm);
    expect(state.stampFor('p2'), lm);
  });

  // m3: курсоры = sync_now после push (нет self-pull конфликтов)
  test('m3: курсоры = серверное now после push', () async {
    await migration.run();
    expect(state.pullCursor, remote.serverNow);
    expect(state.settingsCursor, remote.serverNow);
  });

  // m4: повторный run при done=true → ничего не делает
  test('m4: идемпотентность — done=true → no-op', () async {
    await migration.run(); // первый запуск — done
    calls.clear();
    engine.pendingAtSync = [];
    final again = await migration.run();
    expect(again, isTrue);
    expect(calls, isEmpty); // ни backup, ни sync не вызывались
    expect(outbox.length, 0);
  });

  // m5: автобэкап создаётся ДО engine.sync()
  test('m5: backup до engine.sync (порядок вызовов)', () async {
    await migration.run();
    expect(calls.indexOf('backup'), lessThan(calls.indexOf('engine.sync')));
  });

  // m6: rollback восстанавливает plants+prefs и сбрасывает флаг
  test('m6: rollback восстанавливает данные и сбрасывает done', () async {
    await migration.run();
    final backupPath = state.getValue('migration_backup_path')!;
    expect(File(backupPath).existsSync(), isTrue);

    // «Ломаем» локальные данные
    repo.store.clear();
    await adapter.writeLegacy(PrefsKeys.globalWateringDates, <String>[]);

    await backup.rollback(backupPath);

    expect(repo.store.keys, containsAll(['p1', 'p2']));
    expect(
      (await SharedPreferences.getInstance())
          .getStringList(PrefsKeys.globalWateringDates),
      ['2026-01-10'],
    );
    expect(state.getValue('migration_v1_done'), isNull);
  });

  // m7: без аккаунта → отложено, флаг не стоит, данные целы
  test('m7: без аккаунта — отложено, ничего не трогаем', () async {
    auth.user = null;
    final result = await migration.run();
    expect(result, isFalse);
    expect(calls, isEmpty); // ни backup, ни sync
    expect(state.getValue('migration_v1_done'), isNull);
    expect(outbox.length, 0);
    expect(repo.store.length, 2);
  });

  // m8: частичный сбой push → флаг не стоит, остаток в outbox
  test('m8: сбой push → done нет, outbox сохраняет остаток', () async {
    engine.leaveOutbox = true; // движок «не смог» отправить
    final result = await migration.run();
    expect(result, isFalse);
    expect(state.getValue('migration_v1_done'), isNull);
    expect(outbox.length, greaterThan(0));
    // Повторный вызов домигрирует
    engine.leaveOutbox = false;
    expect(await migration.run(), isTrue);
  });

  // m9 (бонус): отчёт сверки записан в sync_state
  test('m9: migration_report содержит counts local vs remote', () async {
    remote.plants = [
      {'permanent_id': 'p1', 'last_modified': '2026-02-02T10:00:00Z'},
      {'permanent_id': 'p2', 'last_modified': '2026-02-02T10:00:00Z'},
    ];
    remote.settings = [
      {'key': PrefsKeys.globalWateringDates, 'is_deleted': false},
      {'key': PrefsKeys.winteringTemp, 'is_deleted': false},
    ];
    await migration.run();
    final report = jsonDecode(state.getValue('migration_report')!)
        as Map<String, dynamic>;
    expect(report['plants_local'], 2);
    expect(report['plants_remote'], 2);
    expect(report['settings_local'], 2); // 2 ключа со значениями из 6
    expect(report['settings_remote'], 2);
    expect(report['ok'], isTrue);
  });
}
