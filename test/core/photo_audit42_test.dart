import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_cactus/core/models/photo_passport.dart';
import 'package:my_cactus/core/sync/photo_passport_manager.dart';
import 'package:my_cactus/core/sync/photo_trash_service.dart';
import 'package:my_cactus/core/sync/sync_outbox.dart';
import 'package:my_cactus/data/models/plant.dart';
import 'package:my_cactus/data/models/plant_dto.dart';
import 'package:my_cactus/domain/repositories/plant_repository.dart';
import 'package:my_cactus/injection_container.dart';
import 'package:my_cactus/presentation/providers/plant_crud_provider.dart';
import 'package:my_cactus/presentation/screens/plant_card/tabs/gallery_tab.dart';
import 'package:my_cactus/services/photo_sync_service.dart';
import 'package:my_cactus/services/yandex_auth_service.dart';
import 'package:my_cactus/services/yandex_disk_service.dart';

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

class FakeAuth extends YandexAuthService {
  @override
  bool get isConnected => true;
}

/// Диск-фейк: пути из [failing] падают, остальные удаляются успешно.
class FakeDisk extends YandexDiskService {
  FakeDisk(super.auth, {this.failing = const {}});
  final Set<String> failing;
  final deleted = <String>[];

  @override
  Future<void> createAppFolders() async {}
  @override
  Future<void> deletePhoto(String fileUrl) async {
    if (failing.contains(fileUrl)) throw Exception('network fail');
    deleted.add(fileUrl);
  }

  @override
  Future<void> deleteCloudFile(String cloudPath) async {
    if (failing.contains(cloudPath)) throw Exception('network fail');
    deleted.add(cloudPath);
  }
}

// ==================== HELPERS ====================

PhotoPassport _passport(
  String id,
  String plantId, {
  bool archived = false,
  bool deleted = false,
  String path = '/MyCactus/photos/x.jpg',
  String? cache,
}) =>
    PhotoPassport(
      passportId: id,
      plantId: plantId,
      isArchived: archived,
      isDeleted: deleted,
      versions: [
        PhotoVersion(
          versionId: 'v_$id',
          yandexFilePath: path,
          createdAt: DateTime(2026),
          sizeBytes: 1,
          localCachePath: cache,
        ),
      ],
    );

Plant _plant(List<PhotoPassport> passports, {List<String>? userPhotos}) => Plant(
      permanentId: 'p1',
      latinName: 'Cactus',
      status: 'alive',
      year: 2024,
      customNumber: 1,
      category: 'sown',
      photoPassports: passports,
      userPhotos: userPhotos ?? const [],
    );

Future<Box<String>> _box(String name) =>
    Hive.openBox<String>('${name}_${DateTime.now().microsecondsSinceEpoch}');

