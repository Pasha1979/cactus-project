# CURRENT REFACTORING STEP - Текущий шаг рефакторинга

**Дата создания:** 2026-05-09
**Статус:** Завершен

---

## Связанные файлы

- [PROMPT.md](PROMPT.md) - инструкции для работы
- [CURRENT_STATUS.md](CURRENT_STATUS.md) - текущий статус
- [02-REFACTORING_PLAN.md](02-REFACTORING_PLAN.md) - план рефакторинга
- [LESSONS_LEARNED.md](LESSONS_LEARNED.md) - ошибки и уроки
- [CHECKLIST.md](CHECKLIST.md) - чек-листы для проверок ⚠️ ИСПОЛЬЗОВАТЬ ПЕРЕД/ПОСЛЕ ВЫПОЛНЕНИЯ ШАГА

---

## Текущий статус

### Статус: ✅ Завершена

**Текущий шаг:** Шаг 1.10: Разделение PlantProvider
**Начало:** 2026-05-10
**Фаза:** Фаза 1: Критические улучшения (P0)

**Обоснование:** PlantProvider — монолит 2478 строк, содержащий 13 зон ответственности. Разделение необходимо для:
- Упрощения тестирования
- Уменьшения перестроений UI (ChangeNotifier)
- Подготовки к чистой архитектуре

**Результат:**
- И.1-И.4 ✅: Завершены ранее
- 1.8 ✅: Data Migration Manager завершён
- 1.9 ✅: Dependency Injection завершён
- 1.10.1 ✅: 8 новых провайдеров созданы и интегрированы
- 1.10.2 ✅: MultiProvider в main.dart (Android + Windows) — 10 провайдеров
- 1.10.3 ✅: Перенос экранов (итеративно):
  - `qr_scanner_screen` → QrCodeProvider + PlantCrudProvider (Android)
  - `sowing_management_screen` → PlantCrudProvider (Android + Windows)
  - `welcome_screen` → WeatherProvider.initLocation (Android + Windows)
- 1.10.4 ✅: Добавлены недостающие методы:
  - PlantCrudProvider: getPlantsWithQRCode, getPlantsWithoutQRCode, savePlants, createQRCodeBatch, hasUnreadNotifications, clearNotifications
  - QrCodeProvider: renameQRCodeFile
  - WinteringProvider: winteringStartDate, winteringEndDate (алиасы)
  - SyncProvider: restoreFromLocalBackup
- 1.10.5 ✅: flutter analyze — Android (0 errors, 4 info), Windows (0 errors, 4 info)
- 1.10.6 ✅: Перенос экранов (итеративно, по подзадачам):
  - `qr_scanner_screen` → QrCodeProvider + PlantCrudProvider (Android)
  - `sowing_management_screen` → PlantCrudProvider (Android + Windows)
  - `welcome_screen` → WeatherProvider.initLocation (Android + Windows, облако пока через PlantProvider)
  - `qr_management_screen` → QrCodeProvider + PlantCrudProvider (Android + Windows)
  - `select_plants_for_print_screen` → PlantCrudProvider (Android + Windows)
  - `batch_qr_creation_screen` → PlantCrudProvider (Android + Windows)
  - `statistics_screen` → PlantCrudProvider + WateringProvider (Android + Windows)
  - `collection_management_screen` → PlantCrudProvider + WinteringProvider + SyncProvider (Android + Windows)
  - `year_germination_chart_screen` → PlantCrudProvider (Android + Windows)
  - `edit_plant_screen` → PlantCrudProvider (Android + Windows)
  - `print_settings_screen` → QrCodeProvider (Android + Windows)
  - `add_sowing_year_screen` → PlantCrudProvider (Android + Windows)
- 1.10.7 ✅: Оставшиеся экраны (Android + Windows):
  - `care_calendar_screen` → PlantCrudProvider + WateringProvider
  - `plant_statistics_screen` → PlantCrudProvider
  - `wintering_screen` → WinteringProvider
  - `plant_card_screen` → PlantCrudProvider + WateringProvider + PhotoProvider
  - `welcome_screen` → PlantCrudProvider + WeatherProvider + CloudStorageProvider
  - `cloud_storage_provider` → PlantCrudProvider
  - `plant_cards` → PlantCrudProvider + WateringProvider
  - `notes_bottom_sheet` → PlantCrudProvider
  - `main.dart` → PlantCrudProvider + WeatherProvider + все новые провайдеры
