import 'package:flutter/foundation.dart';

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
    /// Полная синхронизация идёт через CloudStorageProvider → SyncManager.
    /// Этот метод — no-op, чтобы не дублировать сложную логику.
    debugPrint(
        '⚠️ SyncRepositoryImpl.syncWithCloud: no-op — используйте CloudStorageProvider.syncData()',);
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    /// Заглушка: статус синхронизации не отслеживается на уровне репозитория.
    return SyncStatus.pending;
  }
}
