import 'package:flutter/foundation.dart';

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
    // TODO(1.15.7): реализовать глобальное хранилище поливов через settings_box в Hive
    return [];
  }

  @override
  Future<void> saveGlobalWateringDates(List<DateTime> dates) async {
    // FIXME(1.15.7): Реализовать при создании settings_box в Hive
    // Сейчас не используется — WateringProvider работает напрямую с SharedPreferences.
    // No-op безопаснее throw — метод не вызывается из UI.
    debugPrint(
        '⚠️ WateringRepositoryImpl.saveGlobalWateringDates: no-op — реализация отложена');
  }
}
