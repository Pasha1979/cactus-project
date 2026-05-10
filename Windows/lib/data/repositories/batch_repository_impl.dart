import '../../domain/repositories/batch_repository.dart';
import '../datasources/local/plant_local_datasource.dart';

/// Реализация BatchRepository с использованием Hive (через PlantDto)
class BatchRepositoryImpl implements BatchRepository {
  final PlantLocalDataSource _plantLocalDataSource;

  BatchRepositoryImpl(this._plantLocalDataSource);

  @override
  Future<List<Map<String, dynamic>>> getAllBatches() async {
    final plants = await _plantLocalDataSource.getAllPlants();
    final batches = plants.where((p) => p.isBatch).map((p) => {
      'id': p.permanentId,
      'name': p.latinName,
      'childrenIds': p.childrenIds,
      'createdAt': p.year.toString(),
    }).toList();
    return batches;
  }

  @override
  Future<List<String>> getBatchPlantIds(String batchId) async {
    final plant = await _plantLocalDataSource.getPlantById(batchId);
    return plant?.childrenIds ?? [];
  }

  @override
  Future<void> createBatch(Map<String, dynamic> batchData) async {
    // Реализация назначена на шаг 1.10.11 (создание BatchProvider)
    throw UnimplementedError(
      'Batch creation will be implemented at step 1.10.11. '
      'Currently no-op would silently fail to create batch.',
    );
  }

  @override
  Future<void> updateBatch(String batchId, Map<String, dynamic> batchData) async {
    // Реализация назначена на шаг 1.10.11 (создание BatchProvider)
    throw UnimplementedError(
      'Batch update will be implemented at step 1.10.11. '
      'Currently no-op would silently fail to save changes.',
    );
  }
}
