# Подключение Supabase — инструкция для владельца

Проект: `https://tbabdqksvjzaxtpzrvgr.supabase.co` (задача 2.2, R-003/R-029/R-030).

## 1. Ключи

В `env.json` (локально, НЕ коммитить) уже добавлены:

```json
"SUPABASE_URL": "https://tbabdqksvjzaxtpzrvgr.supabase.co",
"SUPABASE_ANON_KEY": "sb_publishable_..."
```

Anon key — публичный ключ, безопасен для клиента. Database Password нужен только для админки, в коде не используется.

Запуск приложения — как раньше:

```
flutter run -d windows --dart-define-from-file=env.json
```

Если ключей нет — приложение работает локально, Supabase просто не инициализируется.

## 2. Применение миграции (создание таблиц)

1. Открой https://supabase.com/dashboard → проект `tbabdqksvjzaxtpzrvgr`.
2. В левом меню — **SQL Editor** → **New query**.
3. Скопируй **весь** текст файла `supabase/migrations/00001_initial_schema.sql` и вставь в редактор.
4. Нажми **Run**. Ожидаемый результат: `Success. No rows returned`.

## 3. Проверка, что таблицы созданы

В **Table Editor** должны появиться таблицы `plants` и `sync_metadata`.

Или в SQL Editor:

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

-- Проверка RLS (должно вернуть 2 строки с ENABLED)
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public';
```

## 4. Проверка аутентификации

1. В Dashboard → **Authentication** → **Providers** убедись, что **Email** включён.
2. (Рекомендуется для теста) Authentication → **Sign In / Up** → выключи "Confirm email", чтобы вход работал сразу после регистрации.
3. Тест в SQL Editor создавать не нужно — регистрация/вход идут через приложение:
   `AuthRepository.signUp(email, password)` / `signIn(email, password)`.

## 5. Что дальше

- Задачи 2.3–2.5: логика SyncEngine (push/pull, конфликты, фото на Яндекс.Диск).
- Задача 2.6: миграция существующих локальных данных в Supabase.

## 6. Миграция 00002 (серверное время)

После применения 00001 примените `supabase/migrations/00002_server_time.sql`
тем же способом (SQL Editor → Run). Она добавляет триггер `last_modified`
(серверное время для конфликтов LWW) и колонки `last_fertilization`,
`planned_fertilization_date`.

## 7. Миграция 00003 (user_settings + sync_now)

Примените `supabase/migrations/00003_user_settings.sql` (SQL Editor → Run):
таблица `user_settings` с RLS, триггер `last_modified`, функция `sync_now()`.

## 8. Миграция 00004 (photo_passports)

Примените `supabase/migrations/00004_add_photo_passports.sql` (SQL Editor → Run):
JSONB-колонка `photo_passports` в `plants` — фото-паспорта (этап 3.2).
