-- Миграция 00001: начальная схема синхронизации (задача 2.2, R-003/R-029/R-030)
-- Применять через Supabase Dashboard → SQL Editor (см. README_SUPABASE.md)

-- Таблица растений
CREATE TABLE IF NOT EXISTS plants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  permanent_id TEXT NOT NULL,
  display_id TEXT NOT NULL,
  latin_name TEXT NOT NULL,
  status TEXT NOT NULL,
  year INTEGER,
  custom_number INTEGER,
  category TEXT,
  field_number TEXT,
  seller TEXT,
  harvest_year INTEGER,
  country TEXT,
  habitat TEXT,
  description TEXT,
  synonyms TEXT,
  care_tips TEXT,
  flowering_period TEXT,
  country_flag TEXT,
  seeds_count INTEGER DEFAULT 0,
  germinated_count INTEGER DEFAULT 0,
  watering_dates JSONB DEFAULT '[]'::jsonb,
  custom_watering_dates JSONB DEFAULT '[]'::jsonb,
  has_unread_notification BOOLEAN DEFAULT FALSE,
  last_repotting TIMESTAMPTZ,
  planned_transplant_date TIMESTAMPTZ,
  germination_history JSONB DEFAULT '[]'::jsonb,
  flowering_history JSONB DEFAULT '[]'::jsonb,
  notes JSONB DEFAULT '[]'::jsonb,
  user_photos JSONB DEFAULT '[]'::jsonb,
  llifle_photo_urls JSONB DEFAULT '[]'::jsonb,
  gbif_photo_urls JSONB DEFAULT '[]'::jsonb,
  gbif_occurrences JSONB DEFAULT '[]'::jsonb,
  last_gbif_update TIMESTAMPTZ,
  alive_count INTEGER,
  is_batch BOOLEAN DEFAULT FALSE,
  children_ids JSONB DEFAULT '[]'::jsonb,
  parent_id TEXT,
  qr_code JSONB,
  last_modified TIMESTAMPTZ DEFAULT NOW(),
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Уникальность для upsert (onConflict: 'user_id,permanent_id')
  CONSTRAINT plants_user_permanent_unique UNIQUE (user_id, permanent_id)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_plants_user_id ON plants(user_id);
CREATE INDEX IF NOT EXISTS idx_plants_last_modified ON plants(last_modified);
CREATE INDEX IF NOT EXISTS idx_plants_is_deleted ON plants(is_deleted);

-- RLS политики для plants: каждый пользователь видит только свои записи
ALTER TABLE plants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own plants"
  ON plants FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own plants"
  ON plants FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own plants"
  ON plants FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own plants"
  ON plants FOR DELETE
  USING (auth.uid() = user_id);

-- Таблица метаданных синхронизации (lastSync для инкрементального pull)
CREATE TABLE IF NOT EXISTS sync_metadata (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  last_sync_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own sync metadata"
  ON sync_metadata FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sync metadata"
  ON sync_metadata FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sync metadata"
  ON sync_metadata FOR UPDATE
  USING (auth.uid() = user_id);
