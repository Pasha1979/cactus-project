import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cactus/core/models/photo_passport.dart';
import 'package:my_cactus/core/sync/photo_passport_manager.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:my_cactus/presentation/widgets/photo_passport_section.dart';

// ==================== FAKES ====================

class SpyRepo implements PlantRepository {
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

/// Менеджер-шпион поверх реальной логики на FakeRepo.
class SpyManager extends PhotoPassportManager {
  SpyManager({required super.plants});

  final calls = <String>[];

  @override
  Future<void> deletePassportEverywhere(String passportId) async {
    calls.add('delete:$passportId');
    await super.deletePassportEverywhere(passportId);
  }

  @override
  Future<void> archivePassport(String passportId) async {
    calls.add('archive:$passportId');
    await super.archivePassport(passportId);
  }
}

PhotoPassport _passport(String id, String plantId,
        {bool archived = false, String path = '/MyCactus/photos/x.jpg'}) =>
    PhotoPassport(
      passportId: id,
      plantId: plantId,
      isArchived: archived,
      versions: [
        PhotoVersion(
          versionId: 'v_$id',
          yandexFilePath: path,
          createdAt: DateTime(2026),
          sizeBytes: 1,
        ),
      ],
    );

Plant _plant(List<PhotoPassport> passports) => Plant(
      permanentId: 'p1',
      latinName: 'Cactus',
      status: 'alive',
      year: 2024,
      customNumber: 1,
      category: 'sown',
      photoPassports: passports,
    );

Widget _app(Plant plant, PhotoPassportManager mgr) => MaterialApp(
      home: Scaffold(
        body: PhotoPassportSection(plant: plant, manager: mgr),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpyRepo repo;
  late SpyManager mgr;

  setUp(() {
    repo = SpyRepo();
    mgr = SpyManager(plants: repo);
  });

  // w1: «...» открывает меню с 3 пунктами
  testWidgets('w1: меню «⋮» с тремя пунктами', (tester) async {
    final plant = _plant([_passport('pp1', 'p1')]);
    repo.store['p1'] = plant;
    await tester.pumpWidget(_app(plant, mgr));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('В архив'), findsOneWidget);
    expect(find.text('Удалить везде'), findsOneWidget);
    expect(find.text('Освободить место'), findsOneWidget);
  });

  // w2: «Удалить везде» → диалог; отмена не вызывает менеджер
  testWidgets('w2: диалог подтверждения, отмена — без вызова', (tester) async {
    final plant = _plant([_passport('pp1', 'p1')]);
    repo.store['p1'] = plant;
    await tester.pumpWidget(_app(plant, mgr));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить везде'));
    await tester.pumpAndSettle();

    expect(find.textContaining('будет удалено с Яндекс.Диска'),
        findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(mgr.calls.where((c) => c.startsWith('delete:')), isEmpty);
  });

  // w3: подтверждение «Удалить везде» вызывает deletePassportEverywhere
  testWidgets('w3: подтверждение вызывает deletePassportEverywhere',
      (tester) async {
    final plant = _plant([_passport('pp1', 'p1')]);
    repo.store['p1'] = plant;
    await tester.pumpWidget(_app(plant, mgr));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить везде'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(mgr.calls, contains('delete:pp1'));
  });

  // w4: «Показать архивные фото» отображает архивные паспорта
  testWidgets('w4: переключатель показывает архивные + кнопку возврата',
      (tester) async {
    final plant = _plant([
      _passport('pp_active', 'p1'),
      _passport('pp_arch', 'p1', archived: true),
    ]);
    repo.store['p1'] = plant;
    await tester.pumpWidget(_app(plant, mgr));
    await tester.pumpAndSettle();

    expect(find.text('Вернуть в галерею'), findsNothing);

    await tester.tap(find.text('Показать архивные фото'));
    await tester.pumpAndSettle();

    expect(find.text('Вернуть в галерею'), findsOneWidget);
  });
}
