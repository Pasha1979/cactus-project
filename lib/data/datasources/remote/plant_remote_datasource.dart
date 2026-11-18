/// Контракт удалённого источника данных растений.
///
/// Реализация — [SupabaseDatasource]. Интерфейс нужен для подмены
/// в тестах синхронизации (fake без живой сети).
abstract class PlantRemoteDataSource {
  /// Все неудалённые растения текущего пользователя.
  Future<List<Map<String, dynamic>>> fetchPlants();

  /// Upsert записи (идемпотентно по user_id + permanent_id).
  Future<void> uploadPlant(Map<String, dynamic> plant);

  /// Мягкое удаление (tombstone is_deleted = true).
  Future<void> deletePlant(String plantId);

  /// Обновить sync_metadata.last_sync_at = now() после успешного push.
  Future<void> updateLastSync();
}
