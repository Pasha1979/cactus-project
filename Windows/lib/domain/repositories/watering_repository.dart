/// Репозиторий для работы с поливами
abstract class WateringRepository {
  /// Получить даты полива для растения
  Future<List<DateTime>> getWateringDates(String plantId);

  /// Добавить дату полива
  Future<void> addWateringDate(String plantId, DateTime date);

  /// Удалить дату полива
  Future<void> removeWateringDate(String plantId, DateTime date);

  /// Получить глобальные даты полива
  Future<List<DateTime>> getGlobalWateringDates();

  /// Сохранить глобальные даты полива
  Future<void> saveGlobalWateringDates(List<DateTime> dates);
}
