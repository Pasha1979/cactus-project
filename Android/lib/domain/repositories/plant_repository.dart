import '../../models/plant.dart';

/// Репозиторий для работы с растениями (CRUD операции)
abstract class PlantRepository {
  /// Получить все растения
  Future<List<Plant>> getAllPlants();

  /// Получить растение по ID
  Future<Plant?> getPlantById(String id);

  /// Добавить растение
  Future<void> addPlant(Plant plant);

  /// Обновить растение
  Future<void> updatePlant(Plant plant);

  /// Удалить растение
  Future<void> deletePlant(String id);

  /// Найти растения по статусу
  Future<List<Plant>> getPlantsByStatus(String status);

  /// Найти растения по категории
  Future<List<Plant>> getPlantsByCategory(String category);

  /// Поиск растений по названию
  Future<List<Plant>> searchPlants(String query);
}
