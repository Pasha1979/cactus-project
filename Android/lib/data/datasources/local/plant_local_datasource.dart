import 'package:hive/hive.dart';
import '../../../data/models/plant_dto.dart';
import 'plant_index_manager.dart';

/// Локальный источник данных для растений (Hive) с индексным ускорением.
///
/// Индексы поддерживаются для полей:
/// - `status`    — быстрый фильтр по статусу
/// - `category`  — быстрый фильтр по категории
/// - `displayId` — быстрый поиск по displayId
///
/// Ключевое исправление: `getPlantById` использует `box.get(id)` (O(1))
/// вместо `firstWhere` (O(n)), что критично для коллекций 1000+ растений.
class PlantLocalDataSource {

  PlantLocalDataSource(
    this._plantBox, {
    PlantIndexManager? indexManager,
  }) : _indexManager = indexManager;
  final Box<PlantDto> _plantBox;
  final PlantIndexManager? _indexManager;

  /// Получить все растения (возвращает все значения box — O(n))
  Future<List<PlantDto>> getAllPlants() async {
    return _plantBox.values.toList();
  }

  /// Получить растение по permanentId — O(1) по ключу Hive.
  Future<PlantDto?> getPlantById(String id) async {
    return _plantBox.get(id);
  }

  /// Добавить растение + обновить индексы.
  Future<void> addPlant(PlantDto plant) async {
    await _plantBox.put(plant.permanentId, plant);
    _indexManager?.addPlant(plant);
  }

  /// Обновить растение + перестроить индексы.
  Future<void> updatePlant(PlantDto plant) async {
    final oldPlant = _plantBox.get(plant.permanentId);
    if (oldPlant != null) {
      _indexManager?.removePlant(oldPlant);
    }
    await _plantBox.put(plant.permanentId, plant);
    _indexManager?.addPlant(plant);
  }

  /// Удалить растение + удалить из индексов.
  Future<void> deletePlant(String id) async {
    final plant = _plantBox.get(id);
    if (plant != null) {
      _indexManager?.removePlant(plant);
    }
    await _plantBox.delete(id);
  }

  /// Найти растения по статусу — использует индекс (O(1) + O(k)).
  Future<List<PlantDto>> getPlantsByStatus(String status) async {
    if (_indexManager != null) {
      final ids = _indexManager!.getIdsByField('status', status);
      return ids.map((id) => _plantBox.get(id)).whereType<PlantDto>().toList();
    }
    // Fallback без индекса
    return _plantBox.values.where((plant) => plant.status == status).toList();
  }

  /// Найти растения по категории — использует индекс (O(1) + O(k)).
  Future<List<PlantDto>> getPlantsByCategory(String category) async {
    if (_indexManager != null) {
      final ids = _indexManager!.getIdsByField('category', category);
      return ids.map((id) => _plantBox.get(id)).whereType<PlantDto>().toList();
    }
    return _plantBox.values
        .where((plant) => plant.category == category)
        .toList();
  }

  /// Поиск растений по подстроке в latinName.
  ///
  /// Подстроковый поиск не поддерживается индексами (требует inverted index).
  /// Для коллекций до нескольких тысяч записей O(n) с `.where()`
  /// работает без задержек (< 1 мс на 1000 записей в Dart).
  Future<List<PlantDto>> searchPlants(String query) async {
    final lowerQuery = query.toLowerCase();
    return _plantBox.values
        .where((plant) => plant.latinName.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Очистить все данные + индексы.
  Future<void> clearAll() async {
    await _plantBox.clear();
    _indexManager?.rebuildIndex(_plantBox);
  }

  /// Перестроить индексы заново (полезно после миграции).
  Future<void> rebuildIndex() async {
    await _indexManager?.rebuildIndex(_plantBox);
  }
}
