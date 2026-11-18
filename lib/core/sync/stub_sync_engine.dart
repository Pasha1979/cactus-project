import 'sync_engine.dart';

/// Заглушка движка синхронизации.
///
/// Реальная реализация — задачи 2.3-2.5. До подключения Supabase
/// приложение работает в локальном режиме (R-029).
class StubSyncEngine implements SyncEngine {
  @override
  Stream<SyncStatus> get syncStatusStream => Stream.value(SyncStatus.idle);

  @override
  Future<void> sync() async {
    throw UnimplementedError('Sync engine not implemented yet');
  }

  @override
  Future<void> pushLocalChanges() async {
    throw UnimplementedError('Sync engine not implemented yet');
  }

  @override
  Future<void> pullRemoteChanges() async {
    throw UnimplementedError('Sync engine not implemented yet');
  }
}
