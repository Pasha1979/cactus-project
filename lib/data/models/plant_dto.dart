import 'package:hive/hive.dart';

part 'plant_dto.g.dart';

/// Data Transfer Object для хранения информации о растении в Hive БД.
///
/// Используется для сериализации/десериализации данных растения.
/// Соответствует сущности [Plant] из domain слоя.
///
/// См. также:
/// - [Plant] - domain entity
/// - [PlantRepository] - репозиторий для работы с растениями
@HiveType(typeId: 0)
class PlantDto extends HiveObject {

  /// Создает новый [PlantDto].
  ///
  /// Обязательные поля: [permanentId], [displayId], [latinName], [status],
  /// [year], [customNumber], [category], [seedsCount], [germinatedCount],
  /// [userPhotos], [lliflePhotoUrls], [wateringDates], [customWateringDates],
  /// [hasUnreadNotification], [germinationHistoryJson], [floweringHistoryJson],
  /// [notesJson], [gbifPhotoUrls], [gbifOccurrencesJson], [isBatch], [childrenIds].
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
  /// Уникальный постоянный идентификатор растения (UUID).
  @HiveField(0)
  String permanentId;

  /// Отображаемый идентификатор (например: "001", "A-123").
  @HiveField(1)
  String displayId;

  /// Латинское название растения.
  ///
  /// Используется для поиска в GBIF API.
  @HiveField(2)
  String latinName;

  /// Статус растения: alive, dead, unknown, etc.
  @HiveField(3)
  String status;

  /// Год посева/покупки растения.
  @HiveField(4)
  int year;

  /// Пользовательский номер растения.
  @HiveField(5)
  int customNumber;

  /// Категория растения (кактус, суккулент, etc.).
  @HiveField(6)
  String category;

  /// Количество семян/растений при посеве.
  @HiveField(7)
  int seedsCount;

  /// Количество пророщенных/выживших растений.
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
}
