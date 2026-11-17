/// Репозиторий для работы с синхронизацией
abstract class SyncRepository {
  /// Проверить наличие интернет-соединения
  Future<bool> hasInternetConnection();

  /// Синхронизировать данные с облаком
  Future<void> syncWithCloud();

  /// Получить статус синхронизации
  Future<SyncStatus> getSyncStatus();
}

enum SyncStatus { synced, pending, error }
