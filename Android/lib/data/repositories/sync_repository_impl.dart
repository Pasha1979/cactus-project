import '../../core/network/network_info.dart';
import '../../domain/repositories/sync_repository.dart';

/// Реализация SyncRepository
class SyncRepositoryImpl implements SyncRepository {
  final NetworkInfo _networkInfo;

  SyncRepositoryImpl(this._networkInfo);

  @override
  Future<bool> hasInternetConnection() async {
    return _networkInfo.isConnected;
  }

  @override
  Future<void> syncWithCloud() async {
    // Реализация назначена на шаг 1.11.15 (интеграция с SyncManager)
    throw UnimplementedError(
      'Cloud sync will be implemented at step 1.11.15. '
      'Currently no-op would silently skip sync.',
    );
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    // TODO: реализовать получение статуса при полной интеграции (шаг 1.11.15)
    // Заглушка: возвращаем pending, чтобы не создавать иллюзию синхронизации
    return SyncStatus.pending;
  }
}
