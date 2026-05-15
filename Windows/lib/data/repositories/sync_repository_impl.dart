import '../../core/logger/app_logger.dart';
import '../../core/network/network_info.dart';
import '../../domain/repositories/sync_repository.dart';

/// Реализация SyncRepository
class SyncRepositoryImpl implements SyncRepository {

  SyncRepositoryImpl(this._networkInfo);
  final NetworkInfo _networkInfo;

  @override
  Future<bool> hasInternetConnection() async {
    return _networkInfo.isConnected;
  }

  @override
  Future<void> syncWithCloud() async {
    /// Полная синхронизация идёт через CloudStorageProvider → SyncManager.
    /// Этот метод — no-op, чтобы не дублировать сложную логику.
    AppLogger.warning('⚠️ SyncRepositoryImpl.syncWithCloud: no-op — используйте CloudStorageProvider.syncData()', tag: 'SYNC_REPO');
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    /// Заглушка: статус синхронизации не отслеживается на уровне репозитория.
    return SyncStatus.pending;
  }
}
