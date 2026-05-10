// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wintering_log_entry_dto.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WinteringLogEntryDtoAdapter extends TypeAdapter<WinteringLogEntryDto> {
  @override
  final int typeId = 3;

  @override
  WinteringLogEntryDto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WinteringLogEntryDto(
      date: fields[0] as DateTime,
      description: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WinteringLogEntryDto obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WinteringLogEntryDtoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
