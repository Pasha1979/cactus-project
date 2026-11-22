import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/sync/sync_conflicts.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/presentation/screens/settings/conflict_archive_screen.dart';
import 'package:provider/provider.dart';
import 'package:my_cactus/injection_container.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:my_cactus/presentation/providers/plant_crud_provider.dart';

// Golden-скриншоты архива конфликтов (аудит 4.3, H2).
// Генерация/обновление PNG:
//   flutter test test/widgets/conflict_archive_golden_test.dart --update-goldens
// PNG в test/widgets/goldens/conflict_*.png — скриншот-артефакты
// (рендер движком Flutter — единый для Android и Windows).

class _FakeRepo implements PlantRepository {
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

Plant _plant(String id, String name) => Plant(
      permanentId: id,
      latinName: name,
      status: 'alive',
      year: 2024,
      customNumber: 1,
      category: 'sown',
    );

/// Грузит Roboto и MaterialIcons из кэша Flutter SDK — иначе golden
/// рисует текст и иконки шрифтом-заглушкой (квадраты).
Future<void> _loadSdkFonts() async {
  final roots = <String>[
    Platform.environment['FLUTTER_ROOT'] ?? '',
    r'C:\src\flutter\flutter',
  ];
  final sep = Platform.pathSeparator;
  final fonts = <String, String>{
    'Roboto': 'roboto-regular.ttf',
    'MaterialIcons': 'materialicons-regular.otf',
  };
  for (final root in roots) {
    if (root.isEmpty) continue;
    for (final e in fonts.entries) {
      final file = File(
        '$root${sep}bin${sep}cache${sep}artifacts${sep}material_fonts'
        '$sep${e.value}',
      );
      if (!file.existsSync()) continue;
      final loader = FontLoader(e.key)
        ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
    return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late Box<String> outboxBox;
  late Box<String> confBox;
  late SyncConflictStore store;

  setUpAll(() async {
    await _loadSdkFonts();
    final dir = await Directory.systemTemp.createTemp('conf_golden_');
    Hive.init(dir.path);
  });

  setUp(() async {
    repo = _FakeRepo();
    outboxBox = await Hive.openBox<String>(
        'gout_${DateTime.now().microsecondsSinceEpoch}');
    sl.registerSingleton<PlantRepository>(repo);
    sl.registerSingleton<SyncOutbox>(SyncOutbox(outboxBox));

    confBox = await Hive.openBox<String>(
        'gc_${DateTime.now().microsecondsSinceEpoch}');
    store = SyncConflictStore(confBox);
  });

  tearDown(() async {
    await outboxBox.deleteFromDisk();
    await confBox.deleteFromDisk();
    await sl.reset();
  });

  Future<void> _add(String id, String name, String type) => confBox.put(
        '$id:${DateTime.now().microsecondsSinceEpoch}_$id',
        jsonEncode({
          'type': type,
          'permanentId': id,
          'localJson': _plant(id, name).toJson(),
          'remoteJson': <String, dynamic>{},
          'at': '2026-11-20T10:00:00.000',
        }),
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(460, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final provider = PlantCrudProvider();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: ChangeNotifierProvider<PlantCrudProvider>.value(
        value: provider,
        child: ConflictArchiveScreen(store: store),
      ),
    ));
    // Список конфликтов — синхронный (Hive in-memory), сети/картинок нет.
    await tester.pump();
    await tester.pump();
  }

  // g1: список с 2 конфликтами — кнопки видны.
  testWidgets('g1: список из двух конфликтов', (tester) async {
    // box.put — disk I/O: только в runAsync (FakeAsync-зона его глушит).
    await tester.runAsync(() async {
      await _add('p1', 'Echinocereus reichenbachii', 'edit_vs_edit');
      await _add('p2', 'Gymnocalycium mihanovichii', 'delete_vs_edit');
    });
    await pumpScreen(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/conflict_list.png'),
    );
  });

  // g2: AlertDialog подтверждения восстановления.
  testWidgets('g2: диалог подтверждения восстановления', (tester) async {
    await tester.runAsync(
        () => _add('p1', 'Echinocereus reichenbachii', 'edit_vs_edit'));
    await pumpScreen(tester);

    await tester.tap(find.text('Вернуть мою локальную версию'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/conflict_dialog.png'),
    );
  });

  // g3: пустой список — дружелюбная заглушка.
  testWidgets('g3: пустой архив', (tester) async {
    await pumpScreen(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/conflict_empty.png'),
    );
  });
}
