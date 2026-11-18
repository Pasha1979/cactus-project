import '../../data/models/plant.dart';

/// Кто применяет удалённые изменения к локальному состоянию.
///
/// Реализация — [PlantCrudProvider] (обновляет репозиторий, список
/// и уведомляет слушателей под флагом `_applyingRemote`, чтобы
/// outbox-хуки не создавали петлю). Если провайдер не зарегистрирован
/// (тесты), движок пишет напрямую в репозиторий.
abstract class RemoteChangeApplier {
  /// Применить upsert удалённой записи (без enqueue в outbox).
  Future<void> applyUpsert(Plant plant);

  /// Применить удаление записи по permanentId (без enqueue в outbox).
  Future<void> applyDelete(String permanentId);
}
