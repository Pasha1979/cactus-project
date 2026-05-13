import '../../domain/repositories/qr_code_repository.dart';
import '../../models/qr_code_file.dart';
import '../datasources/local/qr_code_local_datasource.dart';
import '../models/qr_code_dto.dart';

/// Реализация QRCodeRepository с использованием Hive
class QRCodeRepositoryImpl implements QRCodeRepository {

  QRCodeRepositoryImpl(this._localDataSource);
  final QRCodeLocalDataSource _localDataSource;

  @override
  Future<List<QRCodeFile>> getAllQRCodeFiles() async {
    final dtoList = await _localDataSource.getAllQRCodes();
    return dtoList.map((dto) => _mapToEntity(dto)).toList();
  }

  @override
  Future<void> saveQRCodeFile(QRCodeFile file) async {
    final dto = _mapToDto(file);
    await _localDataSource.saveQRCode(dto);
  }

  @override
  Future<void> deleteQRCodeFile(String id) async {
    await _localDataSource.deleteQRCode(id);
  }

  @override
  Future<void> renameQRCodeFile(String id, String newName) async {
    final dto = await _localDataSource.getQRCodeByPlantId(id);
    if (dto != null) {
      final updatedDto = QRCodeDto(
        plantId: dto.plantId,
        plantName: newName,
        permanentId: dto.permanentId,
        createdAt: dto.createdAt,
        isActive: dto.isActive,
      );
      await _localDataSource.saveQRCode(updatedDto);
    }
  }

  QRCodeFile _mapToEntity(QRCodeDto dto) {
    return QRCodeFile(
      id: dto.plantId,
      fileName: dto.plantName,
      filePath: dto.filePath ?? '',
      createdAt: dto.createdAt,
      plantIds: [dto.plantId],
      pageFormat: 'A4',
      orientation: 'portrait',
      labelWidthCm: 5.0,
      labelHeightCm: 5.0,
    );
  }

  QRCodeDto _mapToDto(QRCodeFile entity) {
    return QRCodeDto(
      plantId: entity.id,
      plantName: entity.fileName,
      permanentId: entity.id,
      createdAt: entity.createdAt,
      isActive: true,
      filePath: entity.filePath.isNotEmpty ? entity.filePath : null,
    );
  }
}
