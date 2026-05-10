import 'package:hive/hive.dart';
import '../../../data/models/plant_dto.dart';

/// Локальный источник данных для растений (Hive)
class PlantLocalDataSource {
  final Box<PlantDto> _plantBox;

  PlantLocalDataSource(this._plantBox);

  /// Получить все растения
  Future<List<PlantDto>> getAllPlants() async {
    return _plantBox.values.toList();
  }

  /// Получить растение по ID
  Future<PlantDto?> getPlantById(String id) async {
    try {
      return _plantBox.values.firstWhere(
        (plant) => plant.permanentId == id,
      );
    } catch (e) {
      return null;
    }
  }

  /// Добавить растение
  Future<void> addPlant(PlantDto plant) async {
    await _plantBox.put(plant.permanentId, plant);
  }

  /// Обновить растение
  Future<void> updatePlant(PlantDto plant) async {
    await _plantBox.put(plant.permanentId, plant);
  }

  /// Удалить растение
  Future<void> deletePlant(String id) async {
    await _plantBox.delete(id);
  }

  /// Найти растения по статусу
  Future<List<PlantDto>> getPlantsByStatus(String status) async {
    return _plantBox.values
        .where((plant) => plant.status == status)
        .toList();
  }

  /// Найти растения по категории
  Future<List<PlantDto>> getPlantsByCategory(String category) async {
    return _plantBox.values
        .where((plant) => plant.category == category)
        .toList();
  }

  /// Поиск растений по названию
  Future<List<PlantDto>> searchPlants(String query) async {
    final lowerQuery = query.toLowerCase();
    return _plantBox.values
        .where((plant) =>
            plant.latinName.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Очистить все данные
  Future<void> clearAll() async {
    await _plantBox.clear();
  }
}
