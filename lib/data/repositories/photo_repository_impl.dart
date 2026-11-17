import '../../domain/repositories/photo_repository.dart';
import '../datasources/local/plant_local_datasource.dart';

/// Реализация PhotoRepository с использованием Hive (через PlantDto)
class PhotoRepositoryImpl implements PhotoRepository {

  PhotoRepositoryImpl(this._plantLocalDataSource);
  final PlantLocalDataSource _plantLocalDataSource;

  @override
  Future<void> addUserPhoto(String plantId, String photoPath) async {
    final plant = await _plantLocalDataSource.getPlantById(plantId);
    if (plant != null) {
      final updatedPhotos = [...plant.userPhotos, photoPath];
      final updatedPlant = plant..userPhotos = updatedPhotos;
      await _plantLocalDataSource.updatePlant(updatedPlant);
    }
  }

  @override
  Future<void> removeUserPhoto(String plantId, String photoPath) async {
    final plant = await _plantLocalDataSource.getPlantById(plantId);
    if (plant != null) {
      final updatedPhotos = plant.userPhotos.where((p) => p != photoPath).toList();
      final updatedPlant = plant..userPhotos = updatedPhotos;
      await _plantLocalDataSource.updatePlant(updatedPlant);
    }
  }

  @override
  Future<void> addLliflePhoto(String plantId, String photoUrl) async {
    final plant = await _plantLocalDataSource.getPlantById(plantId);
    if (plant != null) {
      final updatedUrls = [...plant.lliflePhotoUrls, photoUrl];
      final updatedPlant = plant..lliflePhotoUrls = updatedUrls;
      await _plantLocalDataSource.updatePlant(updatedPlant);
    }
  }

  @override
  Future<void> removeLliflePhoto(String plantId, String photoUrl) async {
    final plant = await _plantLocalDataSource.getPlantById(plantId);
    if (plant != null) {
      final updatedUrls = plant.lliflePhotoUrls.where((u) => u != photoUrl).toList();
      final updatedPlant = plant..lliflePhotoUrls = updatedUrls;
      await _plantLocalDataSource.updatePlant(updatedPlant);
    }
  }

  @override
  Future<void> setLlifleAsMainPhoto(String plantId, String photoUrl) async {
    /// Устанавливает Llifle фото как "основное" (первое в списке).
    final plant = await _plantLocalDataSource.getPlantById(plantId);
    if (plant != null) {
      final updatedUrls = [
        photoUrl,
        ...plant.lliflePhotoUrls.where((u) => u != photoUrl),
      ];
      final updatedPlant = plant..lliflePhotoUrls = updatedUrls;
      await _plantLocalDataSource.updatePlant(updatedPlant);
    }
  }
}
