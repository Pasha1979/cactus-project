import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:my_cactus/injection_container.dart';
import 'package:my_cactus/main.dart' show HomeScreen;
import 'package:my_cactus/presentation/providers/plant_crud_provider.dart';
import 'package:my_cactus/presentation/theme/cactus_theme.dart';

// Golden-скриншот главного экрана («Моя коллекция кактусов»).
// Генерация/обновление PNG:
//   flutter test test/widgets/home_screen_golden_test.dart --update-goldens
// PNG в test/widgets/goldens/. Рендер движком Flutter — единый вид
// для Android и Windows (ширина экрана задаёт мобильный/десктопный layout).

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

/// Грузит Roboto и MaterialIcons из кэша Flutter SDK — иначе golden
/// рисует текст плейсхолдером, а иконки — квадратами.
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

Plant _plant(
  String id,
  String latin, {
  String status = 'in_collection',
  String category = 'purchased',
  int year = 2024,
  int number = 1,
}) =>
    Plant(
      permanentId: id,
      latinName: latin,
      status: status,
      year: year,
      customNumber: number,
      category: category,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late PlantCrudProvider provider;
  late Box<String> box;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('home_golden_');
    Hive.init(dir.path);
    await _loadSdkFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    box = await Hive.openBox<String>(
      'outbox_${DateTime.now().microsecondsSinceEpoch}',
    );
    await sl.reset();
    repo = _FakeRepo();
    sl.registerSingleton<PlantRepository>(repo);
    sl.registerSingleton<SyncOutbox>(SyncOutbox(box));
    provider = PlantCrudProvider();
  });

  tearDown(() async {
    provider.dispose();
    await box.deleteFromDisk();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    Size size = const Size(420, 800),
  }) async {
    // Хост — Windows → некоторые стили темы резолвят 'Segoe UI', которого
    // нет в тестовом окружении → подписи NavigationRail рисуются квадратами.
    // Android-таргет → дефолт 'Roboto' (загружен из SDK).
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await provider.loadPlants();
      // apply(fontFamily): у части стилей (labelMedium и др.) family=null —
      // в тестовом окружении резолвится системный дефолт, которого нет →
      // подписи NavigationRail рисовались квадратами.
      final theme = CactusTheme.light();
      final themed = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<PlantCrudProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: themed,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('golden: главный экран (мобильный layout)', (tester) async {
    repo
      ..store['p1'] = _plant('p1', 'Echinocereus reichenbachii', number: 12)
      ..store['p2'] = _plant('p2', 'Mammillaria elongata', number: 34)
      ..store['p3'] =
          _plant('p3', 'Lobivia arachnacantha', category: 'sown', year: 2023)
      ..store['p4'] =
          _plant('p4', 'Gymnocalycium mihanovichii', status: 'flower')
      ..store['p5'] = _plant('p5', 'Rebutia heliosa', category: 'sown');

    await pumpHome(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_screen_mobile.png'),
    );
  });

  testWidgets('golden: главный экран (десктопный layout)', (tester) async {
    repo
      ..store['p1'] = _plant('p1', 'Echinocereus reichenbachii', number: 12)
      ..store['p2'] = _plant('p2', 'Mammillaria elongata', number: 34)
      ..store['p3'] =
          _plant('p3', 'Lobivia arachnacantha', category: 'sown', year: 2023)
      ..store['p4'] =
          _plant('p4', 'Gymnocalycium mihanovichii', status: 'flower')
      ..store['p5'] = _plant('p5', 'Rebutia heliosa', category: 'sown');

    await pumpHome(tester, size: const Size(1100, 700));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_screen_desktop.png'),
    );
  });
}