- 1.10.8 ✅: Удаление старого PlantProvider (Android + Windows)
- 1.10.9 ✅: Исправление критической ошибки:
  - `loadFromCloudJson` — восстановлена логика merge (слияние локальных и облачных растений)
  - `toJson` — добавлены legacy-поля (globalWateringDates, adultImages, wintering*)
  - Добавлены 7 merge-helper методов
  - Урок записан в LESSONS_LEARNED.md
- 1.10.10 ✅: Финальная проверка:
  - `flutter analyze` Android: 0 errors, 6 info
  - `flutter analyze` Windows: 0 errors, 6 info
  - Ни один метод не вызывает `PlantProvider` (кроме комментариев)

## 🚨 Аудит и исправления (2026-05-11)

**Причина:** Пользователь запросил глубокий аудит перед шагом 1.11. Обнаружены 8 проблем.

### Найденные проблемы

| # | Проблема | Критичность | Статус |
|---|---|---|---|
| 1 | `PlantCrudProvider.savePlants()` — no-op, legacy-поля не сохранялись | 🔴 Критичная | ✅ Исправлено |
| 2 | `WateringProvider` — globalWateringDates только в памяти, без persistence | 🔴 Критичная | ✅ Исправлено |
| 3 | `WinteringProvider` — не инициализировался при старте, сеттеры не сохраняли | 🔴 Критичная | ✅ Исправлено |
| 4 | `PhotoProvider.adultImages` — только в памяти, без persistence | 🔴 Критичная | ✅ Исправлено |
| 5 | `addIndividualWateringDate` — copyWith без присваивания результата | 🟡 Высокая | ✅ Исправлено |
| 6 | `main.dart` — дублирующий `loadPlants()` | 🟠 Средняя | ✅ Исправлено |
| 7 | `main.dart` — не вызывался `qrCodeProvider.loadQRCodeFiles()` | 🟠 Средняя | ✅ Исправлено |
| 8 | `SyncProvider.restoreFromLocalBackup()` — заглушка (return true) | 🟠 Средняя | ✅ Исправлено |

### Исправления

1. **PlantCrudProvider:** добавлены `_loadLegacyData()` и `_saveLegacyData()` для загрузки/сохранения globalWateringDates, adultImages, wintering* из SharedPreferences
2. **PlantCrudProvider.loadFromCloudJson():** сделан `async`, добавлено сохранение mergedPlants в Hive + `_saveLegacyData()` — без этого облачные данные терялись после перезапуска
3. **WateringProvider:** добавлены `load()` / `_save()` — globalWateringDates теперь сохраняются в SharedPreferences
4. **WinteringProvider:** полностью переписан на SharedPreferences, сеттеры сохраняют, `load()` загружает
5. **PhotoProvider:** добавлены `load()` / `_saveAdultImages()` — adultImages persistence
6. **SyncProvider:** реализован `restoreFromLocalBackup(PlantCrudProvider)` через `loadFromCloudJson()`
7. **main.dart (Android + Windows):** добавлена загрузка всех провайдеров при старте, убрано дублирование `loadPlants()`
8. **addIndividualWateringDate:** возвращает `Plant` (результат copyWith), вызывающий код должен сохранить через `PlantCrudProvider.updatePlant()`
9. **cloud_storage_provider (Android + Windows):** добавлен `await` перед `loadFromCloudJson()`

### Проверка после исправлений

- `flutter analyze` Android: 0 errors, 3 info (prefer_final_fields)
- `flutter analyze` Windows: 0 errors, 3 info (prefer_final_fields)
- Все изменения синхронизированы Android ↔ Windows
- Урок записан в LESSONS_LEARNED.md (2026-05-11)

---

## Предыдущие шаги (архив)

### Шаг 1.7: Создание Repository Pattern

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Высокая
**Время:** 2 дня
**Статус:** ⚠️ Частично выполнен (6/13 задач)

**Результат:**
- Созданы абстрактные интерфейсы репозиториев (7 штук): Plant, Watering, Photo, Sync, Note, Wintering, QRCode, Batch
- Создан PlantRepositoryImpl с Hive CRUD операциями
- Создан PlantLocalDataSource для работы с PlantDto
- Создан NetworkInfo для проверки интернет-соединения
- Добавлены новые исключения: DuplicateIdException, OAuth2Exception
- flutter analyze проходит без ошибок

