import 'package:hive/hive.dart';

import '../../models/plant_dto.dart';

/// Менеджер индексов для быстрого поиска растений по полям.
///
/// Hive не поддерживает встроенные вторичные индексы, поэтому реализуем
/// собственный индексный слой поверх `Box<List<String>>`.
///
/// Ключ индекса:  `"field:value"` (например `"status:sown"`)
/// Значение:      список `permanentId` растений с таким значением поля.
///
/// Использование:
/// ```dart
/// final ids = indexManager.getIdsByField('status', 'sown');
/// final plants = ids.map((id) => box.get(id)).whereType<PlantDto>().toList();
/// ```
class PlantIndexManager {
  final Box<List<dynamic>> _indexBox;

  PlantIndexManager(this._indexBox);

  /// Зарегистрировать растение во всех индексах.
  void addPlant(PlantDto plant) {
    _addToIndex('status', plant.status, plant.permanentId);
    _addToIndex('category', plant.category, plant.permanentId);
    _addToIndex('displayId', plant.displayId, plant.permanentId);
  }

  /// Удалить растение из всех индексов.
  void removePlant(PlantDto plant) {
    _removeFromIndex('status', plant.status, plant.permanentId);
    _removeFromIndex('category', plant.category, plant.permanentId);
    _removeFromIndex('displayId', plant.displayId, plant.permanentId);
  }

  /// Получить список permanentId по полю и значению.
  List<String> getIdsByField(String field, String value) {
    final key = _indexKey(field, value);
    final raw = _indexBox.get(key);
    if (raw == null) return [];
    // Hive может вернуть List<dynamic>, приводим к String
    return raw.whereType<String>().toList();
  }

  /// Перестроить все индексы заново на основе существующего box.
  /// Полезно при миграции или если индексы рассинхронизировались.
  Future<void> rebuildIndex(Box<PlantDto> plantBox) async {
    await _indexBox.clear();
    for (final entry in plantBox.toMap().entries) {
      final plant = entry.value;
      addPlant(plant);
    }
  }

  String _indexKey(String field, String value) => '$field:$value';

  void _addToIndex(String field, String value, String permanentId) {
    final key = _indexKey(field, value);
    final ids = _indexBox.get(key)?.whereType<String>().toList() ?? [];
    if (!ids.contains(permanentId)) {
      ids.add(permanentId);
      _indexBox.put(key, ids);
    }
  }

  void _removeFromIndex(String field, String? value, String permanentId) {
    if (value == null) return;
    final key = _indexKey(field, value);
    final ids = _indexBox.get(key)?.whereType<String>().toList() ?? [];
    ids.remove(permanentId);
    if (ids.isEmpty) {
      _indexBox.delete(key);
    } else {
      _indexBox.put(key, ids);
    }
  }
}
