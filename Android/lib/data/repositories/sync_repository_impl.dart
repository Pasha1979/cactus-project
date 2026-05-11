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
    // FIXME(1.15.4): Интегрировать с SyncManager при полном переходе на DI
    // Сейчас синхронизация идёт через CloudStorageProvider → SyncManager.
    // No-op безопаснее throw — метод не используется напрямую.
    debugPrint(
        '⚠️ SyncRepositoryImpl.syncWithCloud: no-op — используйте CloudStorageProvider.syncData()');
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    // TODO(1.15.4): реализовать получение статуса при полной интеграции
    // Заглушка: возвращаем pending, чтобы не создавать иллюзию синхронизации
    return SyncStatus.pending;
  }
}
