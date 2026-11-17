/// Репозиторий для работы с зимовкой
abstract class WinteringRepository {
  /// Получить настройки зимовки
  Future<Map<String, dynamic>> getWinteringSettings();

  /// Сохранить настройки зимовки
  Future<void> saveWinteringSettings(Map<String, dynamic> settings);
}
