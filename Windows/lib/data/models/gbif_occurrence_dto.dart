import 'package:hive/hive.dart';

part 'gbif_occurrence_dto.g.dart';

@HiveType(typeId: 4)
class GbifOccurrenceDto extends HiveObject {
  @HiveField(0)
  double latitude;

  @HiveField(1)
  double longitude;

  @HiveField(2)
  String country;

  @HiveField(3)
  String? locality;

  @HiveField(4)
  String? habitat;

  @HiveField(5)
  String? coordinateUncertainty;

  @HiveField(6)
  String? year;

  @HiveField(7)
  String? month;

  @HiveField(8)
  String? day;

  GbifOccurrenceDto({
    required this.latitude,
    required this.longitude,
    required this.country,
    this.locality,
    this.habitat,
    this.coordinateUncertainty,
    this.year,
    this.month,
    this.day,
  });
}
