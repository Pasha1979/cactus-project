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

### Статус: ✅ Завершён — Шаг 2.4 полностью завершён

**Текущий шаг:** Шаг 2.5: Оптимизация дерева виджетов
**Завершён:** 2026-05-13
**Фаза:** Фаза 2: Оптимизация производительности (P1)

**Шаг 2.4 завершён полностью:**

**Вариант А (Фаза 1) — Парсинг в isolate:**
- ✅ 2.4.1 Создать `services/isolates/parser_isolate.dart` (Android + Windows)
- ✅ 2.4.2 Перенести парсинг Llifle HTML в isolate
- ✅ 2.4.3 Перенести парсинг GBIF JSON в isolate
- ✅ 2.4.4 `_IsolateMessage` через SendPort/ReceivePort (внутри ParserIsolate)
- ✅ 2.4.5 Таймауты (5 сек) и `Isolate.kill()` при ошибках/timeout
- ✅ 2.4.6 Тестирование UI без блокировок — пользователь подтвердил
- ✅ 2.4.7 Проверка CPU и памяти — пользователь подтвердил

**Вариант Б (Фаза 2) — HTTP + парсинг + сериализация в isolate:**
- ✅ 2.4.8 Создан `services/isolates/http_isolate.dart` (Android + Windows)
- ✅ 2.4.8 Интегрирован в `GbifService._fetchFromGbifApi` (Android + Windows)
- ✅ 2.4.8 Интегрирован в `LlifleService._fetchSpeciesPage` (Android + Windows)
- ✅ 2.4.9 jsonEncode кэша выполняется в isolate
- ✅ 2.4.10 `flutter analyze` — Android (0 issues), Windows (0 issues)

**Архитектура pipeline (Вариант Б):**
```
main thread:
  1. Проверить кэш (SharedPreferences) → если есть, вернуть
  2. Передать URL в HttpIsolate

isolate (http_isolate.dart):
  3. HTTP GET запрос
  4. Парсинг HTML/JSON
  5. jsonEncode → готовая JSON-строка

main thread:
  6. Сохранить в SharedPreferences (кэш)
  7. jsonDecode → Map → вернуть провайдеру
```

**Следующий шаг:** 2.5 Оптимизация дерева виджетов

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

## Шаг 1.11: Разделение CloudStorageProvider (2026-05-11)

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Высокая
**Время:** 2 дня
**Статус:** ✅ Завершён

**Результат:**
- Старый CloudStorageProvider преобразован в фасад (`lib/providers/cloud_storage_provider.dart`)
- Фасад делегирует работу 4 специализированным сервисам:
  - `YandexAuthService` — OAuth2, токены, подключение
  - `YandexDiskService` — HTTP-операции с Яндекс.Диск
  - `SyncManager` — синхронизация данных (conflict resolution включён)
  - `PhotoSyncService` — синхронизация фотографий
- Локальный сервер для Windows OAuth2 встроен в `YandexAuthService._startLocalServer()`
- Хранение токенов через `FlutterSecureStorage` встроено в `YandexAuthService`
- Все экраны обновлены для работы с новой архитектурой
- flutter analyze проходит без ошибок (Android + Windows)

**Примечание:** Отдельные файлы `auth_service.dart`, `token_storage.dart`, `cloud_storage_service.dart`,
`cloud_file.dart`, `conflict_resolver.dart`, `sync_status.dart`, `deep_link_handler.dart`,
`local_server.dart`, `platform_adapter.dart` объединены по функциональности в 4 сервиса.

---

## Шаг 1.12: Разбиение PlantCardScreen (2026-05-11)

**Фаза:** Фаза 1: Критические улучшения (P0)
**Сложность:** Высокая
**Время:** 2 дня
**Статус:** ✅ Завершён

**Результат:**
- `plant_card_screen.dart` перенесён в `presentation/screens/plant_card/` (~1200 строк)
- Созданы 6 вкладок в `presentation/screens/plant_card/tabs/`:
  - `overview_tab.dart` — обзор растения (география, описание, синонимы)
  - `care_tab.dart` — уход (погода, советы, действия)
  - `history_tab.dart` — история и заметки
  - `gallery_tab.dart` — галерея фото (с типизированными callback-ами)
  - `distribution_tab.dart` — карта распространения + GBIF-данные
  - `seedlings_tab.dart` — сеянцы (для витрин)
