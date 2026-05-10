import 'dart:convert';
import '../../domain/repositories/plant_repository.dart';
import '../../models/plant.dart';
import '../../models/qr_code.dart';
import '../../utils/gbif_utils.dart';
import '../datasources/local/plant_local_datasource.dart';
import '../models/plant_dto.dart';

/// Реализация PlantRepository с использованием Hive
class PlantRepositoryImpl implements PlantRepository {
  final PlantLocalDataSource _localDataSource;

  PlantRepositoryImpl(this._localDataSource);

  @override
  Future<List<Plant>> getAllPlants() async {
    final dtoList = await _localDataSource.getAllPlants();
    return dtoList.map((dto) => _mapToEntity(dto)).toList();
  }

  @override
  Future<Plant?> getPlantById(String id) async {
    final dto = await _localDataSource.getPlantById(id);
    if (dto == null) return null;
    return _mapToEntity(dto);
  }

  @override
  Future<void> addPlant(Plant plant) async {
    final dto = _mapToDto(plant);
    await _localDataSource.addPlant(dto);
  }

  @override
  Future<void> updatePlant(Plant plant) async {
    final dto = _mapToDto(plant);
    await _localDataSource.updatePlant(dto);
  }

  @override
  Future<void> deletePlant(String id) async {
    await _localDataSource.deletePlant(id);
  }

  @override
  Future<List<Plant>> getPlantsByStatus(String status) async {
    final dtoList = await _localDataSource.getPlantsByStatus(status);
    return dtoList.map((dto) => _mapToEntity(dto)).toList();
  }

  @override
  Future<List<Plant>> getPlantsByCategory(String category) async {
    final dtoList = await _localDataSource.getPlantsByCategory(category);
    return dtoList.map((dto) => _mapToEntity(dto)).toList();
  }

  @override
  Future<List<Plant>> searchPlants(String query) async {
    final dtoList = await _localDataSource.searchPlants(query);
    return dtoList.map((dto) => _mapToEntity(dto)).toList();
  }

  /// Преобразование DTO в Entity (прямое, без JSON-посредника)
  Plant _mapToEntity(PlantDto dto) {
    return Plant(
      permanentId: dto.permanentId,
      displayId: dto.displayId,
      latinName: dto.latinName,
      status: dto.status,
      year: dto.year,
      customNumber: dto.customNumber,
      category: dto.category,
      country: dto.country,
      habitat: dto.habitat,
      description: dto.description,
      synonyms: dto.synonyms,
      careTips: dto.careTips,
      floweringPeriod: dto.floweringPeriod,
      countryFlag: dto.countryFlag,
      seedsCount: dto.seedsCount,
      germinatedCount: dto.germinatedCount,
      lastFertilization: dto.lastFertilization,
      plannedFertilizationDate: dto.plannedFertilizationDate,
      wateringDates: dto.wateringDates,
      customWateringDates: dto.customWateringDates,
      hasUnreadNotification: dto.hasUnreadNotification,
      lastRepotting: dto.lastRepotting,
      plannedTransplantDate: dto.plannedTransplantDate,
      germinationHistory: dto.germinationHistoryJson
          .map((json) => GerminationRecord.fromJson(jsonDecode(json)))
          .toList(),
      floweringHistory: dto.floweringHistoryJson
          .map((json) => FloweringRecord.fromJson(jsonDecode(json)))
          .toList(),
      notes: dto.notesJson
          .map((json) => Note.fromJson(jsonDecode(json)))
          .toList(),
      userPhotos: dto.userPhotos,
      lliflePhotoUrls: dto.lliflePhotoUrls,
      fieldNumber: dto.fieldNumber,
      seller: dto.seller,
      harvestYear: dto.harvestYear,
      lastModified: dto.lastModified,
      gbifPhotoUrls: dto.gbifPhotoUrls,
      gbifOccurrences: dto.gbifOccurrencesJson
          .map((json) => GbifOccurrence.fromJson(jsonDecode(json)))
          .toList(),
      lastGbifUpdate: dto.lastGbifUpdate,
      aliveCount: dto.aliveCount,
      isBatch: dto.isBatch,
      childrenIds: dto.childrenIds,
      parentId: dto.parentId,
      qrCode: dto.qrCodeJson != null
          ? QRCode.fromJson(jsonDecode(dto.qrCodeJson!))
          : null,
    );
  }

  /// Преобразование Entity в DTO (прямое, без JSON-посредника)
  PlantDto _mapToDto(Plant entity) {
    return PlantDto(
      permanentId: entity.permanentId,
      displayId: entity.displayId,
      latinName: entity.latinName,
      status: entity.status,
      year: entity.year,
      customNumber: entity.customNumber,
      category: entity.category,
      seedsCount: entity.seedsCount,
      germinatedCount: entity.germinatedCount,
      userPhotos: entity.userPhotos,
      lastFertilization: entity.lastFertilization,
      plannedFertilizationDate: entity.plannedFertilizationDate,
      lliflePhotoUrls: entity.lliflePhotoUrls,
      lastModified: entity.lastModified,
      fieldNumber: entity.fieldNumber,
      seller: entity.seller,
      harvestYear: entity.harvestYear,
      country: entity.country,
      habitat: entity.habitat,
      description: entity.description,
      synonyms: entity.synonyms,
      careTips: entity.careTips,
      floweringPeriod: entity.floweringPeriod,
      countryFlag: entity.countryFlag,
      wateringDates: entity.wateringDates,
      customWateringDates: entity.customWateringDates,
      hasUnreadNotification: entity.hasUnreadNotification,
      lastRepotting: entity.lastRepotting,
      plannedTransplantDate: entity.plannedTransplantDate,
      germinationHistoryJson: entity.germinationHistory
          .map((e) => jsonEncode(e.toJson()))
          .toList(),
      floweringHistoryJson: entity.floweringHistory
          .map((e) => jsonEncode(e.toJson()))
          .toList(),
      notesJson: entity.notes
          .map((e) => jsonEncode(e.toJson()))
          .toList(),
      gbifPhotoUrls: entity.gbifPhotoUrls,
      gbifOccurrencesJson: entity.gbifOccurrences
          .map((e) => jsonEncode(e.toJson()))
          .toList(),
      lastGbifUpdate: entity.lastGbifUpdate,
      aliveCount: entity.aliveCount,
      isBatch: entity.isBatch,
      childrenIds: entity.childrenIds,
      parentId: entity.parentId,
      qrCodeJson: entity.qrCode != null ? jsonEncode(entity.qrCode!.toJson()) : null,
    );
  }
}
