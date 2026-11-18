-- Миграция 00003: user_settings для legacy-настроек + sync_now() (задача 2.4б)
-- Применять через Supabase Dashboard → SQL Editor (см. README_SUPABASE.md)

CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  key TEXT NOT NULL,
  value JSONB,
  last_modified TIMESTAMPTZ DEFAULT now(),
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, key)
);

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own settings"
  ON user_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings"
  ON user_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own settings"
  ON user_settings FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own settings"
  ON user_settings FOR DELETE
  USING (auth.uid() = user_id);

CREATE TRIGGER user_settings_set_last_modified
BEFORE INSERT OR UPDATE ON user_settings
FOR EACH ROW EXECUTE FUNCTION set_last_modified();

-- Точные серверные часы (устраняет отклонение updateLastSync из 2.4)
CREATE OR REPLACE FUNCTION sync_now() RETURNS timestamptz
  LANGUAGE sql SECURITY INVOKER AS $$ SELECT now(); $$;
GRANT EXECUTE ON FUNCTION sync_now() TO authenticated;