- Созданы 7 виджетов в `presentation/screens/plant_card/widgets/`:
  - `geography_section.dart`, `description_section.dart`, `synonyms_section.dart`
  - `care_tips_section.dart`, `action_card.dart`
  - `stat_card.dart`, `empty_gbif_state.dart`
- Исправлены все deprecated API (`.withOpacity()` → `.withValues()`)
- Исправлены info-сообщения (`prefer_final_fields`)
- Разорвана циклическая зависимость `SeedlingsTab` → `PlantCardScreen` через callback
- Все импорты обновлены (`plant_cards.dart`, `qr_scanner_screen.dart`)
- flutter analyze: 0 errors, 0 warnings, 0 info (Android + Windows)
- Сборка: `app-debug.apk` ✅, `my_cactus.exe` ✅

---

## Дополнительно: Hive индексы (выполнено при аудите 1.1–1.12)

**Дата:** 2026-05-11
**Статус:** ✅ Завершено

**Что сделано:**
- Создан `data/datasources/local/plant_index_manager.dart` — индексный слой поверх Hive
- Индексы по `status`, `category`, `displayId` → списки `permanentId`
- `PlantLocalDataSource.getPlantById` исправлен с `firstWhere` (O(n)) на `box.get(id)` (O(1))
- `getPlantsByStatus` / `getPlantsByCategory` — O(1) по индексу + O(k) загрузка объектов
- Авто-обновление индексов при CRUD-операциях
- `DataMigrationManager._migratePlants` — `rebuildIndex()` после массовой миграции
- Fallback к O(n) оставлен для случаев без индекса
- Файлы синхронизированы Android ↔ Windows
- `flutter analyze`: 0 errors, 0 warnings, 0 info (Android + Windows)
- Сборка: `app-debug.apk` ✅, `my_cactus.exe` ✅

**Урок:** Урок 18 добавлен в LESSONS_LEARNED.md

---

## Дополнительно: Шаг 1.13 — Сервисный слой API

**Дата:** 2026-05-11
**Статус:** ✅ Завершено

**Что сделано:**
- Создан `services/api/gbif_service.dart` — GBIF API сервис с кэшированием (7 дней)
- Создан `services/api/llifle_service.dart` — Llifle.com парсер + интеграция GBIF
- Создан `services/api/weather_service.dart` — OpenWeatherMap API сервис
- Создан `models/gbif_occurrence.dart` — доменная модель GbifOccurrence
- `GbifOccurrence` вынесен из `utils/gbif_utils.dart` в отдельную модель
- Все `print` заменены на `AppLogger` (добавлен класс `AppLogger` в `core/logger/app_logger.dart`)
- Удалены старые `utils/gbif_utils.dart`, `utils/llifle_utils.dart`, `utils/weather_service.dart`
- Удалены мёртвые копии в `core/utils/`
- Все импорты обновлены в Android и Windows
- Тестовые скрипты `test_gbif.dart` и `test_gbif_integration.dart` обновлены
- `flutter analyze`: 0 errors, 0 warnings, 0 info (Android + Windows)

---

## Дополнительно: Шаг 1.15 — DI-интеграция + закрытие TODO

**Дата:** 2026-05-11
**Статус:** ✅ Завершено

**Что сделано:**
- **1.15.1** ✅: SyncProvider, PhotoProvider, BatchProvider подключены к репозиториям через DI
- **1.15.2** ✅: cleanupUnusedPhotosForSelected + deleteAllPhotosForSelected перенесены в PhotoProvider, PlantCrudProvider делегирует к ним
- **1.15.3** ✅: exportSelectedToCSV реализован (экспорт в CSV с заголовками, SnackBar с результатом)
- **1.15.4** ✅: SyncRepositoryImpl — комментарии обновлены (no-op для syncWithCloud оставлен, заглушка getSyncStatus)
- **1.15.5** ✅: setLlifleAsMainPhoto в PhotoRepositoryImpl — TODO убран, реализация подтверждена
- **1.15.6** ✅: ensureLocalPhotosExist — комментарий обновлён, метод оставлен в PlantCrudProvider (требует доступ к _plants)
- **1.15.7** ✅: settings_box добавлен в HiveDatabase, WateringRepositoryImpl.getGlobalWateringDates/saveGlobalWateringDates реализованы через settingsBox
- **1.15.8** ✅: QRCodeDto расширен полем filePath (@HiveField(5)), QRCodeRepositoryImpl обновлён, миграция обновлена
- **1.15.9** ✅: BatchRepositoryImpl.createBatch/updateBatch реализованы
- **1.15.10** ✅: flutter analyze — **0 errors, 0 warnings, 0 info** (Android + Windows)
- **1.15.11** ✅: Все TODO(1.15.x) в коде обработаны — реализованы или заменены на комментарии
- **1.15.12** ✅: PlantRepositoryImpl._mapToEntity — добавлен _safeJsonList для защиты от крашей при некорректном JSON

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
- Задача 1.6.11 (индексы для быстрого поиска) → ✅ Выполнена при аудите 1.1–1.12

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
Фаза 1: Критические улучшения (P0) — ✅ **ЗАВЕРШЕНА** (все шаги 1.1-1.15 + Фаза И пройдены)

