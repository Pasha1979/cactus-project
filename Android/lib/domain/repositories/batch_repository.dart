/// Репозиторий для работы с партиями
abstract class BatchRepository {
  /// Получить все партии
  Future<List<Map<String, dynamic>>> getAllBatches();

  /// Получить растения партии
  Future<List<String>> getBatchPlantIds(String batchId);

  /// Создать партию
  Future<void> createBatch(Map<String, dynamic> batchData);

  /// Обновить партию
  Future<void> updateBatch(String batchId, Map<String, dynamic> batchData);
}
