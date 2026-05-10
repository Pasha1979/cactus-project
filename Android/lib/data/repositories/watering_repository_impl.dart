import '../../domain/repositories/watering_repository.dart';
import '../datasources/local/plant_local_datasource.dart';

/// Реализация WateringRepository с использованием Hive (через PlantDto)
class WateringRepositoryImpl implements WateringRepository {
  final PlantLocalDataSource _plantLocalDataSource;

  WateringRepositoryImpl(this._plantLocalDataSource);

  @override
  Future<List<DateTime>> getWateringDates(String plantId) async {
    final plant = await _plantLocalDataSource.getPlantById(plantId);
    return plant?.wateringDates ?? [];
  }

  @override
  Future<void> addWateringDate(String plantId, DateTime date) async {
    final plant = await _plantLocalDataSource.getPlantById(plantId);
    if (plant != null) {
      final updatedDates = [...plant.wateringDates, date];
      final updatedPlant = plant..wateringDates = updatedDates;
      await _plantLocalDataSource.updatePlant(updatedPlant);
    }
  }

  @override
  Future<void> removeWateringDate(String plantId, DateTime date) async {
    final plant = await _plantLocalDataSource.getPlantById(plantId);
    if (plant != null) {
      final updatedDates = plant.wateringDates.where((d) => d != date).toList();
      final updatedPlant = plant..wateringDates = updatedDates;
      await _plantLocalDataSource.updatePlant(updatedPlant);
    }
  }

  @override
  Future<List<DateTime>> getGlobalWateringDates() async {
    // TODO: реализовать глобальное хранилище поливов при полной интеграции
    return [];
  }

  @override
  Future<void> saveGlobalWateringDates(List<DateTime> dates) async {
    // Реализация назначена на шаг 1.10.10 (создание WateringProvider + settings_box)
    throw UnimplementedError(
      'Global watering storage will be implemented at step 1.10.10. '
      'Currently no-op would silently lose user data.',
    );
  }
}
