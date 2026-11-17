import '../../domain/repositories/batch_repository.dart';
import '../datasources/local/plant_local_datasource.dart';
import '../models/plant_dto.dart';

/// Реализация BatchRepository с использованием Hive (через PlantDto)
class BatchRepositoryImpl implements BatchRepository {

  BatchRepositoryImpl(this._plantLocalDataSource);
  final PlantLocalDataSource _plantLocalDataSource;

  @override
  Future<List<Map<String, dynamic>>> getAllBatches() async {
    final plants = await _plantLocalDataSource.getAllPlants();
    final batches = plants.where((p) => p.isBatch).map((p) => {
      'id': p.permanentId,
      'name': p.latinName,
      'childrenIds': p.childrenIds,
      'createdAt': p.year.toString(),
    },).toList();
    return batches;
  }

  @override
  Future<List<String>> getBatchPlantIds(String batchId) async {
    final plant = await _plantLocalDataSource.getPlantById(batchId);
    return plant?.childrenIds ?? [];
  }

  @override
  Future<void> createBatch(Map<String, dynamic> batchData) async {
    final batch = PlantDto(
      permanentId: batchData['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      displayId: batchData['displayId'] as String? ?? 'BATCH-UNKNOWN',
      latinName: batchData['name'] as String? ?? 'Unknown Batch',
      status: 'batch',
      year: batchData['year'] as int? ?? DateTime.now().year,
      customNumber: batchData['customNumber'] as int? ?? 0,
      category: 'batch',
      seedsCount: batchData['seedsCount'] as int? ?? 0,
      germinatedCount: 0,
      userPhotos: [],
      lliflePhotoUrls: [],
      wateringDates: [],
      customWateringDates: [],
      hasUnreadNotification: false,
      germinationHistoryJson: [],
      floweringHistoryJson: [],
      notesJson: [],
      gbifPhotoUrls: [],
      gbifOccurrencesJson: [],
      isBatch: true,
      childrenIds: batchData['childrenIds'] as List<String>? ?? [],
    );
    await _plantLocalDataSource.addPlant(batch);
  }

  @override
  Future<void> updateBatch(
      String batchId, Map<String, dynamic> batchData,) async {
    final batch = await _plantLocalDataSource.getPlantById(batchId);
    if (batch == null) return;

    final updatedBatch = PlantDto(
      permanentId: batch.permanentId,
      displayId: batchData['displayId'] as String? ?? batch.displayId,
      latinName: batchData['name'] as String? ?? batch.latinName,
      status: batch.status,
      year: batchData['year'] as int? ?? batch.year,
      customNumber: batchData['customNumber'] as int? ?? batch.customNumber,
      category: batch.category,
      seedsCount: batchData['seedsCount'] as int? ?? batch.seedsCount,
      germinatedCount: batch.germinatedCount,
      userPhotos: batch.userPhotos,
      lliflePhotoUrls: batch.lliflePhotoUrls,
      wateringDates: batch.wateringDates,
      customWateringDates: batch.customWateringDates,
      hasUnreadNotification: batch.hasUnreadNotification,
      germinationHistoryJson: batch.germinationHistoryJson,
      floweringHistoryJson: batch.floweringHistoryJson,
      notesJson: batch.notesJson,
      gbifPhotoUrls: batch.gbifPhotoUrls,
      gbifOccurrencesJson: batch.gbifOccurrencesJson,
      isBatch: true,
      childrenIds:
          batchData['childrenIds'] as List<String>? ?? batch.childrenIds,
      parentId: batch.parentId,
      qrCodeJson: batch.qrCodeJson,
    );
    await _plantLocalDataSource.updatePlant(updatedBatch);
  }
}
