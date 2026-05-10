import '../../models/qr_code_file.dart';

/// Репозиторий для работы с QR кодами
abstract class QRCodeRepository {
  /// Получить все QR файлы
  Future<List<QRCodeFile>> getAllQRCodeFiles();

  /// Сохранить QR файл
  Future<void> saveQRCodeFile(QRCodeFile file);

  /// Удалить QR файл
  Future<void> deleteQRCodeFile(String id);

  /// Переименовать QR файл
  Future<void> renameQRCodeFile(String id, String newName);
}
