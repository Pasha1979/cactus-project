import 'package:hive/hive.dart';

part 'qr_code_dto.g.dart';

@HiveType(typeId: 1)
class QRCodeDto extends HiveObject {

  QRCodeDto({
    required this.plantId,
    required this.plantName,
    required this.permanentId,
    required this.createdAt,
    this.isActive = true,
    this.filePath,
  });
  @HiveField(0)
  String plantId;

  @HiveField(1)
  String plantName;

  @HiveField(2)
  String permanentId;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  String? filePath;
}
