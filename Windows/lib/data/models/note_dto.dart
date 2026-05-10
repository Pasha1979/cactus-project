import 'package:hive/hive.dart';

part 'note_dto.g.dart';

@HiveType(typeId: 2)
class NoteDto extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String text;

  @HiveField(3)
  DateTime createdAt;

  NoteDto({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
  });
}
