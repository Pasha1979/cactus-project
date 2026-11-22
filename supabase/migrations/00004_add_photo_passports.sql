-- Миграция 00004: фото-паспорта растений (этап 3.2, R-054/R-055).
-- JSONB-массив PhotoPassport {passportId, plantId, versions[], isArchived, isDeleted}.
-- Применить вручную в SQL Editor (как 00001-00003).

ALTER TABLE plants
  ADD COLUMN IF NOT EXISTS photo_passports JSONB DEFAULT '[]'::jsonb;
