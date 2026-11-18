import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/auth/auth_repository.dart';
import 'package:my_cactus/core/auth/auth_state.dart';
import 'package:my_cactus/core/config/feature_flags.dart';
import 'package:my_cactus/core/sync/settings_sync_adapter.dart';
import 'package:my_cactus/core/sync/sync_actions.dart';
import 'package:my_cactus/core/sync/sync_conflicts.dart';
import 'package:my_cactus/core/sync/sync_engine.dart';
import 'package:my_cactus/core/sync/sync_engine_full.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/core/sync/sync_scheduler.dart';
import 'package:my_cactus/core/sync/sync_state_store.dart';
import 'package:my_cactus/data/datasources/remote/plant_remote_datasource.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:my_cactus/presentation/providers/cloud_storage_provider.dart';
import 'package:my_cactus/presentation/providers/plant_crud_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_cactus/injection_container.dart';

// ==================== FAKES ====================

class CountingEngine implements SyncEngine {
  var syncCalls = 0;

  @override
  Stream<SyncStatus> get syncStatusStream => const Stream.empty();

  @override
  Future<void> sync() async => syncCalls++;

  @override
  Future<void> pushLocalChanges() async {}

  @override
  Future<void> pullRemoteChanges() async {}
}

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
  var touched = false;
  @override
  Future<List<Map<String, dynamic>>> fetchPlants() async {
    touched = true;
    return [];
  }

  @override
  Future<void> uploadPlant(Map<String, dynamic> plant) async =>
      touched = true;
  @override
  Future<void> deletePlant(String plantId) async => touched = true;
  @override
  Future<DateTime?> updateLastSync() async {
    touched = true;
    return null;
  }

  @override
  Future<RemoteChangesPage> fetchChangesSince(
    DateTime? cursor, {
    int limit = 1000,
  }) async =>
      RemoteChangesPage(rows: [], newCursor: null);

  @override
  Future<void> upsertSetting(Map<String, dynamic> row) async =>
      touched = true;
  @override
  Future<RemoteChangesPage> fetchSettingsSince(
    DateTime? cursor, {
    int limit = 1000,
  }) async =>
      RemoteChangesPage(rows: [], newCursor: null);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingEngine engine;
  late SyncActions actions;
  late SyncOutbox outbox;
  late Box<String> outboxBox;
  late SyncScheduler scheduler;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('wiring_test_');
    Hive.init(dir.path);
  });

  setUp(() async {
    outboxBox = await Hive.openBox<String>(
        'wo_${DateTime.now().microsecondsSinceEpoch}');
    outbox = SyncOutbox(outboxBox);
    engine = CountingEngine();
    actions = SyncActions(engine);
    scheduler = SyncScheduler(
      engine: engine,
      outbox: outbox,
      debounce: const Duration(milliseconds: 50),
      periodic: const Duration(hours: 1), // periodic в тестах не мешает
      enabledCheck: () => true,
    );
    SharedPreferences.setMockInitialValues({});
    await sl.reset();
    FeatureFlags.clearAllLocalOverrides();
  });

  tearDown(() async {
    scheduler.stop();
    await outboxBox.deleteFromDisk();
    FeatureFlags.clearAllLocalOverrides();
  });

  // w1: старт вызывает engine.sync
  test('w1: startup вызывает engine.sync', () async {
    await actions.startup();
    expect(engine.syncCalls, 1);
  });

  // w2: кнопка вызывает engine.sync
  test('w2: manual (кнопка) вызывает engine.sync', () async {
    await actions.manual();
    expect(engine.syncCalls, 1);
  });

  // w3: старый record-sync НЕ вызывается при флаге false
  test('w3: legacyYandexRecordSync default false → record-путь gated', () async {
    expect(FeatureFlags.isEnabled(FeatureFlag.legacyYandexRecordSync), isFalse);

    sl.registerSingleton<PlantRepository>(FakePlantRepository());
    sl.registerSingleton<SyncOutbox>(outbox);
    final cloud = CloudStorageProvider();
    final plantProvider = PlantCrudProvider();

    // Вызов фасада возвращается мгновенно — syncManager не трогается
    await cloud.syncData(plantProvider);
    await cloud.loadDataFromCloud(plantProvider);
    // Если бы gate не сработал — SyncManager пошёл бы в сеть/упал
  });

  // w4: resume → sync
  test('w4: resume триггерит sync', () async {
    scheduler.start();
    scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(engine.syncCalls, 1);
  });

  // w5: debounce — 5 быстрых enqueue → 1 sync
  test('w5: debounce схлопывает пачку enqueue', () async {
    scheduler.start();
    for (var i = 0; i < 5; i++) {
      await outbox.enqueue('p$i', SyncOutbox.opUpsert);
    }
    await Future.delayed(const Duration(milliseconds: 150));
    expect(engine.syncCalls, 1);
  });

  // w6: photo-sync и backup НЕ gated флагом legacyYandexRecordSync
  test('w6: фото/бэкап не тронуты флагом', () {
    // Старый record-путь gated только в cloud_storage_provider:
    // фото и бэкап не должны содержать ссылок на флаг.
    final photoSrc =
        File('lib/services/photo_sync_service.dart').readAsStringSync();
    final backupSrc =
        File('lib/services/backup/auto_backup_service.dart').readAsStringSync();
    expect(photoSrc.contains('legacyYandexRecordSync'), isFalse);
    expect(backupSrc.contains('legacyYandexRecordSync'), isFalse);
  });

  // w7: без аккаунта → engine no-op, приложение не падает
  test('w7: без аккаунта — no-op, не падает', () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final stateBox = await Hive.openBox<String>('ws_$ts');
    final confBox = await Hive.openBox<String>('wc_$ts');
    SharedPreferences.setMockInitialValues({});
    final remote = FakeRemote();
    final auth = FakeAuthRepository(); // user = null
    final realEngine = FullSyncEngine(
      outbox: outbox,
      remote: remote,
      plants: FakePlantRepository(),
      auth: auth,
      state: SyncStateStore(stateBox),
      conflicts: SyncConflictStore(confBox),
      settings: SettingsSyncAdapter(await SharedPreferences.getInstance()),
    );

    await realEngine.sync(); // не бросает
    expect(remote.touched, isFalse);
    expect(realEngine.currentStatus, SyncStatus.idle);

    await stateBox.deleteFromDisk();
    await confBox.deleteFromDisk();
  });
}
