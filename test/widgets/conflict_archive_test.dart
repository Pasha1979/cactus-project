import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/sync/sync_conflicts.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:my_cactus/injection_container.dart';
import 'package:my_cactus/presentation/providers/plant_crud_provider.dart';
import 'package:my_cactus/presentation/screens/settings/about_screen.dart';
import 'package:my_cactus/presentation/screens/settings/conflict_archive_screen.dart';
import 'package:provider/provider.dart';

// ==================== FAKES ====================

class SpyRepo implements PlantRepository {
  final store = <String, Plant>{};
  final updates = <Plant>[];
  @override
  Future<Plant?> getPlantById(String id) async => store[id];
  @override
  Future<void> addPlant(Plant p) async => store[p.permanentId] = p;
  @override
  Future<void> updatePlant(Plant p) async {
    updates.add(p);
    store[p.permanentId] = p;
  }

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
  late Box<String> outboxBox;
  late SyncOutbox outbox;
  late Box<String> emptyConfBox;
  late Box<String> oneConfBox;
  late SyncConflictStore emptyStore;
  late SyncConflictStore oneStore;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('conf_ui_');
    Hive.init(dir.path);
  });

  /// Все Hive-операции — в setUp (реальный async-контекст; внутри
  /// testWidgets выполняется FakeAsync и disk I/O зависает).
  setUp(() async {
    repo = SpyRepo();
    outboxBox = await Hive.openBox<String>(
        'cout_${DateTime.now().microsecondsSinceEpoch}');
    outbox = SyncOutbox(outboxBox);
    sl.registerSingleton<PlantRepository>(repo);
    sl.registerSingleton<SyncOutbox>(outbox);

    emptyConfBox = await Hive.openBox<String>(
        'ce_${DateTime.now().microsecondsSinceEpoch}');
    emptyStore = SyncConflictStore(emptyConfBox);

    oneConfBox = await Hive.openBox<String>(
        'co_${DateTime.now().microsecondsSinceEpoch}');
    await oneConfBox.put(
      'p1:1',
      jsonEncode({
        'type': 'edit_vs_edit',
        'permanentId': 'p1',
        'localJson':
            _plant('p1').copyWith(latinName: 'Мой кактус').toJson(),
        'remoteJson': <String, dynamic>{},
        'at': '2026-11-20T10:00:00.000',
      }),
    );
    oneStore = SyncConflictStore(oneConfBox);
  });

  tearDown(() async {
    await outboxBox.deleteFromDisk();
    await emptyConfBox.deleteFromDisk();
    await oneConfBox.deleteFromDisk();
    await sl.reset();
  });

  SyncConflict conflict() => oneStore.listConflicts().single;

  // k1: пункт входа скрыт при N=0 и виден при N>0.
  testWidgets('k1: вход виден только при N>0', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConflictArchiveTile(store: emptyStore)),
    ));
    expect(find.textContaining('Архив конфликтов'), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConflictArchiveTile(store: oneStore)),
    ));
    await tester.pump();
    expect(find.textContaining('Архив конфликтов синхронизации (1)'),
        findsOneWidget);
  });

  // k2: «Вернуть локальную» → updatePlant + outbox enqueue + removeConflict.
  // Проверяет restoreLocalConflict — ту же функцию, что вызывает кнопка
  // после подтверждения (реальный async, test() — не testWidgets).
  test('k2: восстановление идёт через updatePlant → outbox', () async {
    final provider = PlantCrudProvider();
    await provider.addPlant(_plant('p1'));

    await restoreLocalConflict(
      provider: provider,
      store: oneStore,
      conflict: conflict(),
    );

    expect(repo.updates.single.latinName, 'Мой кактус',
        reason: 'локальная версия восстановлена штатным updatePlant');
    expect(oneStore.length, 0, reason: 'запись удалена из архива');
    expect(outboxBox.keys.contains('p1'), isTrue,
        reason: 'восстановление ушло в outbox на синхронизацию');
  });

  // k3: «Оставить облачную» → только removeConflict, без updatePlant.
  test('k3: оставить облачную — только очистка записи', () async {
    final provider = PlantCrudProvider();
    await provider.addPlant(_plant('p1'));

    await keepRemoteConflict(store: oneStore, conflict: conflict());

    expect(repo.updates, isEmpty,
        reason: 'облачная версия уже применена — updatePlant не нужен');
    expect(oneStore.length, 0);
  });

  // k4: отмена в диалоге — архив и растение не тронуты (без I/O в зоне
  // FakeAsync: диалог закрывается до начала реальных операций).
  testWidgets('k4: отмена не меняет ничего', (tester) async {
    final provider = PlantCrudProvider();

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<PlantCrudProvider>.value(
        value: provider,
        child: Scaffold(body: ConflictArchiveScreen(store: oneStore)),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Вернуть мою локальную версию'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Отмена'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.updates, isEmpty);
    expect(oneStore.length, 1, reason: 'запись осталась в архиве');
  });
}