### Прогресс по фазе 1
15/15 шагов ✅ (1.1-1.5 ✅, 1.6 ⚠️ частично, 1.7 ⚠️ частично + Фаза И ✅, 1.8 ✅, 1.9 ✅, 1.10 ✅, 1.11 ✅, 1.12 ✅, 1.13 ✅, 1.14 ✅, 1.15 ✅)

### Прогресс по фазе И
6/6 подшагов ✅ (И.1-И.4 + И.5 + И.6)

### Прогресс по фазе 2
3.0/10 шагов (2.0 ✅, 2.1 ✅)

**2.0 Исправления из глубокого аудита — ✅ Завершён:**
- 2.0.1 Hive race condition fix (Android + Windows)
- 2.0.2 Удалены пустые dispose() из 8 провайдеров (Android + Windows)
- 2.0.3 Перенос CloudStorageProvider → presentation/providers (Android + Windows)
- 2.0.4 Future.wait для параллельной загрузки провайдеров (Android + Windows)
- 2.0.5 Safe date parsing (_parseDateTimeSafe, _parseDateTimeList) в Plant (Android + Windows)
- 2.0.6 PlantStatusMapper — централизованный маппер статусов (Android + Windows)

**2.1 go_router — ✅ Завершён:**
- 2.1.1 ✅ Добавлен go_router ^14.8.0 в pubspec.yaml (Android + Windows)
- 2.1.2 ✅ Создан presentation/routers/app_router.dart с 18 (Android) / 17 (Windows) маршрутами
- 2.1.3 ✅ Маршруты определены (выполнено в рамках 2.1.2)
- 2.1.4 ✅ Замена Navigator.push — 6 микро-шагов:
  - [x] 2.1.4.1 main.dart (7 вызовов)
  - [x] 2.1.4.2 plant_card_screen.dart + plant_cards.dart (4 вызова)
  - [x] 2.1.4.3 sowing_management_screen.dart (5 вызовов + /sowing-year/:year маршрут)
  - [x] 2.1.4.4 statistics_screen.dart (4 вызова + /plant-list маршрут)
  - [x] 2.1.4.5 qr_management_screen.dart (4 вызова)
  - [x] 2.1.4.6 Остальные экраны (8+ вызовов)
- 2.1.5 ✅ Deep linking (MaterialApp.router, redirect, AndroidManifest, Windows registry)
- 2.1.6 ✅ Тестирование навигации (flutter analyze 0 errors, все маршруты проверены)

**🔄 Дополнительный аудит 2.0 + 2.1 (2026-05-12):**
- ✅ Исправлен deep link redirect — добавлена защита от перенаправления внешних deep links на `/welcome`
- ✅ Исправлен route mismatch — `/add-sowing-year` → `/sowing/add` в app_router.dart
- ✅ Исправлены пропущенные `Navigator.push` в widgets (care_tips, description, geography, history_tab)
- ✅ Исправлен `DateTime.parse` → `_parseDateTimeSafe` в `GerminationRecord`, `FloweringRecord`, `Note`
- ✅ Добавлены fallback `?? ''` для `id`, `title`, `text` в `Note.fromJson`
- ✅ Обновлен CHECKLIST.md — добавлен чек-лист go_router навигации
- ✅ Обновлен LESSONS_LEARNED.md — добавлены ошибки #5–#9
- ✅ Обновлен 02-REFACTORING_PLAN.md — добавлены предупреждения для будущих изменений навигации

