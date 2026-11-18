/// Статус движка синхронизации.
enum SyncStatus { idle, syncing, error }

/// Интерфейс движка синхронизации.
///
/// Локальная база (Hive) ↔ SyncEngine ↔ Supabase (записи) +
/// Яндекс.Диск (фото). Офлайн-first: все изменения локально,
/// синхронизация при появлении сети (R-003).
abstract class SyncEngine {
  Stream<SyncStatus> get syncStatusStream;

  Future<void> sync();
  Future<void> pushLocalChanges();
  Future<void> pullRemoteChanges();
}