**Выявленные ошибки (исправляются в Фазе И):**
- КРИТИЧЕСКАЯ: Опечатка в маппинге `plannedFertilizationDate` → `plannedTransplantDate` в PlantRepositoryImpl
- ВЫСОКАЯ: Отсутствуют DuplicateFailure и OAuth2Failure в failures.dart
- ВЫСОКАЯ: ErrorHandler не обрабатывает DuplicateIdException и OAuth2Exception
- СРЕДНЯЯ: HiveDatabase без защиты от повторной инициализации
- СРЕДНЯЯ: JSON-посредник в маппинге PlantRepositoryImpl (вместо прямого присвоения)
- СРЕДНЯЯ: Нет реализаций репозиториев (только интерфейсы) — 7 репозиториев без impl
- НИЗКАЯ: PlantLocalDataSource.getPlantById использует неэффективный firstWhere вместо Box.get()
- НИЗКАЯ: Нет DataSource для QRCode, Note, Wintering, GbifCache

---

### Шаг 1.6: Создание Hive Database

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Средняя
**Время:** 2 дня
**Статус:** ⚠️ Частично выполнен (9/11 задач)

**Результат:**
- Созданы DTO модели с @HiveType: plant_dto, qr_code_dto, note_dto, wintering_log_entry_dto, gbif_occurrence_dto
- Создан data/datasources/local/hive_database.dart с инициализацией Hive
- Запущен build_runner для генерации адаптеров (все .g.dart файлы созданы)
- Hive инициализирован в main.dart (оба проекта)
- flutter analyze проходит без ошибок в обоих проектах

**Не выполнено (перенесено в отдельные шаги):**
- Задача 1.6.10 (миграция SharedPreferences → Hive) → Шаг 1.8
- Задача 1.6.11 (индексы для быстрого поиска) → отдельный шаг после Repository Pattern

---

### Шаг 1.5: Создание core/utils - Утилиты

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Низкая
**Время:** 0.5 дня
**Статус:** ✅ Завершен

**Результат:**
- Создан набор утилитарных функций в обоих проектах
- Файлы созданы: date_formatter.dart, validators.dart
- Перенесены утилиты из utils/: gbif_utils.dart, llifle_utils.dart, responsive_helper.dart, translation_utils.dart
- Удалены лишние файлы: string_utils.dart, weather_service.dart
- flutter analyze проходит без ошибок в обоих проектах

---

### Шаг 1.4: Создание core/config - Централизация констант

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Низкая
**Время:** 1 день
**Статус:** ✅ Завершен (с исправлениями)

**Результат:**
- Создана централизованная система констант в обоих проектах
- Файлы созданы: app_constants.dart, api_config.dart, route_config.dart, theme_config.dart
- Перенесены константы PrefsKeys, PlantStatus, PlantCategory в новый app_constants.dart
- Добавлены недостающие PrefsKeys: qrCodeFiles, qrScanHistory, cloudStorageType, hasSeenWelcome
- Добавлены ApiConfig константы: yandexClientId, yandexClientSecret, yandexRedirectUri, yandexTokenEndpoint, yandexAuthEndpoint
- Заменены хардкоды в PlantProvider: _qrFilesKey, _scanHistoryKey (оба проекта)
- Заменены хардкоды в CloudStorageProvider: OAuth credentials, prefs keys (оба проекта)
- Обновлен импорт в plant_provider.dart в обоих проектах
- flutter analyze проходит без ошибок в обоих проектах

---

### Шаг 1.3: Создание core/logger - Логирование

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Низкая
**Время:** 0.5 дня
**Статус:** ✅ Завершен (с исправлениями)

**Результат:**
- Создана централизованная система логирования в обоих проектах
- Файлы созданы: app_logger.dart, logger_service.dart
- Добавлены категории логов в app_logger.dart (SYNC, DB, API, UI, PHOTO, NOTIFICATION)
- Заменены ВСЕ print() на logger.d() в plant_provider.dart (50 замен в каждом проекте)
- flutter analyze проходит без ошибок в обоих проектах
- Исправлены lint предупреждения (deprecated_member_use)

---

### Шаг 1.2: Создание core/error - Обработка ошибок

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Низкая
**Время:** 1 день
**Статус:** ✅ Завершен