/// Минимальный валидный DTO (как в plant_repository_test).
PlantDto _dto(String id) => PlantDto(
      permanentId: id,
      displayId: 'C-$id',
      latinName: 'Cactus $id',
      status: 'alive',
      year: 2024,
      customNumber: 1,
      category: 'sown',
      seedsCount: 0,
      germinatedCount: 0,
      userPhotos: const [],
      lliflePhotoUrls: const [],
      wateringDates: const [],
      customWateringDates: const [],
      hasUnreadNotification: false,
      germinationHistoryJson: const [],
      floweringHistoryJson: const [],
      notesJson: const [],
      gbifPhotoUrls: const [],
      gbifOccurrencesJson: const [],
      isBatch: false,
      childrenIds: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpyRepo repo;
  late Box<String> outboxBox;
  late Box<String> trashBox;
  late PhotoTrashService trash;
  late PhotoPassportManager manager;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('audit42_');
    Hive.init(dir.path);
  });

  setUp(() async {
    repo = SpyRepo();
    outboxBox = await _box('o42');
    trashBox = await _box('t42');
    trash = PhotoTrashService(trashBox);
    manager = PhotoPassportManager(
      plants: repo,
      outbox: SyncOutbox(outboxBox),
      trash: trash,
    );
  });

  tearDown(() async {
    await outboxBox.deleteFromDisk();
    await trashBox.deleteFromDisk();
    await sl.reset();
  });

  // f1: фильтр 'my'/'all' — только активные паспорта, legacy userPhotos
  // и архивные/удалённые в сетку НЕ попадают.
  testWidgets('f1: галерея показывает только активные паспорта',
      (tester) async {
    final plant = _plant(
      [
        _passport('a1', 'p1', path: '/local/a1.jpg'),
        _passport('a2', 'p1', path: '/local/a2.jpg'),
        _passport('arch', 'p1', archived: true, path: '/local/arch.jpg'),
        _passport('del', 'p1', deleted: true, path: '/local/del.jpg'),
      ],
      userPhotos: ['/legacy/one.jpg', '/legacy/two.jpg'],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GalleryTab(
          plant: plant,
          onShowFullPhoto: (_, __, ___, ____) {},
          onShowPhotoOptions: (_, __, ___) {},
          onUploadPhoto: (_, __) {},
          onRefreshLlifle: (_, __) {},
        ),
      ),
    ));
    await tester.pump();

    // GridView сам оборачивает детей в RepaintBoundary — считаем
    // по ClipRRect (ровно один на ячейку фото).
    int gridCount() => tester
        .widgetList(
          find.descendant(
            of: find.byType(GridView),
            matching: find.byType(ClipRRect),
          ),
        )
        .length;

    // 'all': 2 активных паспорта, legacy userPhotos не дублируются.
    expect(gridCount(), 2);

    // 'my': те же 2 — архив/удалённые исключены.
    await tester.tap(find.widgetWithText(FilterChip, 'Мои'));
    await tester.pump();
    expect(gridCount(), 2);
  });

  // f2: addUserPhoto не трогает userPhotos, создаёт паспорт.
  test('f2: addUserPhoto → паспорт, userPhotos не меняется', () async {
    sl.registerSingleton<PlantRepository>(repo);
    sl.registerSingleton<SyncOutbox>(SyncOutbox(outboxBox));
    sl.registerSingleton<PhotoTrashService>(trash);
    sl.registerSingleton<PhotoPassportManager>(manager);

    final tmp = await Directory.systemTemp.createTemp('f2_');
    final src = await File('${tmp.path}/src.jpg').writeAsBytes([1, 2, 3]);

    // path_provider: documents-директория = tmp.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );

    final provider = PlantCrudProvider();
    await provider.addPlant(_plant([])); // заполняет и _plants, и repo
    await provider.addUserPhoto('p1', src.path);

    final stored = repo.store['p1']!;
    expect(stored.userPhotos, isEmpty,
        reason: 'userPhotos — legacy, в него больше не пишем');
    expect(stored.photoPassports.length, 1);
    expect(stored.photoPassports.first.versions.single.yandexFilePath,
        contains('src.jpg'));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  // f3: deletePassportEverywhere → флаг + запись в photo_trash,
  // мгновенного удаления файла нет.
  test('f3: deletePassportEverywhere → флаг + корзина', () async {
    repo.store['p1'] = _plant([_passport('pp', 'p1')]);
    await manager.deletePassportEverywhere('pp');

    final stored = repo.store['p1']!;
    expect(stored.photoPassports.single.isDeleted, isTrue);
    expect(trash.pendingCount, 1);

    final entry =
        jsonDecode(trashBox.values.single) as Map<String, dynamic>;
    expect(entry['paths'], contains('/MyCactus/photos/x.jpg'));
    expect(entry['now'], isTrue);
  });

  // f4: processTrash — успешные вычёркиваются, упавшие остаются.
  test('f4: корзина — частичный успех оставляет остаток', () async {
    await trash.enqueueDelete('e1', ['/MyCactus/ok.jpg', '/MyCactus/bad.jpg']);

    final deleted = <String>[];
    var n = await trash.processTrash((p) async {
      if (p.contains('bad')) throw Exception('fail');
      deleted.add(p);
    });
    expect(n, 1);
    expect(deleted, ['/MyCactus/ok.jpg']);
    expect(trash.pendingCount, 1,
        reason: 'упавший путь остаётся на повтор');

    // Повтор: теперь всё удаляется.
    n = await trash.processTrash((p) async => deleted.add(p));
    expect(n, 1);
    expect(trash.pendingCount, 0);
  });

  // f5: freeLocalSpace реально удаляет файл кэша с диска.
  test('f5: freeLocalSpace удаляет файл с диска', () async {
    final tmp = await Directory.systemTemp.createTemp('f5_');
    final cache = await File('${tmp.path}/cache.jpg').writeAsBytes([1]);

    repo.store['p1'] =
        _plant([_passport('pp', 'p1', cache: cache.path)]);
    await manager.freeLocalSpace('pp');

    expect(cache.existsSync(), isFalse,
        reason: 'файл кэша должен быть физически удалён');
    final stored = repo.store['p1']!;
    expect(stored.photoPassports.single.versions.single.localCachePath,
        isNull);
  });

  // f6: round-trip Plant → DTO → Hive → чтение → паспорта целы
  // (регенерированный адаптер, поле 40 nullable → старые записи читаются).
  test('f6: photoPassports переживают Hive round-trip', () async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PlantDtoAdapter());
    }
    final box = await Hive.openBox<PlantDto>(
        'dto42_${DateTime.now().microsecondsSinceEpoch}');

    final pp = _passport('pp', 'p1');
    final dto = _dto('p1')
      ..photoPassportsJson = [jsonEncode(pp.toJson())];
    await box.put('p1', dto);

    // «Старая» запись без паспортов — null допустим (до этапа 3).
    await box.put('old', _dto('old'));

    final read = box.get('p1')!;
    final decoded = PhotoPassport.fromJson(
      jsonDecode(read.photoPassportsJson!.single) as Map<String, dynamic>,
    );
    expect(decoded.passportId, 'pp');
    expect(decoded.versions.single.yandexFilePath,
        '/MyCactus/photos/x.jpg');
    expect(box.get('old')!.photoPassportsJson, isNull,
        reason: 'поле 40 отсутствует у старых записей → null, не краш');

    await box.deleteFromDisk();
  });

  // f8: legacy _syncDeletedPhotos — частичная ошибка НЕ чистит очередь.
  test('f8: удаление с частичным сбоем — очередь сохраняется', () async {
    sl.registerSingleton<PlantRepository>(repo);
    sl.registerSingleton<SyncOutbox>(SyncOutbox(outboxBox));
    sl.registerSingleton<PhotoTrashService>(trash);
    sl.registerSingleton<PhotoPassportManager>(manager);

    final provider = PlantCrudProvider();
    await provider.addPlant(_plant([]));
    provider.markUserPhotoAsDeleted('/MyCactus/ok.jpg');
    provider.markUserPhotoAsDeleted('/MyCactus/bad.jpg');

    final auth = FakeAuth();
    final disk = FakeDisk(auth, failing: {'/MyCactus/bad.jpg'});
    final svc = PhotoSyncService(auth, disk, trash);

    await svc.syncUserPhotos(provider);

    expect(disk.deleted, contains('/MyCactus/ok.jpg'));
    expect(provider.deletedUserPhotos, contains('/MyCactus/bad.jpg'),
        reason: 'упавшее удаление остаётся в очереди провайдера');
    expect(provider.deletedUserPhotos, isNot(contains('/MyCactus/ok.jpg')));
    expect(trash.pendingCount, greaterThan(0),
        reason: 'упавший путь продублирован в photo_trash');
  });
}
