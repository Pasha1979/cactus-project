-- Миграция 00002: серверное время last_modified + недостающие колонки (задача 2.3)
-- Применять через Supabase Dashboard → SQL Editor (см. README_SUPABASE.md)

-- last_modified всегда ставит СЕРВЕР — часы устройств в конфликтах не участвуют.
CREATE OR REPLACE FUNCTION set_last_modified() RETURNS trigger AS $$
BEGIN
  NEW.last_modified = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS plants_set_last_modified ON plants;
CREATE TRIGGER plants_set_last_modified
BEFORE INSERT OR UPDATE ON plants
FOR EACH ROW EXECUTE FUNCTION set_last_modified();

-- Колонки из модели Plant, отсутствовавшие в 00001 (ноль потерь, R-31)
ALTER TABLE plants ADD COLUMN IF NOT EXISTS last_fertilization TIMESTAMPTZ;
ALTER TABLE plants ADD COLUMN IF NOT EXISTS planned_fertilization_date TIMESTAMPTZ;
