# HANDOFF (автоген) · 2026-11-18 · `main` · 128b99d chore(brain): session handoff - end of ses

Сделано:
- 128b99d chore(brain): session handoff - end of session after
- 55ac42b chore(brain): sync status/handoff after task 3.1
- 4a76406 feat(photo): photo passport models and local CRUD (n
- 80f10dc chore(brain): sync status/handoff after task 2.7

Дальше:
1. Завершить миграцию мозга v4 (реестры+v4+архив+скрипты→проверка→коммит)
2. Решить Q-4: Hive финально или 5 сущностей — блокирует T-19
3. Уточнить статусы: фото-сравнение (Q-2), уведомления (Q-3), печать Wind

Ждут решения: Q-1, Q-2, Q-3, Q-4, Q-5 · Последнее решение: D-27 — «Зафиксировано» — точки отката документации; актуальный стат

---

## ТОЧКА ВОЗОБНОВЛЕНИЯ (ручная запись, конец сессии 2026-11-18)

**Завершено в сессии:** задачи 2.5, 2.5б, 2.6, 2.7, 3.1 — этап 2 (синхронизация
Supabase) закрыт полностью; этап 3 (фото-паспорта) начат: модели + локальный CRUD.

**СЛЕДУЮЩИЙ ШАГ — ЗАДАЧА 3.2:** фото-паспорта — интеграция с YandexDiskService +
миграция userPhotos → паспорта.

**Открытые вопросы для 3.2 (обсудить ДО реализации):**
1. `photoPassports` не едет в Supabase — нет колонки в `plants` (40 полей покрыты 1:1).
   Варианты: jsonb-колонка `photo_passports` или отдельная таблица `photo_passports`.
2. Миграция userPhotos → как разложить по паспортам (1 фото = 1 паспорт с 1 версией?).
3. Загрузка файлов на Диск при создании версии — какой сервис/путь (/MyCactus/photos/?).

**Состояние:** 74 зелёных теста; 2 предсуществующих падения app_flow_test (не наши).
**Файлы вехи:** lib/core/models/photo_passport.dart, lib/core/sync/photo_passport_manager.dart,
Plant.photoPassports (+PlantDto поле 40), test/core/photo_passport_test.dart (7 тестов).
