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
