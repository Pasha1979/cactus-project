# Покрытие схемы: Plant (модель) ↔ plants (Supabase)

Задача 2.4, аудит «ноль потерь». Источник полей: `lib/data/models/plant.dart`.
Источник колонок: `supabase/migrations/00001_initial_schema.sql` + `00002_server_time.sql`.

| Поле модели Plant | Колонка plants | Миграция |
|---|---|---|
| permanentId | permanent_id | 00001 |
| displayId | display_id | 00001 |
| latinName | latin_name | 00001 |
| status | status | 00001 |
| year | year | 00001 |
| customNumber | custom_number | 00001 |
| category | category | 00001 |
| fieldNumber | field_number | 00001 |
| seller | seller | 00001 |
| harvestYear | harvest_year | 00001 |
| country | country | 00001 |
| habitat | habitat | 00001 |
| description | description | 00001 |
| synonyms | synonyms | 00001 |
| careTips | care_tips | 00001 |
| floweringPeriod | flowering_period | 00001 |
| countryFlag | country_flag | 00001 |
| seedsCount | seeds_count | 00001 |
| germinatedCount | germinated_count | 00001 |
| wateringDates | watering_dates | 00001 |
| customWateringDates | custom_watering_dates | 00001 |
| hasUnreadNotification | has_unread_notification | 00001 |
| lastRepotting | last_repotting | 00001 |
| plannedTransplantDate | planned_transplant_date | 00001 |
| germinationHistory | germination_history | 00001 |
| floweringHistory | flowering_history | 00001 |
| notes | notes | 00001 |
| userPhotos | user_photos | 00001 |
| lliflePhotoUrls | llifle_photo_urls | 00001 |
| gbifPhotoUrls | gbif_photo_urls | 00001 |
| gbifOccurrences | gbif_occurrences | 00001 |
| lastGbifUpdate | last_gbif_update | 00001 |
| aliveCount | alive_count | 00001 |
| isBatch | is_batch | 00001 |
| childrenIds | children_ids | 00001 |
| parentId | parent_id | 00001 |
| qrCode | qr_code | 00001 |
| lastFertilization | last_fertilization | 00002 |
| plannedFertilizationDate | planned_fertilization_date | 00002 |
| lastModified | last_modified | 00001 (ставит триггер 00002; только чтение) |

## Колонки только на сервере (служебные)

| Колонка | Назначение |
|---|---|
| id | PK строки (uuid) |
| user_id | владелец записи (RLS) |
| is_deleted | tombstone |
| created_at | время создания строки |

## Итог

- Полей модели: **40** (включая lastModified) — все имеют колонку. **100%**
- Служебных колонок без поля модели: 4 (id, user_id, is_deleted, created_at) — так задумано.
- Непокрытых полей: **нет**.
