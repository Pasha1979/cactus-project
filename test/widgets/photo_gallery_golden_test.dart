import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cactus/core/models/photo_passport.dart';
import 'package:my_cactus/core/sync/photo_passport_manager.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:my_cactus/presentation/widgets/photo_passport_section.dart';

// Golden-скриншоты секции фото-паспортов (этап 3.3).
// Генерация/обновление PNG:
//   flutter test test/widgets/photo_gallery_golden_test.dart --update-goldens
// Проверка без обновления:
//   flutter test test/widgets/photo_gallery_golden_test.dart
// PNG складываются в test/widgets/goldens/ и служат скриншот-артефактами
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

/// Рисует «фото» кактуса: зелёный прямоугольник с тёмной полосой —
/// кодируется движком в настоящий PNG (вызов только внутри runAsync).
Future<String> _writeTempPhoto(String name, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, 16, 16),
      Paint()..color = color,
    )
    ..drawRect(
      const Rect.fromLTWH(4, 0, 3, 16),
      Paint()..color = Colors.black26,
    );
  final image = await recorder.endRecording().toImage(16, 16);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory.systemTemp.createTempSync('golden_photo');
  final f = File('${dir.path}${Platform.pathSeparator}$name.png');
  await f.writeAsBytes(data!.buffer.asUint8List());
  return f.path;
}

PhotoPassport _passport(
  String id,
  String plantId,
  String imagePath, {
  bool archived = false,
}) =>
    PhotoPassport(
      passportId: id,
      plantId: plantId,
      isArchived: archived,
      versions: [
        PhotoVersion(
          versionId: 'v_$id',
          yandexFilePath: imagePath,
          createdAt: DateTime(2026, 5, 20),
          sizeBytes: 1024,
          localCachePath: imagePath,
        ),
      ],
    );

Plant _plant(List<PhotoPassport> passports) => Plant(
      permanentId: 'p1',
      latinName: 'Echinocereus reichenbachii',
      status: 'alive',
      year: 2024,
      customNumber: 1,
      category: 'sown',
      photoPassports: passports,
    );

/// Грузит Roboto и MaterialIcons из кэша Flutter SDK — иначе golden
/// рисует текст тестовым шрифтом-плейсхолдером, а иконки — квадратами.
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

Widget _screen(Plant plant, PhotoPassportManager mgr) => MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(
        appBar: AppBar(title: const Text('Галерея')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Фото-паспорта', style: TextStyle(fontSize: 16)),
            ),
            PhotoPassportSection(plant: plant, manager: mgr),
          ],
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late PhotoPassportManager mgr;

  setUpAll(_loadSdkFonts);

  setUp(() {
    repo = _FakeRepo();
    mgr = PhotoPassportManager(plants: repo);
  });

  Future<void> pumpScene(
    WidgetTester tester,
    Plant plant, [
    List<String> imagesToPrecache = const [],
  ]) async {
    tester.view.physicalSize = const Size(420, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    repo.store['p1'] = plant;
    // runAsync + precacheImage: реальное чтение файла и декод Image.file
    // иначе не успевает завершиться в fake-async — карточки серые.
    await tester.runAsync(() async {
      await tester.pumpWidget(_screen(plant, mgr));
      final ctx = tester.element(find.byType(PhotoPassportSection));
      for (final path in imagesToPrecache) {
        await precacheImage(FileImage(File(path)), ctx);
      }
      await tester.pumpAndSettle();
    });
  }

  testWidgets('golden: секция с двумя активными паспортами', (tester) async {
    String pa = '', pb = '';
    await tester.runAsync(() async {
      pa = await _writeTempPhoto('a', Colors.green);
      pb = await _writeTempPhoto('b', Colors.teal);
    });
    final plant = _plant([
      _passport('pp1', 'p1', pa),
      _passport('pp2', 'p1', pb),
    ]);
    await pumpScene(tester, plant, [pa, pb]);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/passport_section_closed.png'),
    );
  });

  testWidgets('golden: открытое меню «⋮»', (tester) async {
    String pa = '', pb = '';
    await tester.runAsync(() async {
      pa = await _writeTempPhoto('a', Colors.green);
      pb = await _writeTempPhoto('b', Colors.teal);
    });
    final plant = _plant([
      _passport('pp1', 'p1', pa),
      _passport('pp2', 'p1', pb),
    ]);
    await pumpScene(tester, plant, [pa, pb]);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/passport_menu_open.png'),
    );
  });

  testWidgets('golden: развёрнутый архив с «Вернуть в галерею»',
      (tester) async {
    String pa = '', pb = '';
    await tester.runAsync(() async {
      pa = await _writeTempPhoto('a', Colors.green);
      pb = await _writeTempPhoto('arch', Colors.lightGreen);
    });
    final plant = _plant([
      _passport('pp1', 'p1', pa),
      _passport('pp_arch', 'p1', pb, archived: true),
    ]);
    await pumpScene(tester, plant, [pa, pb]);

    await tester.tap(find.text('Показать архивные фото'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/passport_archive_expanded.png'),
    );
  });
}
