// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_code_dto.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QRCodeDtoAdapter extends TypeAdapter<QRCodeDto> {
  @override
  final int typeId = 1;

  @override
  QRCodeDto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QRCodeDto(
      plantId: fields[0] as String,
      plantName: fields[1] as String,
      permanentId: fields[2] as String,
      createdAt: fields[3] as DateTime,
      isActive: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, QRCodeDto obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.plantId)
      ..writeByte(1)
      ..write(obj.plantName)
      ..writeByte(2)
      ..write(obj.permanentId)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QRCodeDtoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
