/// Репозиторий для работы с фотографиями
abstract class PhotoRepository {
  /// Добавить фото пользователя к растению
  Future<void> addUserPhoto(String plantId, String photoPath);

  /// Удалить фото пользователя
  Future<void> removeUserPhoto(String plantId, String photoPath);

  /// Добавить фото из Llifle
  Future<void> addLliflePhoto(String plantId, String photoUrl);

  /// Удалить фото из Llifle
  Future<void> removeLliflePhoto(String plantId, String photoUrl);

  /// Установить фото Llifle как основное
  Future<void> setLlifleAsMainPhoto(String plantId, String photoUrl);
}
