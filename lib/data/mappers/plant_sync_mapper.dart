import '../models/plant.dart';

/// Маппер Plant → строка таблицы plants (Supabase, схема 00001+00002).
///
/// ВАЖНО: 'last_modified' НЕ отправляется — его ставит серверный триггер
/// (миграция 00002, R-045). 'user_id' подставляется из auth-сессии.
Map<String, dynamic> plantToSyncRow(Plant p, String userId) => {
      'user_id': userId,
      'permanent_id': p.permanentId,
      'display_id': p.displayId,
      'latin_name': p.latinName,
      'status': p.status,
      'year': p.year,
      'custom_number': p.customNumber,
      'category': p.category,
      'field_number': p.fieldNumber,
      'seller': p.seller,
      'harvest_year': p.harvestYear,
      'country': p.country,
      'habitat': p.habitat,
      'description': p.description,
      'synonyms': p.synonyms,
      'care_tips': p.careTips,
      'flowering_period': p.floweringPeriod,
      'country_flag': p.countryFlag,
      'seeds_count': p.seedsCount,
      'germinated_count': p.germinatedCount,
      'watering_dates':
          p.wateringDates.map((d) => d.toIso8601String()).toList(),
      'custom_watering_dates':
          p.customWateringDates.map((d) => d.toIso8601String()).toList(),
      'has_unread_notification': p.hasUnreadNotification,
      'last_repotting': p.lastRepotting?.toIso8601String(),
      'planned_transplant_date': p.plannedTransplantDate?.toIso8601String(),
      'last_fertilization': p.lastFertilization?.toIso8601String(),
      'planned_fertilization_date':
          p.plannedFertilizationDate?.toIso8601String(),
      'germination_history':
          p.germinationHistory.map((r) => r.toJson()).toList(),
      'flowering_history': p.floweringHistory.map((r) => r.toJson()).toList(),
      'notes': p.notes.map((n) => n.toJson()).toList(),
      'user_photos': p.userPhotos,
      'photo_passports': p.photoPassports.map((pp) => pp.toJson()).toList(),
      'llifle_photo_urls': p.lliflePhotoUrls,
      'gbif_photo_urls': p.gbifPhotoUrls,
      'gbif_occurrences': p.gbifOccurrences.map((o) => o.toJson()).toList(),
      'last_gbif_update': p.lastGbifUpdate?.toIso8601String(),
      'alive_count': p.aliveCount,
      'is_batch': p.isBatch,
      'children_ids': p.childrenIds,
      'parent_id': p.parentId,
      'qr_code': p.qrCode?.toJson(),
    };

/// Обратный маппер: строка таблицы plants (snake_case) → Plant.
///
/// Собирает camelCase-JSON и переиспользует [Plant.fromJson].
/// `last_modified` серверной строки попадает в [Plant.lastModified].
Plant plantFromSyncRow(Map<String, dynamic> row) {
  final json = <String, dynamic>{
    'permanentId': row['permanent_id'],
    'displayId': row['display_id'],
    'latinName': row['latin_name'],
    'status': row['status'],
    'year': row['year'],
    'customNumber': row['custom_number'],
    'category': row['category'],
    'fieldNumber': row['field_number'],
    'seller': row['seller'],
    'harvestYear': row['harvest_year'],
    'country': row['country'],
    'habitat': row['habitat'],
    'description': row['description'],
    'synonyms': row['synonyms'],
    'careTips': row['care_tips'],
    'floweringPeriod': row['flowering_period'],
    'countryFlag': row['country_flag'],
    'seedsCount': row['seeds_count'],
    'germinatedCount': row['germinated_count'],
    'wateringDates': row['watering_dates'],
    'customWateringDates': row['custom_watering_dates'],
    'hasUnreadNotification': row['has_unread_notification'],
    'lastRepotting': row['last_repotting'],
    'plannedTransplantDate': row['planned_transplant_date'],
    'lastFertilization': row['last_fertilization'],
    'plannedFertilizationDate': row['planned_fertilization_date'],
    'germinationHistory': row['germination_history'],
    'floweringHistory': row['flowering_history'],
    'notes': row['notes'],
    'userPhotos': row['user_photos'],
    'photoPassports': row['photo_passports'],
    'lliflePhotoUrls': row['llifle_photo_urls'],
    'gbifPhotoUrls': row['gbif_photo_urls'],
    'gbifOccurrences': row['gbif_occurrences'],
    'lastGbifUpdate': row['last_gbif_update'],
    'aliveCount': row['alive_count'],
    'isBatch': row['is_batch'],
    'childrenIds': row['children_ids'],
    'parentId': row['parent_id'],
    'qrCode': row['qr_code'],
    'lastModified': row['last_modified'],
  };
  final plant = Plant.fromJson(json);
  if (row['display_id'] != null) plant.displayId = row['display_id'] as String;
  return plant;
}
