import 'package:hive/hive.dart';

part 'wintering_log_entry_dto.g.dart';

@HiveType(typeId: 3)
class WinteringLogEntryDto extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String description;

  WinteringLogEntryDto({
    required this.date,
    required this.description,
  });
}
