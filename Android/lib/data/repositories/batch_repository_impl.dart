import 'package:flutter/foundation.dart';

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
    // FIXME(1.15.9): Реализовать при создании BatchProvider
    // Сейчас не используется в UI. No-op безопаснее throw.
    debugPrint(
        '⚠️ BatchRepositoryImpl.createBatch: no-op — реализация отложена');
  }

  @override
  Future<void> updateBatch(
      String batchId, Map<String, dynamic> batchData) async {
    // FIXME(1.15.9): Реализовать при создании BatchProvider
    // Сейчас не используется в UI. No-op безопаснее throw.
    debugPrint(
        '⚠️ BatchRepositoryImpl.updateBatch: no-op — реализация отложена');
  }
}
