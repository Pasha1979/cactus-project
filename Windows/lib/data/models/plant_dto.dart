import 'package:hive/hive.dart';

part 'plant_dto.g.dart';

@HiveType(typeId: 0)
class PlantDto extends HiveObject {
  @HiveField(0)
  String permanentId;

  @HiveField(1)
  String displayId;

  @HiveField(2)
  String latinName;

  @HiveField(3)
  String status;

  @HiveField(4)
  int year;

  @HiveField(5)
  int customNumber;

  @HiveField(6)
  String category;

  @HiveField(7)
  int seedsCount;

  @HiveField(8)
  int germinatedCount;

  @HiveField(9)
  List<String> userPhotos;

  @HiveField(10)
  DateTime? lastFertilization;

  @HiveField(11)
  DateTime? plannedFertilizationDate;

  @HiveField(12)
  List<String> lliflePhotoUrls;

  @HiveField(13)
  DateTime? lastModified;

  @HiveField(14)
  String? fieldNumber;

  @HiveField(15)
  String? seller;

  @HiveField(16)
  int? harvestYear;

  @HiveField(17)
  String? country;

  @HiveField(18)
  String? habitat;

  @HiveField(19)
  String? description;

  @HiveField(20)
  String? synonyms;

  @HiveField(21)
  String? careTips;

  @HiveField(22)
  String? floweringPeriod;

  @HiveField(23)
  String? countryFlag;

  @HiveField(24)
  List<DateTime> wateringDates;

  @HiveField(25)
  List<DateTime> customWateringDates;

  @HiveField(26)
  bool hasUnreadNotification;

  @HiveField(27)
  DateTime? lastRepotting;

  @HiveField(28)
  DateTime? plannedTransplantDate;

  @HiveField(29)
  List<String> germinationHistoryJson;

  @HiveField(30)
  List<String> floweringHistoryJson;

  @HiveField(31)
  List<String> notesJson;

  @HiveField(32)
  List<String> gbifPhotoUrls;

  @HiveField(33)
  List<String> gbifOccurrencesJson;

  @HiveField(34)
  DateTime? lastGbifUpdate;

  @HiveField(35)
  int? aliveCount;

  @HiveField(36)
  bool isBatch;

  @HiveField(37)
  List<String> childrenIds;

  @HiveField(38)
  String? parentId;

  @HiveField(39)
  String? qrCodeJson;

  PlantDto({
    required this.permanentId,
    required this.displayId,
    required this.latinName,
    required this.status,
    required this.year,
    required this.customNumber,
    required this.category,
    required this.seedsCount,
    required this.germinatedCount,
    required this.userPhotos,
    this.lastFertilization,
    this.plannedFertilizationDate,
    required this.lliflePhotoUrls,
    this.lastModified,
    this.fieldNumber,
    this.seller,
    this.harvestYear,
    this.country,
    this.habitat,
    this.description,
    this.synonyms,
    this.careTips,
    this.floweringPeriod,
    this.countryFlag,
    required this.wateringDates,
    required this.customWateringDates,
    required this.hasUnreadNotification,
    this.lastRepotting,
    this.plannedTransplantDate,
    required this.germinationHistoryJson,
    required this.floweringHistoryJson,
    required this.notesJson,
    required this.gbifPhotoUrls,
    required this.gbifOccurrencesJson,
    this.lastGbifUpdate,
    this.aliveCount,
    required this.isBatch,
    required this.childrenIds,
    this.parentId,
    this.qrCodeJson,
  });
}
