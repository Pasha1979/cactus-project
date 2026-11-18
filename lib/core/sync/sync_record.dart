/// Базовая модель синхронизируемой записи.
///
/// Конфликты разрешаются по last-writer-wins через [lastModified]
/// (серверное время, см. docs/sync/SYNC_ARCHITECTURE.md).
abstract class SyncRecord {
  String get id;
  DateTime get lastModified;
  bool get isDeleted;

  Map<String, dynamic> toJson();
}
