import 'package:flutter/foundation.dart';

import 'dart:convert';

import '../../domain/repositories/watering_repository.dart';
import '../datasources/local/hive_database.dart';
import '../datasources/local/plant_local_datasource.dart';

/// Реализация WateringRepository с использованием Hive (через PlantDto)
class WateringRepositoryImpl implements WateringRepository {

  WateringRepositoryImpl(this._plantLocalDataSource);
  final PlantLocalDataSource _plantLocalDataSource;

  static const String _globalWateringKey = 'global_watering_dates';

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
    final box = HiveDatabase.settingsBox;
    final jsonStr = box.get(_globalWateringKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => DateTime.tryParse(e as String))
          .whereType<DateTime>()
          .toList();
    } catch (e) {
      debugPrint('Ошибка чтения globalWateringDates: $e');
      return [];
    }
  }

  @override
  Future<void> saveGlobalWateringDates(List<DateTime> dates) async {
    final box = HiveDatabase.settingsBox;
    final jsonStr = jsonEncode(dates.map((d) => d.toIso8601String()).toList());
    await box.put(_globalWateringKey, jsonStr);
  }
}
