/// Страница изменений из Supabase (pull-курсор).
class RemoteChangesPage {
  const RemoteChangesPage({required this.rows, required this.newCursor});

  /// Строки plants (включая tombstones is_deleted = true).
  final List<Map<String, dynamic>> rows;

  /// Серверное last_modified последней строки; null если страница пуста.
  final DateTime? newCursor;
}

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

  /// Обновить sync_metadata.last_sync_at серверным временем.
  /// Возвращает серверный штамп (или null, если нечем проставить).
  Future<DateTime?> updateLastSync();

  /// Изменения с [cursor] (строго позже), по возрастанию last_modified.
  /// ВКЛЮЧАЕТ tombstones (is_deleted = true) — без них удаления не дойдут.
  /// cursor == null → тянуть всё с начала.
  Future<RemoteChangesPage> fetchChangesSince(
    DateTime? cursor, {
    int limit = 1000,
  });

  /// Upsert строки user_settings (ключ = (user_id, key)).
  Future<void> upsertSetting(Map<String, dynamic> row);

  /// Изменения user_settings с [cursor], включая tombstones.
  Future<RemoteChangesPage> fetchSettingsSince(
    DateTime? cursor, {
    int limit = 1000,
  });
}
