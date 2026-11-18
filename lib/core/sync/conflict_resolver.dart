import 'sync_record.dart';

/// Интерфейс разрешения конфликтов синхронизации.
///
/// Базовая стратегия — last-writer-wins по [SyncRecord.lastModified]
/// (серверное время). Реализации — задача 2.4.
abstract class ConflictResolver<T extends SyncRecord> {
  T resolve(T local, T remote);
}
