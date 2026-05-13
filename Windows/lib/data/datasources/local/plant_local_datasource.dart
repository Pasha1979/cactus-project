import 'package:hive/hive.dart';
import '../../../data/models/plant_dto.dart';
import 'plant_index_manager.dart';

/// Локальный источник данных для растений (Hive) с индексным ускорением.
class PlantLocalDataSource {

  PlantLocalDataSource(
    this._plantBox, {
    PlantIndexManager? indexManager,
  }) : _indexManager = indexManager;
  final Box<PlantDto> _plantBox;
  final PlantIndexManager? _indexManager;

  Future<List<PlantDto>> getAllPlants() async {
    return _plantBox.values.toList();
  }

  Future<PlantDto?> getPlantById(String id) async {
    return _plantBox.get(id);
  }

  Future<void> addPlant(PlantDto plant) async {
    await _plantBox.put(plant.permanentId, plant);
    _indexManager?.addPlant(plant);
  }

  Future<void> updatePlant(PlantDto plant) async {
    final oldPlant = _plantBox.get(plant.permanentId);
    if (oldPlant != null) {
      _indexManager?.removePlant(oldPlant);
    }
    await _plantBox.put(plant.permanentId, plant);
    _indexManager?.addPlant(plant);
  }

  Future<void> deletePlant(String id) async {
    final plant = _plantBox.get(id);
    if (plant != null) {
      _indexManager?.removePlant(plant);
    }
    await _plantBox.delete(id);
  }

  Future<List<PlantDto>> getPlantsByStatus(String status) async {
    final indexManager = _indexManager;
    if (indexManager != null) {
      final ids = indexManager.getIdsByField('status', status);
      return ids.map((id) => _plantBox.get(id)).whereType<PlantDto>().toList();
    }
    return _plantBox.values.where((plant) => plant.status == status).toList();
  }

  Future<List<PlantDto>> getPlantsByCategory(String category) async {
    final indexManager = _indexManager;
    if (indexManager != null) {
      final ids = indexManager.getIdsByField('category', category);
      return ids.map((id) => _plantBox.get(id)).whereType<PlantDto>().toList();
    }
    return _plantBox.values
        .where((plant) => plant.category == category)
        .toList();
  }

  Future<List<PlantDto>> searchPlants(String query) async {
    final lowerQuery = query.toLowerCase();
    return _plantBox.values
        .where((plant) =>
            plant.latinName.toLowerCase().contains(lowerQuery),)
        .toList();
  }

  Future<void> clearAll() async {
    await _plantBox.clear();
    _indexManager?.rebuildIndex(_plantBox);
  }

  Future<void> rebuildIndex() async {
    await _indexManager?.rebuildIndex(_plantBox);
  }
}
