import 'package:get_it/get_it.dart';

import 'core/network/network_info.dart';
import 'data/datasources/local/gbif_cache_local_datasource.dart';
import 'data/datasources/local/hive_database.dart';
import 'data/datasources/local/note_local_datasource.dart';
import 'data/datasources/local/plant_index_manager.dart';
import 'data/datasources/local/plant_local_datasource.dart';
import 'data/datasources/local/qr_code_local_datasource.dart';
import 'data/datasources/local/wintering_local_datasource.dart';
import 'data/repositories/batch_repository_impl.dart';
import 'data/repositories/note_repository_impl.dart';
import 'data/repositories/photo_repository_impl.dart';
import 'data/repositories/plant_repository_impl.dart';
import 'data/repositories/qr_code_repository_impl.dart';
import 'data/repositories/sync_repository_impl.dart';
import 'data/repositories/watering_repository_impl.dart';
import 'data/repositories/wintering_repository_impl.dart';
import 'domain/repositories/batch_repository.dart';
import 'domain/repositories/note_repository.dart';
import 'domain/repositories/photo_repository.dart';
import 'domain/repositories/plant_repository.dart';
import 'domain/repositories/qr_code_repository.dart';
import 'domain/repositories/sync_repository.dart';
import 'domain/repositories/watering_repository.dart';
import 'domain/repositories/wintering_repository.dart';

/// Глобальный Service Locator (DI-контейнер)
///
/// Использует get_it для регистрации всех зависимостей приложения.
/// Инициализируется один раз при запуске в `main.dart`.
///
/// Пример получения зависимости:
/// ```dart
/// final repository = sl<PlantRepository>();
/// ```
final GetIt sl = GetIt.instance;

/// Инициализация DI-контейнера
///
/// Регистрирует все DataSources, Repositories и Services.
/// Hive должен быть инициализирован ДО вызова этой функции.
Future<void> init() async {
  // ==================== DATA SOURCES ====================
  // Регистрируем как LazySingleton — создаются при первом обращении
  sl.registerLazySingleton(
    () => PlantLocalDataSource(
      HiveDatabase.plantsBox,
      indexManager: PlantIndexManager(HiveDatabase.plantIndexBox),
    ),
  );
  sl.registerLazySingleton(
    () => NoteLocalDataSource(HiveDatabase.notesBox),
  );
  sl.registerLazySingleton(
    () => QRCodeLocalDataSource(HiveDatabase.qrCodesBox),
  );
  sl.registerLazySingleton(
    () => WinteringLocalDataSource(HiveDatabase.winteringLogsBox),
  );
  sl.registerLazySingleton(
    () => GbifCacheLocalDataSource(HiveDatabase.gbifCacheBox),
  );

  // ==================== CORE ====================
  sl.registerLazySingleton(() => NetworkInfo());

  // ==================== REPOSITORIES ====================
  // PlantRepository
  sl.registerLazySingleton<PlantRepository>(
    () => PlantRepositoryImpl(sl<PlantLocalDataSource>()),
  );

  // WateringRepository (использует PlantLocalDataSource)
  sl.registerLazySingleton<WateringRepository>(
    () => WateringRepositoryImpl(sl<PlantLocalDataSource>()),
  );

  // PhotoRepository (использует PlantLocalDataSource)
  sl.registerLazySingleton<PhotoRepository>(
    () => PhotoRepositoryImpl(sl<PlantLocalDataSource>()),
  );

  // BatchRepository (использует PlantLocalDataSource)
  sl.registerLazySingleton<BatchRepository>(
    () => BatchRepositoryImpl(sl<PlantLocalDataSource>()),
  );

  // NoteRepository
  sl.registerLazySingleton<NoteRepository>(
    () => NoteRepositoryImpl(sl<NoteLocalDataSource>()),
  );

  // QRCodeRepository
  sl.registerLazySingleton<QRCodeRepository>(
    () => QRCodeRepositoryImpl(sl<QRCodeLocalDataSource>()),
  );

  // SyncRepository
  sl.registerLazySingleton<SyncRepository>(
    () => SyncRepositoryImpl(sl<NetworkInfo>()),
  );

  // WinteringRepository
  sl.registerLazySingleton<WinteringRepository>(
    () => WinteringRepositoryImpl(sl<WinteringLocalDataSource>()),
  );
}