### Технический долг / Напоминания
- **dispose() в провайдерах:** удалены пустые `@override void dispose() { super.dispose(); }` из 8 провайдеров (2.0.2). Когда появятся реальные ресурсы (Timer, StreamSubscription, isolate, http client) — добавить `dispose()` с реальной очисткой. Проверить: watering, wintering, photo, batch, sync, qr_code, weather, plant_crud провайдеры.

**🔄 Глубокий аудит 2.0 + 2.1 + 2.2 (2026-05-12):**
- ✅ `flutter analyze` — чистый (Android + Windows)
- ✅ Все TODO/FIXME — либо отсутствуют, либо platform-specific (printing/pdfium)
- ✅ Platform differences — полностью сохранены (QRScanner, printing, Platform checks)
- ✅ go_router redirect — защита deep links работает (`state.uri.path != '/'`)
- ✅ `navigatorKey` + `context.mounted` — корректно в `cloud_storage_provider.dart`
- ✅ `isLoading` backward compatibility — `bool get isLoading => _plantsState is UiLoading`
- ⚠️ **Найдено и исправлено:** `DateTime.parse` без защиты в 5 файлах:
  - `models/qr_code.dart` — `QRCode.fromJson`
  - `models/qr_code_file.dart` — `QRCodeFile.fromJson`
  - `presentation/providers/wintering_provider.dart` — `WinteringLogEntry.fromJson`
  - `data/repositories/wintering_repository_impl.dart` — `saveWinteringSettings`
  - `presentation/providers/plant_crud_provider.dart` — `loadFromCloudJson`
- ✅ LESSONS_LEARNED.md обновлен — добавлена ошибка #10

**2.3 Кэширование изображений (Вариант А) — ✅ Завершён:**
- 2.3.1 ✅ Заменён `Image.network` → `CachedNetworkImage` в 4 файлах (`geography_section`, `edit_plant_screen`, `plant_card_screen`, `plant_cards`)
- 2.3.2 ✅ `flutter_image_compress` проверен на Windows — собирается (flutter build windows прошёл)
- 2.3.4 ✅ Создан `services/image/photo_cache_manager.dart` — централизованный кэш для GBIF/llifle URL
- ✅ `flutter_cache_manager` добавлен в `pubspec.yaml` (Android + Windows) — явная зависимость
- ✅ Исправлен `main.cpp` warning C4267 (deep linking код) — `static_cast<DWORD>` для `RegSetValueExW`

**⏳ Отложено из 2.3 (план возврата):**
- `image_processor.dart` + сжатие в `PhotoProvider` → **шаг 2.10** (после 2.9 надёжность синхронизации)
- Prefetch галереи → **шаг 2.8.7** (в рамках финального тестирования Фазы 2)

**2.2 UiState pattern — ✅ Завершён:**
- 2.2.1 ✅ Создан `core/ui/ui_state.dart` — sealed class `UiState<T>` с `UiLoading`/`UiSuccess`/`UiError`
- 2.2.2 ✅ Интегрирован в `WateringProvider` — `_uiState` с `onRetry: load`
- 2.2.3 ✅ Интегрирован в `PlantCrudProvider` — `_plantsState` для `loadPlants`/`addPlant`/`updatePlant`/`deletePlant`/`savePlants`
- 2.2.4 ✅ Создан `UiStateBuilder<T>` + `ErrorCard` с кнопкой «Повторить»

### Общий прогресс
23/42 шагов завершено (2.0 ✅ + 2.1 ✅ + 2.2 ✅ + 2.3 ✅)

> Всего шагов увеличено с 41 до 42 (добавлен 2.10 Оптимизация изображений — сжатие, перенесённый из 2.3)

### Оценка времени до завершения
8-10 недель (обновлено после завершения 2.0 и части 2.1)

### Дополнительно: новые шаги из аудита (внесены в план 2026-05-11)
- **2.0 Исправления из глубокого аудита** — 6 задач (Hive race condition, dispose(), CloudStorageProvider перемещение, Future.wait, _parseDateTimeSafe, PlantStatusMapper)
- **2.9 Надёжность синхронизации** — 5 задач (Lock, лимит ретраев, backoff, валидация облака, индикатор прогресса)

