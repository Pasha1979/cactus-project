// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gbif_occurrence_dto.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GbifOccurrenceDtoAdapter extends TypeAdapter<GbifOccurrenceDto> {
  @override
  final int typeId = 4;

  @override
  GbifOccurrenceDto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GbifOccurrenceDto(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      country: fields[2] as String,
      locality: fields[3] as String?,
      habitat: fields[4] as String?,
      coordinateUncertainty: fields[5] as String?,
      year: fields[6] as String?,
      month: fields[7] as String?,
      day: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, GbifOccurrenceDto obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.country)
      ..writeByte(3)
      ..write(obj.locality)
      ..writeByte(4)
      ..write(obj.habitat)
      ..writeByte(5)
      ..write(obj.coordinateUncertainty)
      ..writeByte(6)
      ..write(obj.year)
      ..writeByte(7)
      ..write(obj.month)
      ..writeByte(8)
      ..write(obj.day);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GbifOccurrenceDtoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
