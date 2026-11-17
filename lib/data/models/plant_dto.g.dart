// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plant_dto.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlantDtoAdapter extends TypeAdapter<PlantDto> {
  @override
  final int typeId = 0;

  @override
  PlantDto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlantDto(
      permanentId: fields[0] as String,
      displayId: fields[1] as String,
      latinName: fields[2] as String,
      status: fields[3] as String,
      year: fields[4] as int,
      customNumber: fields[5] as int,
      category: fields[6] as String,
      seedsCount: fields[7] as int,
      germinatedCount: fields[8] as int,
      userPhotos: (fields[9] as List).cast<String>(),
      lastFertilization: fields[10] as DateTime?,
      plannedFertilizationDate: fields[11] as DateTime?,
      lliflePhotoUrls: (fields[12] as List).cast<String>(),
      lastModified: fields[13] as DateTime?,
      fieldNumber: fields[14] as String?,
      seller: fields[15] as String?,
      harvestYear: fields[16] as int?,
      country: fields[17] as String?,
      habitat: fields[18] as String?,
      description: fields[19] as String?,
      synonyms: fields[20] as String?,
      careTips: fields[21] as String?,
      floweringPeriod: fields[22] as String?,
      countryFlag: fields[23] as String?,
      wateringDates: (fields[24] as List).cast<DateTime>(),
      customWateringDates: (fields[25] as List).cast<DateTime>(),
      hasUnreadNotification: fields[26] as bool,
      lastRepotting: fields[27] as DateTime?,
      plannedTransplantDate: fields[28] as DateTime?,
      germinationHistoryJson: (fields[29] as List).cast<String>(),
      floweringHistoryJson: (fields[30] as List).cast<String>(),
      notesJson: (fields[31] as List).cast<String>(),
      gbifPhotoUrls: (fields[32] as List).cast<String>(),
      gbifOccurrencesJson: (fields[33] as List).cast<String>(),
      lastGbifUpdate: fields[34] as DateTime?,
      aliveCount: fields[35] as int?,
      isBatch: fields[36] as bool,
      childrenIds: (fields[37] as List).cast<String>(),
      parentId: fields[38] as String?,
      qrCodeJson: fields[39] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PlantDto obj) {
    writer
      ..writeByte(40)
      ..writeByte(0)
      ..write(obj.permanentId)
      ..writeByte(1)
      ..write(obj.displayId)
      ..writeByte(2)
      ..write(obj.latinName)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.year)
      ..writeByte(5)
      ..write(obj.customNumber)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.seedsCount)
      ..writeByte(8)
      ..write(obj.germinatedCount)
      ..writeByte(9)
      ..write(obj.userPhotos)
      ..writeByte(10)
      ..write(obj.lastFertilization)
      ..writeByte(11)
      ..write(obj.plannedFertilizationDate)
      ..writeByte(12)
      ..write(obj.lliflePhotoUrls)
      ..writeByte(13)
      ..write(obj.lastModified)
      ..writeByte(14)
      ..write(obj.fieldNumber)
      ..writeByte(15)
      ..write(obj.seller)
      ..writeByte(16)
      ..write(obj.harvestYear)
      ..writeByte(17)
      ..write(obj.country)
      ..writeByte(18)
      ..write(obj.habitat)
      ..writeByte(19)
      ..write(obj.description)
      ..writeByte(20)
      ..write(obj.synonyms)
      ..writeByte(21)
      ..write(obj.careTips)
      ..writeByte(22)
      ..write(obj.floweringPeriod)
      ..writeByte(23)
      ..write(obj.countryFlag)
      ..writeByte(24)
      ..write(obj.wateringDates)
      ..writeByte(25)
      ..write(obj.customWateringDates)
      ..writeByte(26)
      ..write(obj.hasUnreadNotification)
      ..writeByte(27)
      ..write(obj.lastRepotting)
      ..writeByte(28)
      ..write(obj.plannedTransplantDate)
      ..writeByte(29)
      ..write(obj.germinationHistoryJson)
      ..writeByte(30)
      ..write(obj.floweringHistoryJson)
      ..writeByte(31)
      ..write(obj.notesJson)
      ..writeByte(32)
      ..write(obj.gbifPhotoUrls)
      ..writeByte(33)
      ..write(obj.gbifOccurrencesJson)
      ..writeByte(34)
      ..write(obj.lastGbifUpdate)
      ..writeByte(35)
      ..write(obj.aliveCount)
      ..writeByte(36)
      ..write(obj.isBatch)
      ..writeByte(37)
      ..write(obj.childrenIds)
      ..writeByte(38)
      ..write(obj.parentId)
      ..writeByte(39)
      ..write(obj.qrCodeJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlantDtoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