### Доработка плана (аудит логики и дублей, 2026-05-11)
- **Убран дубль:** PlantStatusMapper удалён из 2.7 (уже есть в 2.0)
- **Убран рискованный шаг:** 2.6 Code Generation (freezed) заменён на «Очистка deprecated кода»
- **Убран дубль:** 3.1.7 CI/CD удалён (уже покрыто шагом 3.3)
- **Обновлены оценки:** Фаза 2 (2–2.5 недели), Фаза 3 (2–2.5 недели), итого 8.5–10.5 недель

---

## Мои успешные практики (адаптация)

### Что работает:
1. **Микро-шаги + коммиты** — легко откатить, легко проверить
2. **Параллельно Android + Windows** — diff для проверки
3. **Автоматический аудит (9 пунктов)** — без запроса пользователя
4. **UiState sealed class** — типобезопасность, retry
5. **Вариант А по умолчанию** — консервативный подход для рисков

### Что усиливать:
1. **Предсказание ошибок ПЕРЕД кодом** — анализировать 3 вероятных ошибки
2. **Самопроверка инструментов** — перед каждым вызовом
3. **Проверка вложенных моделей** — при любом парсинге

---

## Предупреждения для следующих шагов (2.4+)

| Шаг | Риск | Предостережение |
|-----|------|-----------------|
| **2.4 Isolates** | Memory leaks, deadlocks | Проверить `Isolate.kill()` при dispose |
| **2.4 Isolates** | Сложность отладки | Добавить логирование, тестировать на Windows |
| **2.5 Widget tree** | const-оптимизация может не сработать | Проверить каждый const через flutter analyze |
| **2.6 Cleanup** | Удалить лишнее | Проверить git diff перед удалением |
| **2.9 Синхронизация** | Lock + retry — сложная логика | Проверить на race condition |
| **2.10 Сжатие** | Синхронизация Яндекс Диска | Тестировать с реальным фото, путь не менять |

---

## Проверка 9 пунктов (шаг 2.4, 2026-05-12)

| # | Пункт | Результат |
|---|-------|-----------|
| 1 | Выполнено в полном объеме для ОБОИХ проектов | ✅ Android + Windows — `parser_isolate.dart`, `gbif_service.dart`, `llifle_service.dart` |
| 2 | Все функции и фичи сохранены | ✅ Парсинг Llifle и GBIF работает, логика не изменена, только перенос в isolate |
| 3 | Платформенные различия сохранены | ✅ Оба проекта идентичны, platform-specific код не затронут |
| 4 | Нет скрытых багов для будущих шагов | ✅ Isolate.kill() при dispose, таймауты, exception handling |
| 5 | Нет багов для последующих запусков | ✅ Кэш SharedPreferences — в main thread, нет race condition |
| 6 | Код, файлы, связи, зависимости логичны | ✅ `flutter analyze` чистый на обоих проектах |
| 7 | Нет TODO, FIXME, HACK, XXX, STUB | ✅ Проверено — не найдено |
| 8 | `flutter analyze` чистый на обоих проектах | ✅ Android: No issues, Windows: No issues |
| 9 | Все учитывая цели рефакторинга, код чистый | ✅ Цель достигнута — парсинг в isolate, UI не блокируется |

**Вывод:** Шаг 2.4 (Фаза 1 — Вариант А) готов к тестированию. Задачи 2.4.1-2.4.5 выполнены. Осталось 2.4.6 (UI/FPS) и 2.4.7 (CPU/память).

---

## Связанные файлы

- [MY_COLLABORATION_GUIDE.md](MY_COLLABORATION_GUIDE.md) — руководство по совместной работе (адаптация)
- [00-BEFORE_REFACTORING.md](00-BEFORE_REFACTORING.md) - состояние до рефакторинга
- [01-AFTER_REFACTORING.md](01-AFTER_REFACTORING.md) - состояние после рефакторинга
- [02-REFACTORING_PLAN.md](02-REFACTORING_PLAN.md) - детальный план
- [CURRENT_STATUS.md](CURRENT_STATUS.md) - текущий статус
- [LESSONS_LEARNED.md](LESSONS_LEARNED.md) - ошибки и уроки
- [CHECKLIST.md](CHECKLIST.md) — чек-листы для проверок

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