**Результат:**
- Создана централизованная система обработки ошибок в обоих проектах
- Файлы созданы: failures.dart, exceptions.dart, error_handler.dart, error_boundary.dart
- flutter analyze проходит без ошибок в обоих проектах
- Исправлены lint предупреждения (use_super_parameters)

---

### Шаг 1.1: Подготовка инфраструктуры

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Низкая
**Время:** 1 день
**Статус:** ✅ Завершен

**Результат:**
- Структура папок создана в обоих проектах (core, data, domain, presentation, services)
- Новые зависимости добавлены: get_it, injectable, hive, hive_flutter, logger, injectable_generator, build_runner, hive_generator
- flutter pub get выполнен успешно в обоих проектах
- flutter analyze проходит без ошибок в обоих проектах

---

## Следующий шаг: Шаг 1.8: Создание Data Migration Manager

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Высокая
**Время:** 1.5 дня
**Статус:** Готов к началу

**Описание:**
Создание системы миграции данных из SharedPreferences в Hive с версионированием, бэкапом и откатом.

**Задачи:**
1.8.1 Создать `data/migrations/data_migration_manager.dart`
1.8.2 Реализовать миграцию SharedPreferences → Hive (все растения, QR-коды, заметки)
1.8.3 Реализовать миграцию с версионированием (currentVersion = 1)
1.8.4 Реализовать автоматический бэкап перед миграцией
1.8.5 Реализовать миграцию поля lastModified (v1)
1.8.6 Добавить миграцию в `main.dart` при запуске
1.8.7 Протестировать миграцию на реальных данных
1.8.8 Добавить проверку целостности данных после миграции
1.8.9 Реализовать возможность отката миграции
1.8.10 Расширить QRCodeDto полем filePath (TODO из И.3) — миграция путей к PDF

**Файлы:**
- `data/migrations/data_migration_manager.dart`
- `data/migrations/migration_v1_add_last_modified.dart`

**Критерии завершения:**
- Миграция работает без потери данных
- Версионирование работает корректно
- Бэкап создается автоматически
- Откат работает корректно
- flutter analyze проходит без ошибок

---

## Общая информация о рефакторинге

### Текущая фаза
Фаза 1: Критические улучшения (P0) — Фаза И ✅ завершена

### Прогресс по фазе 1
6/15 шагов (1.1-1.5 ✅, 1.6 ⚠️ частично, 1.7 ⚠️ частично + Фаза И ✅)

### Прогресс по фазе И
4/4 подшага ✅ (И.1-И.4)

### Общий прогресс
6/39 шагов завершено (33 шага плана + 6 шагов фазы И)

### Оценка времени до завершения
10.5-12.5 недель

---

## Связанные файлы

- [00-BEFORE_REFACTORING.md](00-BEFORE_REFACTORING.md) - состояние до рефакторинга
- [01-AFTER_REFACTORING.md](01-AFTER_REFACTORING.md) - состояние после рефакторинга
- [02-REFACTORING_PLAN.md](02-REFACTORING_PLAN.md) - детальный план
- [CURRENT_STATUS.md](CURRENT_STATUS.md) - текущий статус
- [LESSONS_LEARNED.md](LESSONS_LEARNED.md) - ошибки и уроки

---

## Предупреждения об ошибках в прошлом

**Текущие предупреждения:**
- План может содержать ошибки - не следовать слепо, проверять соответствие целям рефакторинга
- При изменении критических файлов (main.dart) - проверять git diff ДО изменений, flutter analyze ПОСЛЕ изменений
- При обнаружении частично выполненной задачи - немедленно проводить глубокий анализ и исправлять

**Как использовать:**
Перед началом каждого шага проверьте этот раздел на наличие предупреждений для текущего шага. Если есть предупреждения - будьте особенно осторожны и следуйте рекомендациям из LESSONS_LEARNED.md.

---

## Примечания

- Рефакторинг выполняется для обоих проектов (Android и Windows)
- Каждый шаг должен быть протестирован на обеих платформах
- flutter analyze должен проходить после каждого шага
- Сохранять бэкапы перед критическими изменениями
- Применять обязательный чек-лист из 8 пунктов после каждого шага
- Проводить глубокий анализ частично выполненных задач
- Проверять соответствие плана целям рефакторинга
