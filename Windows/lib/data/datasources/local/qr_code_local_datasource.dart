import 'package:hive/hive.dart';
import '../../../data/models/qr_code_dto.dart';

/// Локальный источник данных для QR кодов (Hive)
class QRCodeLocalDataSource {

  QRCodeLocalDataSource(this._qrCodeBox);
  final Box<QRCodeDto> _qrCodeBox;

  /// Получить все QR коды
  Future<List<QRCodeDto>> getAllQRCodes() async {
    return _qrCodeBox.values.toList();
  }

  /// Получить QR код по plantId
  Future<QRCodeDto?> getQRCodeByPlantId(String plantId) async {
    try {
      return _qrCodeBox.values.firstWhere(
        (qr) => qr.plantId == plantId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Сохранить QR код
  Future<void> saveQRCode(QRCodeDto qrCode) async {
    await _qrCodeBox.put(qrCode.plantId, qrCode);
  }

  /// Удалить QR код
  Future<void> deleteQRCode(String plantId) async {
    await _qrCodeBox.delete(plantId);
  }

  /// Очистить все данные
  Future<void> clearAll() async {
    await _qrCodeBox.clear();
  }
}
