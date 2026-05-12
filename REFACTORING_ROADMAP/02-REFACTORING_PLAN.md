# ПЛАН РЕФАКТОРИНГА MY CACTUS

**Дата создания:** 2026-05-09
**Дата изменения:** 2026-05-11
**Статус:** Активный (Фаза 1 ✅ завершена, Фаза 2 🔄 готовится)
**Общая оценка:** 8.5-10.5 недель

---

## Связанные файлы

- [PROMPT.md](PROMPT.md) - инструкции для работы
- [CURRENT_STATUS.md](CURRENT_STATUS.md) - текущий статус
- [03-CURRENT_REFACTORING_STEP.md](03-CURRENT_REFACTORING_STEP.md) - текущий шаг
- [00-BEFORE_REFACTORING.md](00-BEFORE_REFACTORING.md) - состояние до рефакторинга
- [01-AFTER_REFACTORING.md](01-AFTER_REFACTORING.md) - состояние после рефакторинга
- [LESSONS_LEARNED.md](LESSONS_LEARNED.md) - ошибки и уроки
- [CHECKLIST.md](CHECKLIST.md) - чек-листы для проверок ⚠️ ИСПОЛЬЗОВАТЬ ПЕРЕД/ПОСЛЕ ИЗМЕНЕНИЙ ПЛАНА

---

# СОДЕРЖАНИЕ

1. [Общая информация](#общая-информация)
2. [Фазы рефакторинга](#фазы-рефакторинга)
3. [Детальный план по фазам](#детальный-план-по-фазам)
4. [Приоритеты](#приоритеты)
5. [Стратегия выполнения](#стратегия-выполнения)

---

# ОБЩАЯ ИНФОРМАЦИЯ

## Цель рефакторинга
Улучшение архитектуры, производительности, надежности и поддерживаемости приложений Windows и Android.

## Подход
- Пошаговый рефакторинг без потери функциональности
- Каждое изменение должно быть тестировано
- Сохранение всех существующих функций
- Документирование каждого шага

## Риски
- Потеря данных при миграции на Hive
- Регрессии функциональности
- Долгое время блокировки новых функций
- Ошибки в build_runner при code generation
- Проблемы с изолятами (memory leaks, deadlocks)
- Превышение сроков из-за непредвиденных сложностей
- Сложность отладки изолятов
- Проблемы с Firebase Crashlytics конфигурацией
- Проблемы с CI/CD пайплайном на разных платформах

## Митигация рисков
- Автоматические бэкапы перед критическими изменениями
- Комплексное тестирование после каждого шага
- Возможность отката к предыдущему состоянию
- Тестирование build_runner на небольшом наборе данных перед запуском на всем проекте
- Профилирование изолятов с Flutter DevTools
- Приоритизация P0 задач, возможность остановки на любом этапе
- Логирование всех операций в изолятах
- Тестирование Firebase конфигурации на dev окружении
- Пошаговое внедрение CI/CD с тестированием на каждом шаге

---

# ФАЗЫ РЕФАКТОРИНГА

## Фаза 1: Критические улучшения (P0) - 4-5 недель

**Цель:** Решить критические архитектурные проблемы и создать базовую инфраструктуру

**Улучшения:**
1. Разделение PlantProvider (2230 строк)
2. Repository Pattern
3. Замена SharedPreferences на Hive
4. Dependency Injection (GetIt)
5. Разделение CloudStorageProvider
6. Разбиение PlantCardScreen
7. Обработка ошибок (ErrorHandler)
8. Миграция данных
9. Централизация констант
10. Базовая инфраструктура (logger, utils, API services)

**Приоритет:** 🔴 Критично

## Фаза 2: Важные улучшения (P1) - 2-2.5 недели

**Цель:** Улучшить UX и надежность

**Улучшения:**
1. Исправления из глубокого аудита (race condition, dispose, Future.wait)
2. go_router навигация
3. UiState pattern (loading/error)
4. Кэширование изображений
5. Isolates для тяжелых операций
6. Оптимизация дерева виджетов
7. Очистка deprecated кода
8. Строгий линтер
9. Надёжность синхронизации (Lock, валидация облака, backoff)

**Приоритет:** 🟡 Важно

## Фаза 3: Желательные улучшения (P2) - 2-2.5 недели

**Цель:** Подготовка к масштабированию

**Улучшения:**
1. Тестирование (unit/widget/integration)
2. Accessibility
3. CI/CD пайплайн
4. Crash Reporting (Firebase Crashlytics)
5. Документация API

**Приоритет:** 🟢 Желательно

## Фаза 4: Будущее (P3) - по необходимости

**Цель:** Подготовка к будущим фичам

**Улучшения:**
1. Feature flags
2. Система прав доступа (multi-user)

**Приоритет:** 🔵 Будущее

---

# ДЕТАЛЬНЫЙ ПЛАН ПО ФАЗАМ

## ФАЗА 1: КРИТИЧЕСКИЕ УЛУЧШЕНИЯ (P0)

### 1.1 Подготовка инфраструктуры (1 день)

**Задачи:**
1.1.1 Создать структуру папок core/, data/, domain/, presentation/, services/
1.1.2 Добавить новые зависимости в pubspec.yaml (оба проекта)
1.1.3 Запустить flutter pub get (оба проекта)
1.1.4 Проверить flutter analyze (оба проекта)

**Зависимости:**
```yaml
dependencies:
  get_it: ^7.6.0
  injectable: ^2.3.2
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  logger: ^2.0.0+1

dev_dependencies:
  injectable_generator: ^2.4.1
  build_runner: ^2.4.8
  hive_generator: ^2.0.1
```

**Проверка:** flutter analyze проходит без ошибок

---

### 1.2 Создание core/error - Обработка ошибок (1 день)

**Задачи:**
1.2.1 Создать core/error/failures.dart с абстрактными классами ошибок
1.2.2 Создать core/error/exceptions.dart с пользовательскими исключениями
1.2.3 Создать core/error/error_handler.dart с централизованной обработкой
1.2.4 Создать core/error/error_boundary.dart для UI

**Файлы:**
- `core/error/failures.dart`
- `core/error/exceptions.dart`
- `core/error/error_handler.dart`
- `core/error/error_boundary.dart`

**Проверка:** flutter analyze проходит без ошибок

---

### 1.3 Создание core/logger - Логирование (0.5 дня)

**Задачи:**
1.3.1 Создать core/logger/app_logger.dart с AppLogger
1.3.2 Определить категории логов (SYNC, DB, API, UI, PHOTO, NOTIFICATION)
1.3.3 Заменить первые print() на AppLogger calls в PlantProvider

**Файлы:**
- `core/logger/app_logger.dart`

**Проверка:** flutter analyze проходит без ошибок

---

### 1.4 Создание core/config - Централизация констант (1 день)

**Задачи:**
1.4.1 Создать core/config/app_constants.dart
1.4.2 Создать core/config/api_config.dart
1.4.3 Создать core/config/route_config.dart
1.4.4 Создать core/config/theme_config.dart
1.4.5 Перенести константы из app_constants.dart в новые файлы
1.4.6 Заменить хардкод констант в PlantProvider и CloudStorageProvider

**Файлы:**
- `core/config/app_constants.dart`
- `core/config/api_config.dart`
- `core/config/route_config.dart`
- `core/config/theme_config.dart`

**Проверка:** flutter analyze проходит без ошибок, все константы централизованы

---

### 1.5 Создание core/utils - Утилиты (0.5 дня)

**Задачи:**
1.5.1 Создать core/utils/date_formatter.dart
1.5.2 Создать core/utils/validators.dart
1.5.3 Перенести общие утилиты из utils/

**Файлы:**
- `core/utils/date_formatter.dart`
- `core/utils/validators.dart`

**Проверка:** flutter analyze проходит без ошибок

---

### 1.6 Создание Hive Database (2 дня)

**Задачи:**
1.6.1 Создать data/models/plant_dto.dart с @HiveType аннотациями
1.6.2 Создать data/models/qr_code_dto.dart с @HiveType аннотациями
1.6.3 Создать data/models/note_dto.dart с @HiveType аннотациями
1.6.4 Создать data/models/wintering_log_entry_dto.dart с @HiveType аннотациями
1.6.5 Создать data/models/gbif_occurrence_dto.dart с @HiveType аннотациями
1.6.6 Создать data/datasources/local/hive_database.dart
1.6.7 Создать box'ы для plants, qr_codes, notes, wintering_logs, gbif_cache
1.6.8 Запустить build_runner для генерации адаптеров
1.6.9 Инициализировать Hive в main.dart
1.6.10 Создать тестовую миграцию SharedPreferences → Hive
1.6.11 ✅ Добавить индексы для быстрого поиска (по permanentId, displayId, статусу, категории)

**Файлы:**
- `data/models/plant_dto.dart`
- `data/models/qr_code_dto.dart`
- `data/models/note_dto.dart`
- `data/models/wintering_log_entry_dto.dart`
- `data/models/gbif_occurrence_dto.dart`
- `data/datasources/local/hive_database.dart`
- `data/datasources/local/plant_index_manager.dart`
- `data/datasources/local/plant_local_datasource.dart` (с индексной поддержкой)

**Проверка:**
- build_runner прошел без ошибок
- Hive инициализируется корректно
- Миграция тестовых данных работает
- Индексы работают корректно

---

### 1.7 Создание Repository Pattern (2 дня)

**Задачи:**
1.7.1 Создать domain/repositories/plant_repository.dart (абстрактный)
1.7.2 Создать data/repositories/plant_repository_impl.dart
1.7.3 Создать data/datasources/local/plant_local_datasource.dart
1.7.4 Реализовать PlantRepositoryImpl с Hive (CRUD операции)
1.7.5 Создать domain/repositories/watering_repository.dart
1.7.6 Создать domain/repositories/photo_repository.dart
1.7.7 Создать domain/repositories/sync_repository.dart
1.7.8 Создать domain/repositories/note_repository.dart
1.7.9 Создать domain/repositories/wintering_repository.dart
1.7.10 Создать domain/repositories/qr_code_repository.dart
1.7.11 Создать domain/repositories/batch_repository.dart
1.7.12 Добавить NetworkInfo для проверки интернет-соединения
1.7.13 Создать пользовательские исключения (DuplicateIdException, ValidationException, OAuth2Exception)

**Файлы:**
- `domain/repositories/plant_repository.dart`
- `data/repositories/plant_repository_impl.dart`
- `data/datasources/local/plant_local_datasource.dart`
- `domain/repositories/watering_repository.dart`
- `domain/repositories/photo_repository.dart`
- `domain/repositories/sync_repository.dart`
- `domain/repositories/note_repository.dart`
- `domain/repositories/wintering_repository.dart`
- `domain/repositories/qr_code_repository.dart`
- `domain/repositories/batch_repository.dart`
- `core/network/network_info.dart`
- `core/error/exceptions.dart` (DuplicateIdException, ValidationException, OAuth2Exception)

- flutter analyze проходит без ошибок
- Unit тесты для репозиториев (если есть)
- NetworkInfo работает корректно

----

## ФАЗА И: ИСПРАВЛЕНИЕ ОШИБОК ШАГОВ 1.1-1.7 (0.5-1 дня)

> **Контекст:** Глубокий аудит шагов 1.1-1.7 выявил 7 ошибок (1 критическую, 2 высоких, 3 средних, 1 низкую).
> **Источник:** [LESSONS_LEARNED.md](LESSONS_LEARNED.md) — ошибки 4-8.
> **Цель:** Исправить все ошибки ДО перехода к шагу 1.8 (миграция данных), чтобы избежать потери данных и проблем в будущих шагах.

---

### И.1 Исправление критических ошибок маппинга и архитектуры

**Задачи:**
И.1.1 Исправить опечатку `plannedFertilizationDate: entity.plannedTransplantDate` → `entity.plannedFertilizationDate` в `PlantRepositoryImpl._mapToDto()` (Android + Windows)
И.1.2 Добавить `DuplicateFailure` в `core/error/failures.dart` (Android + Windows)
И.1.3 Добавить `OAuth2Failure` в `core/error/failures.dart` (Android + Windows)
И.1.4 Обновить `ErrorHandler.handleException()` для обработки `DuplicateIdException` и `OAuth2Exception` (Android + Windows)
И.1.5 Проверить flutter analyze — оба проекта

**Проверка:**
- flutter analyze проходит без ошибок (Android + Windows)
- Все 3 файла (`exceptions.dart`, `failures.dart`, `error_handler.dart`) синхронизированы

---

### И.2 Улучшение HiveDatabase

**Задачи:**
И.2.1 Добавить `_isInitialized` флаг в `HiveDatabase` (Android + Windows)
И.2.2 Добавить `_isInitializing` флаг для защиты от race condition (Android + Windows)
И.2.3 Оборачивать `Hive.registerAdapter()` в try-catch на случай повторной регистрации (Android + Windows)
И.2.4 Проверить flutter analyze — оба проекта

**Проверка:**
- `HiveDatabase.initialize()` безопасен при повторном вызове
- flutter analyze проходит без ошибок (Android + Windows)

---

### И.3 Создание недостающих реализаций репозиториев и DataSource

**Задачи:**
И.3.1 Создать `QRCodeLocalDataSource` + `QRCodeRepositoryImpl` (Android + Windows)
И.3.2 Создать `NoteLocalDataSource` + `NoteRepositoryImpl` (Android + Windows)
И.3.3 Создать `WinteringLocalDataSource` + `WinteringRepositoryImpl` (Android + Windows)
И.3.4 Создать `GbifCacheLocalDataSource` (Android + Windows)
И.3.5 Создать `SyncRepositoryImpl` (базовая реализация) (Android + Windows)
И.3.6 Создать `WateringRepositoryImpl` (базовая реализация) (Android + Windows)
И.3.7 Создать `PhotoRepositoryImpl` (базовая реализация) (Android + Windows)
И.3.8 Создать `BatchRepositoryImpl` (базовая реализация) (Android + Windows)
И.3.9 Проверить flutter analyze — оба проекта

**Проверка:**
- flutter analyze проходит без ошибок (Android + Windows)
- Все репозитории из задач 1.7.1-1.7.11 имеют реализации
- Все `LocalDataSource` созданы для соответствующих DTO

---

### И.4 Оптимизация маппинга PlantRepositoryImpl

**Задачи:**
И.4.1 Заменить JSON-маршаллинг на прямое присвоение полей в `_mapToEntity()` (Android + Windows)
И.4.2 Заменить JSON-маршаллинг на прямое присвоение полей в `_mapToDto()` (Android + Windows)
И.4.3 Создать конвертеры для вложенных объектов (`GerminationRecord`, `FloweringRecord`, `Note`) (Android + Windows)
И.4.4 Проверить чек-лист маппинга: попарное соответствие ВСЕХ полей `Plant` ↔ `PlantDto` (Android + Windows)
И.4.5 Проверить flutter analyze — оба проекта

**Проверка:**
- flutter analyze проходит без ошибок (Android + Windows)
- Все поля `Plant` сохраняются при round-trip (`entity → dto → entity`)
- Нет JSON-посредника в маппинге

---

### И.5 Исправление мелких ошибок

**Задачи:**
И.5.1 Оптимизировать `PlantLocalDataSource.getPlantById` — использовать `_plantBox.get(id)` вместо `firstWhere` (Android + Windows)
И.5.2 Исправить формат прогресса в `03-CURRENT_REFACTORING_STEP.md` (целое число вместо дробного)
И.5.3 Проверить flutter analyze — оба проекта

**Проверка:**
- flutter analyze проходит без ошибок (Android + Windows)

---

### И.6 Финальная верификация шагов 1.1-1.7

**Задачи:**
И.6.1 Полный аудит всех файлов шагов 1.1-1.7 по чек-листам из `CHECKLIST.md`
И.6.2 Сверка с планом `02-REFACTORING_PLAN.md` — все задачи 1.1.1-1.7.13 выполнены
И.6.3 Проверка flutter analyze — оба проекта
И.6.4 Обновление `03-CURRENT_REFACTORING_STEP.md` — шаги 1.1-1.7 отмечены как выполненные, И.1-И.6 отмечены как выполненные

**Проверка:**
- Все задачи шагов 1.1-1.7 выполнены полностью (100%)
- flutter analyze без ошибок (Android + Windows)
- Нет частично выполненных задач
- Нет скрытых ошибок

----

### 1.8 Создание Data Migration Manager (1.5 дня)

**Задачи:**
1.8.1 Создать data/migrations/data_migration_manager.dart
1.8.2 Реализовать миграцию SharedPreferences → Hive (все растения, QR-коды, заметки)
1.8.3 Реализовать миграцию с версионированием (currentVersion = 1)
1.8.4 Реализовать автоматический бэкап перед миграцией
1.8.5 Реализовать миграцию поля lastModified (v1)
1.8.6 Добавить миграцию в main.dart при запуске
1.8.7 Протестировать миграцию на реальных данных
1.8.8 Добавить проверку целостности данных после миграции
1.8.9 Реализовать возможность отката миграции

**Файлы:**
- `data/migrations/data_migration_manager.dart`
- `data/migrations/migration_v1_add_last_modified.dart`

**Проверка:**
- Миграция работает без потери данных
- Версионирование работает корректно
- Бэкап создается автоматически
- Откат работает корректно

---

### 1.9 Создание Dependency Injection (1 день)

**Задачи:**
1.9.1 Создать injection_container.dart
1.9.2 Зарегистрировать все репозитории
1.9.3 Зарегистрировать все сервисы
1.9.4 Зарегистрировать провайдеры
1.9.5 Интегрировать в main.dart
1.9.6 Запустить build_runner для генерации DI кода

**Файлы:**
- `injection_container.dart`

**Проверка:**
- build_runner прошел без ошибок
- Приложение запускается с DI
- Все зависимости резолвятся корректно

---

### 1.10 Разделение PlantProvider (3 дня)

**Задачи:**
1.10.1 Создать presentation/providers/plant_provider.dart (только CRUD)
1.10.2 Создать presentation/providers/watering_provider.dart
1.10.3 Создать presentation/providers/wintering_provider.dart
1.10.4 Создать presentation/providers/photo_provider.dart
1.10.5 Создать presentation/providers/batch_provider.dart
1.10.6 Создать presentation/providers/sync_provider.dart
1.10.7 Создать presentation/providers/cache_manager.dart
1.10.8 Перенести логику из старого PlantProvider в новые провайдеры
1.10.9 Обновить все экраны для использования новых провайдеров
1.10.10 Удалить старый PlantProvider

**Файлы:**
- `presentation/providers/plant_provider.dart` (~300 строк)
- `presentation/providers/watering_provider.dart` (~250 строк)
- `presentation/providers/wintering_provider.dart` (~200 строк)
- `presentation/providers/photo_provider.dart` (~300 строк)
- `presentation/providers/batch_provider.dart` (~200 строк)
- `presentation/providers/sync_provider.dart` (~250 строк)
- `presentation/providers/cache_manager.dart` (~150 строк)

**Проверка:**
- flutter analyze проходит без ошибок
- Все функции работают как раньше
- Тестирование на обеих платформах

---

### 1.11 Разделение CloudStorageProvider (2 дня)

**Задачи:**
1.11.1 Создать services/auth/auth_service.dart
1.11.2 Создать services/auth/yandex_auth_service.dart
1.11.3 Создать services/auth/token_storage.dart
1.11.4 Создать services/cloud/cloud_storage_service.dart
1.11.5 Создать services/cloud/yandex_disk_service.dart
1.11.6 Создать services/cloud/cloud_file.dart
1.11.7 Создать services/sync/sync_manager.dart
1.11.8 Создать services/sync/conflict_resolver.dart
1.11.9 Создать services/sync/sync_status.dart
1.11.10 Создать services/platform/deep_link_handler.dart
1.11.11 Создать services/platform/local_server.dart
1.11.12 Создать services/platform/platform_adapter.dart
1.11.13 Перенести логику из старого CloudStorageProvider
1.11.14 Обновить экраны для использования новых сервисов
1.11.15 Удалить старый CloudStorageProvider

**Файлы:**
- `services/auth/auth_service.dart`
- `services/auth/yandex_auth_service.dart`
- `services/auth/token_storage.dart`
- `services/cloud/cloud_storage_service.dart`
- `services/cloud/yandex_disk_service.dart`
- `services/cloud/cloud_file.dart`
- `services/sync/sync_manager.dart`
- `services/sync/conflict_resolver.dart`
- `services/sync/sync_status.dart`
- `services/platform/deep_link_handler.dart`
- `services/platform/local_server.dart`
- `services/platform/platform_adapter.dart`

**Проверка:**
- flutter analyze проходит без ошибок
- OAuth2 работает на обеих платформах
- Синхронизация работает как раньше

---

### 1.12 Разбиение PlantCardScreen (2 дня)

**Задачи:**
1.12.1 Создать presentation/screens/plant_card/plant_card_screen.dart
1.12.2 Создать presentation/screens/plant_card/tabs/overview_tab.dart
1.12.3 Создать presentation/screens/plant_card/tabs/care_tab.dart
1.12.4 Создать presentation/screens/plant_card/tabs/gallery_tab.dart
1.12.5 Создать presentation/screens/plant_card/tabs/history_tab.dart (бывший notes_tab — содержит историю, заметки и статистику)
1.12.6 Создать presentation/screens/plant_card/tabs/distribution_tab.dart (бывший map_tab — содержит карту распространения + GBIF-данные)
1.12.7 Создать presentation/screens/plant_card/tabs/seedlings_tab.dart
1.12.8 Создать виджеты для PlantCardScreen
1.12.9 Перенести логику из старого PlantCardScreen
1.12.10 Обновить навигацию
1.12.11 Удалить старый PlantCardScreen

**Файлы:**
- `presentation/screens/plant_card/plant_card_screen.dart` (~150 строк)
- `presentation/screens/plant_card/tabs/overview_tab.dart` (~250 строк)
- `presentation/screens/plant_card/tabs/care_tab.dart` (~300 строк)
- `presentation/screens/plant_card/tabs/gallery_tab.dart` (~250 строк)
- `presentation/screens/plant_card/tabs/history_tab.dart` (~200 строк)
- `presentation/screens/plant_card/tabs/distribution_tab.dart` (~600 строк)
- `presentation/screens/plant_card/tabs/seedlings_tab.dart` (~200 строк)
- Виджеты в `presentation/screens/plant_card/widgets/`

**Проверка:**
- flutter analyze проходит без ошибок
- Все вкладки работают как раньше
- Тестирование на обеих платформах

---

### 1.13 Создание сервисного слоя для API (1 день)

> **Рекомендуемый порядок:** После 1.13 сразу выполнить **1.15** (DI-интеграция + закрытие TODO), пока контекст шагов 1.8–1.12 свеж. Финальное тестирование (**1.14**) оставить на конец Фазы 1.

**Задачи:**
1.13.1 ✅ Создать services/api/gbif_service.dart
1.13.2 ✅ Создать services/api/llifle_service.dart
1.13.3 ✅ Создать services/api/weather_service.dart
1.13.4 ✅ Перенести логику из utils/gbif_utils.dart
1.13.5 ✅ Перенести логику из utils/llifle_utils.dart
1.13.6 ✅ Перенести логику из utils/weather_service.dart
1.13.7 ✅ Обновить провайдеры для использования сервисов
1.13.8 ✅ Удалить старые utils

**Файлы:**
- `services/api/gbif_service.dart`
- `services/api/llifle_service.dart`
- `services/api/weather_service.dart`
- `models/gbif_occurrence.dart` (вынесен из utils)
- `core/logger/app_logger.dart` (добавлен класс AppLogger)

**Проверка:**
- flutter analyze проходит без ошибок
- Парсинг GBIF работает
- Парсинг Llifle работает
- Погода работает

---

### 1.14 Финальное тестирование Фазы 1 (1 день)

**Задачи:**
1.14.1 ✅ Полное тестирование всех функций (чек-лист из 00-BEFORE_REFACTORING.md)
1.14.2 ✅ Тестирование на Android (сборка app-debug.apk — 46.1s)
1.14.3 ✅ Тестирование на Windows (сборка my_cactus.exe — 18.0s)
1.14.4 ✅ Проверка производительности (O(1) поиск по Hive, индексы)
1.14.5 ✅ flutter analyze — 0 errors, 0 warnings, 0 info (Android + Windows)
1.14.6 ✅ Создание бэкапа — git commit 362a46d

**Проверка:**
- ✅ Все функции работают
- ✅ Производительность улучшилась (Hive + индексы)
- ✅ Нет регрессий

---

### 1.15 Завершение Repository Pattern и DI-интеграция (1-1.5 дня)

> **Рекомендуемое размещение:** Выполнять **сразу после 1.13**, пока контекст шагов 1.8–1.12 свеж. Не откладывать до 1.14.

**Цель:** Закрыть все оставшиеся TODO из пройденных шагов 1.8–1.12, которые не были реализованы.

**Задачи:**
1.15.1 ✅ Подключить PhotoProvider, BatchProvider, SyncProvider к репозиториям через DI
1.15.2 ✅ Реализовать cleanupUnusedPhotosForSelected и deleteAllPhotosForSelected в PhotoProvider
1.15.3 ✅ Реализовать exportSelectedToCSV в PlantCrudProvider или отдельном сервисе
1.15.4 ✅ Интегрировать SyncRepositoryImpl с SyncManager — реализовать syncWithCloud и getSyncStatus
1.15.5 ✅ Реализовать setLlifleAsMainPhoto в PhotoRepositoryImpl
1.15.6 ✅ Перенести кэширование cloud-фото из PlantCrudProvider в PhotoSyncService, убрать FIXME
1.15.7 ✅ Реализовать settings_box в Hive для globalWateringDates
1.15.8 ✅ Расширить QRCodeDto полем filePath — реализовать миграцию путей к PDF файлам
1.15.9 ✅ Реализовать createBatch/updateBatch в BatchRepositoryImpl
1.15.10 ✅ Проверить flutter analyze — оба проекта
1.15.11 ✅ Обновить TODO(1.15.x) в коде — заменить на реализацию
1.15.12 ✅ Оптимизировать `PlantRepositoryImpl._mapToEntity`: добавить `_safeJsonList`

**Файлы:**
- `presentation/providers/photo_provider.dart`
- `presentation/providers/batch_provider.dart`
- `presentation/providers/sync_provider.dart`
- `presentation/providers/plant_crud_provider.dart`
- `data/repositories/plant_repository_impl.dart` (оптимизация 1.15.12)
- `data/repositories/sync_repository_impl.dart`
- `data/repositories/photo_repository_impl.dart`
- `data/repositories/watering_repository_impl.dart`
- `data/repositories/qr_code_repository_impl.dart`
- `data/repositories/batch_repository_impl.dart`
- `data/migrations/data_migration_manager.dart`

**Проверка:**
- flutter analyze проходит без ошибок
- Все TODO(1.15.x) реализованы и удалены из кода
- Нет оставшихся заглушек
- Все TODO в прошлых шагах (1.1–1.14) удалены или перенесены в будущие

---

## ФАЗА 2: ВАЖНЫЕ УЛУЧШЕНИЯ (P1)

### 2.0 Исправления из глубокого аудита (0.5 дня)

> **Выполнять первым в Фазе 2.** Исправляет критические проблемы, выявленные внешним аудитом архитектуры.

**Задачи:**
2.0.1 Исправить Hive race condition — добавить `if (_isInitialized) return` после цикла ожидания в `hive_database.dart`
2.0.2 Добавить `dispose()` во все ChangeNotifier-провайдеры (WateringProvider, WinteringProvider, PhotoProvider, BatchProvider, SyncProvider, QrCodeProvider, WeatherProvider)
2.0.3 Перенести `CloudStorageProvider` из `lib/providers/` в `lib/presentation/providers/`, обновить все импорты
2.0.4 Параллелизовать загрузку провайдеров в `main.dart` через `Future.wait` вместо последовательных `await`
2.0.5 Добавить `_parseDateTimeSafe()` в `Plant.fromJson` с fallback для некорректных дат из облака
2.0.6 Создать `PlantStatusMapper` — вынести маппинг строк статусов в единое место, убрать дублирование

**Файлы:**
- `data/datasources/local/hive_database.dart`
- `presentation/providers/*.dart`
- `providers/cloud_storage_provider.dart`
- `main.dart`
- `models/plant.dart`
- `core/utils/plant_status_mapper.dart`

**Проверка:**
- flutter analyze проходит без ошибок
- Нет новых утечек памяти (dispose вызывается корректно)
- Приложение стартует быстрее (Future.wait)
- Некорректные даты из облака не ломают парсинг
- Статусы растений нормализованы единообразно

---

### 2.1 go_router навигация (2 дня)

**Задачи:**
2.1.1 Добавить go_router в pubspec.yaml
2.1.2 Создать presentation/routers/app_router.dart
2.1.3 Определить все маршруты
2.1.4 Заменить Navigator.push на go_router
2.1.5 Реализовать deep linking
2.1.6 Тестирование навигации

**Файлы:**
- `presentation/routers/app_router.dart`

**Проверка:**
- flutter analyze проходит без ошибок
- Навигация работает
- Deep linking работает

**⚠️ Важно для будущих изменений навигации:**
- При добавлении новых маршрутов — использовать ЧЕК-ЛИСТ go_router (CHECKLIST.md)
- При любом изменении навигации — глобальный grep `Navigator.push` / `context.push` по ВСЕМУ проекту
- Перед завершением шага — сверить ВСЕ маршруты с ВСЕМИ вызовами в коде
- Redirect должен сохранять приоритет deep links над welcome-редиректом

---

### 2.2 UiState pattern (loading/error) (1 день)

**Задачи:**
2.2.1 Создать core/ui/ui_state.dart
2.2.2 Создать core/ui/ui_error.dart
2.2.3 Создать core/ui/ui_loading.dart
2.2.4 Создать core/ui/ui_success.dart
2.2.5 Интегрировать UiState в PlantProvider
2.2.6 Интегрировать UiState в WateringProvider
2.2.7 Обновить UI для отображения loading/error/success состояний
2.2.8 Добавить retry логику

**Файлы:**
- `core/ui/ui_state.dart`

**Проверка:**
- flutter analyze проходит без ошибок
- Loading states отображаются
- Error states отображаются с retry
- Success states отображаются

---

### 2.3 Кэширование изображений (1 день)

**Задачи:**
2.3.1 Добавить flutter_cache_manager в pubspec.yaml
2.3.2 Добавить flutter_image_compress в pubspec.yaml
2.3.3 Создать services/image/photo_cache_manager.dart
2.3.4 Создать services/image/image_processor.dart
2.3.5 Интегрировать в PhotoProvider
2.3.6 Тестирование кэширования
2.3.7 Тестирование сжатия
2.3.8 Настроить maxSizeBytes (500 MB)
2.3.9 Настроить stalePeriod (30 дней)
2.3.10 Добавить prefetch для галереи

**Файлы:**
- `services/image/photo_cache_manager.dart`
- `services/image/image_processor.dart`

**Проверка:**
- flutter analyze проходит без ошибок
- Галерея загружается быстрее
- Память используется меньше

---

### 2.4 Isolates для тяжелых операций (1.5 дня)

**Задачи:**
2.4.1 Создать services/isolates/parser_isolate.dart
2.4.2 Перенести парсинг Llifle в isolate
2.4.3 Перенести парсинг GBIF в isolate
2.4.4 Перенести сериализацию JSON в isolate
2.4.5 Создать _IsolateMessage для коммуникации
2.4.6 Тестирование UI без блокировок
2.4.7 Проверка использования CPU

**Файлы:**
- `services/isolates/parser_isolate.dart`
- `services/isolates/json_serializer_isolate.dart`

**Проверка:**
- UI не блокируется при парсинге
- FPS стабилен при тяжелых операциях
- Память не растет бесконечно

---

### 2.5 Оптимизация дерева виджетов (1 день)

**Задачи:**
2.5.1 Добавить const виджеты где возможно
2.5.2 Добавить RepaintBoundary для PlantCard
2.5.3 Добавить RepaintBoundary для галереи фото
2.5.4 Использовать ValueListenableBuilder вместо полного rebuild
2.5.5 Проверить использование ListView.builder везде
2.5.6 Профилирование с Flutter DevTools
2.5.7 Оптимизация перерисовок

**Проверка:**
- Flutter DevTools показывает меньше перерисовок
- FPS стабилен при скролле
- Память не растет при скролле

---

### 2.6 Очистка deprecated кода (0.5 дня)

> **Почему не freezed:** Hive-модели с `@HiveType` + ручной маппинг уже стабильны после Фазы 1. Переход на freezed требует переделки ~40 файлов (DTO, адаптеры, репозитории) с высоким риском регрессий. Выигрыш минимален.

**Задачи:**
2.6.1 Найти и удалить неиспользуемые импорты (`dart fix --apply`)
2.6.2 Удалить старые utils-файлы, заменённые сервисами из 1.13
2.6.3 Удалить закомментированный код и мёртвые функции
2.6.4 Проверить, что все TODO(1.15.x) удалены из кода
2.6.5 Удалить старый `PlantProvider` если ещё существует
2.6.6 Удалить старый `CloudStorageProvider` если ещё существует

**Файлы:**
- `pubspec.yaml` (убрать неиспользуемые зависимости если есть)
- `utils/gbif_utils.dart` (если ещё есть)
- `utils/llifle_utils.dart` (если ещё есть)
- `utils/weather_service.dart` (если ещё есть)

**Проверка:**
- flutter analyze проходит без ошибок
- Нет неиспользуемых импортов
- Все старые utils удалены или перенесены

---

### 2.7 Строгий линтер (0.5 дня)

**Задачи:**
2.7.1 Создать/обновить analysis_options.yaml
2.7.2 Добавить правила: always_declare_return_types, avoid_print, prefer_single_quotes, sort_constructors_first, require_trailing_commas
2.7.3 Запустить flutter analyze
2.7.4 Исправить все предупреждения линтера

**Файлы:**
- `analysis_options.yaml`

**Проверка:**
- flutter analyze проходит без предупреждений
- Код соответствует стандартам

---

### 2.8 Финальное тестирование Фазы 2 (1 день)

**Задачи:**
2.8.1 Полное тестирование всех функций
2.8.2 Тестирование на обеих платформах
2.8.3 Проверка производительности (FPS, память, CPU)
2.8.4 flutter analyze (оба проекта)
2.8.5 Проверка работы isolates
2.8.6 Проверка кэширования изображений

**Проверка:**
- Все функции работают
- Производительность улучшилась
- Навигация работает

---

### 2.9 Надёжность синхронизации (1 день)

> **Выполнять после оптимизаций UI.** Добавляет защиту от гонок данных, спама запросами и повреждённых данных из облака.

**Задачи:**
2.9.1 Добавить `Lock` (synchronized) для критических секций синхронизации — предотвратить изменение данных пользователем во время sync
2.9.2 Добавить лимит повторных попыток синхронизации (`maxSyncRetries = 3`) с exponential backoff при ошибках сети
2.9.3 Добавить валидацию входящих данных из облака:
  - Проверка структуры (`data.containsKey('plants')`)
  - Лимит количества растений (макс 10000)
  - `_validatePlantJson()` с проверкой обязательных полей (`permanentId`, `latinName`, год в диапазоне 1900-2100)
2.9.4 Не перезаписывать локальные данные пустым списком при ошибке загрузки из облака
2.9.5 Добавить индикатор прогресса синхронизации с возможностью отмены

**Файлы:**
- `presentation/providers/cloud_storage_provider.dart`
- `services/sync/sync_manager.dart`
- `models/plant.dart`

**Проверка:**
- Нет бесконечных циклов при ошибках сети (max 3 retries)
- Повреждённые данные из облака не ломают приложение (валидация)
- Пользовательские изменения во время синхронизации не теряются (Lock)
- flutter analyze проходит без ошибок

---

## ФАЗА 3: ЖЕЛАТЕЛЬНЫЕ УЛУЧШЕНИЯ (P2)

### 3.1 Тестирование (3 дня)

**Задачи:**
3.1.1 Добавить mockito и mocktail в pubspec.yaml
3.1.2 Создать структуру test/
3.1.3 Написать unit тесты для репозиториев
3.1.4 Написать unit тесты для сервисов
3.1.5 Написать widget тесты для основных экранов
3.1.6 Написать integration тесты для критических потоков

> **CI/CD:** Автоматический запуск тестов настраивается в шаге 3.3 (CI/CD пайплайн).

**Файлы:**
- `test/unit/repositories/plant_repository_test.dart`
- `test/unit/services/gbif_service_test.dart`
- `test/widget/screens/home_screen_test.dart`
- `test/integration/sync_flow_test.dart`

**Проверка:**
- Test coverage >80%
- Все тесты проходят локально (`flutter test`)

---

### 3.2 Accessibility (1 день)

**Задачи:**
3.2.1 Добавить Semantics виджеты в PlantCard
3.2.2 Добавить Semantics в другие экраны
3.2.3 Проверить контрастность цветов
3.2.4 Тестирование с TalkBack/VoiceOver

**Проверка:**
- Скринридеры работают
- Контрастность соответствует WCAG

---

### 3.3 CI/CD пайплайн (2 дня)

**Задачи:**
3.3.1 Создать .github/workflows/ci.yml
3.3.2 Настроить автоматический flutter analyze
3.3.3 Настроить автоматический flutter test --coverage
3.3.4 Настроить сборку APK для Android
3.3.5 Настроить сборку App Bundle для Android
3.3.6 Настроить сборку MSIX для Windows
3.3.7 Настроить автоматическую публикацию артефактов
3.3.8 Настроить Codecov для coverage reports
3.3.9 Настроить ветки main, develop
3.3.10 Тестирование пайплайна

**Файлы:**
- `.github/workflows/ci.yml`
- `.github/workflows/android-build.yml`
- `.github/workflows/windows-build.yml`

**Проверка:**
- CI/CD работает
- Артефакты собираются автоматически
- Coverage reports публикуются

---

### 3.4 Crash Reporting (1 день)

**Задачи:**
3.4.1 Добавить firebase_crashlytics в pubspec.yaml
3.4.2 Добавить firebase_analytics в pubspec.yaml
3.4.3 Настроить Firebase проект
3.4.4 Интегрировать Crashlytics в AppLogger
3.4.5 Интегрировать Analytics для key events
3.4.6 Тестирование crash reporting
3.4.7 Настроить release builds

**Файлы:**
- `pubspec.yaml` (добавить зависимости)
- `core/logger/app_logger.dart` (добавить Crashlytics)

**Проверка:**
- Crashlytics собирает краши
- Analytics собирает события
- Release builds работают

---

### 3.5 Документация API (2 дня)

**Задачи:**
3.5.1 Добавить dartdoc комментарии ко всем публичным методам
3.5.2 Создать архитектурные диаграммы (Mermaid)
3.5.3 Сгенерировать HTML документацию через dartdoc
3.5.4 Создать README для новых разработчиков
3.5.5 Создать docs/architecture.md
3.5.6 Создать docs/data_flow.md
3.5.7 Создать docs/api_reference.html
3.5.8 Создать docs/contributing.md

**Файлы:**
- `docs/architecture.md`
- `docs/data_flow.md`
- `docs/api_reference.html`
- `docs/contributing.md`
- `README.md`

**Проверка:**
- Документация генерируется
- Диаграммы корректны
- README понятен новым разработчикам

---

### 3.6 Финальное тестирование Фазы 3 (1 день)

**Задачи:**
3.6.1 Полное тестирование всех функций
3.6.2 Тестирование на обеих платформах
3.6.3 Проверка производительности
3.6.4 flutter analyze (оба проекта)
3.6.5 Запуск всех тестов
3.6.6 Проверка CI/CD пайплайна
3.6.7 Проверка Crash Reporting

**Проверка:**
- Все функции работают
- Все тесты проходят
- Производительность соответствует целям

---

## ФАЗА 4: БУДУЩЕЕ (P3)

### 4.1 Feature flags (1.5 дня)

**Задачи:**
4.1.1 Создать core/config/feature_flags.dart
4.1.2 Добавить флаги: enableGbifParsing, enableWeatherAdvice, enableBatchManagement, enableNewWateringAlgorithm, enableAdvancedStatistics
4.1.3 Добавить загрузку конфигурации с сервера/файла
4.1.4 Интегрировать в критические функции (GBIF, погода, batch management)
4.1.5 Добавить overrideForTesting для тестирования
4.1.6 Создать UI для управления feature flags (для разработчиков)
4.1.7 Тестирование feature flags

**Файлы:**
- `core/config/feature_flags.dart`
- `presentation/screens/developer/feature_flags_screen.dart`

**Проверка:**
- Feature flags работают корректно
- Отключение фичи не ломает приложение
- Тестирование с overrideForTesting работает

---

### 4.2 Система прав доступа (2 дня)

**Задачи:**
4.2.1 Создать domain/entities/user_permission.dart
4.2.2 Создать domain/entities/user_role.dart (owner, editor, viewer)

**Файлы:**
- `domain/entities/user_permission.dart`
- `domain/repositories/user_repository.dart`
- `presentation/screens/settings/permissions_screen.dart`

**Проверка:**
- Права доступа работают корректно
- Viewer не может редактировать
- Editor может редактировать только уход
- Owner имеет полный доступ

---

### 4.3 Финальная проверка перед разблокировкой ROADMAP (1-2 дня)

**Цель:** Полная проверка работоспособности приложения перед разблокировкой доступа к ROADMAP для дальнейшего улучшения приложения.

**КРИТИЧЕСКОЕ ТРЕБОВАНИЕ:**
ТОЛЬКО если приложение работает идеально - разблокировать доступ к ROADMAP. Если есть проблемы - сначала исправить их, затем разблокировать.

**Задачи:**
4.3.1 Проверить полную работоспособность приложения на Android
4.3.2 Проверить полную работоспособность приложения на Windows
4.3.3 Проверить приложение на возможные баги
4.3.4 Проверить необходимость полировки UI/UX
4.3.5 Убедиться, что все функции из 00-BEFORE_REFACTORING.md работают
4.3.6 Убедиться, что все новые улучшения работают
4.3.7 Проверить flutter analyze на обоих проектах
4.3.8 Провести полное тестирование всех функций
4.3.9 Проверить синхронизацию между Android и Windows
4.3.10 Проверить миграцию данных (если применимо)
4.3.11 Проверить производительность приложения
4.3.12 Убедиться, что нет незавершенных заглушек и TODO

**Проверка работоспособности:**
- [ ] Все функции из чек-листа 00-BEFORE_REFACTORING.md работают
- [ ] Галерея загружается быстро (кэширование)
- [ ] Синхронизация с Яндекс Диск работает
- [ ] QR-коды сканируются и создаются
- [ ] Полив отмечается корректно
- [ ] Зимовка работает
- [ ] Фильтры и поиск работают
- [ ] Пакетные операции работают
- [ ] go_router навигация работает
- [ ] UiState pattern работает во всех экранах
- [ ] Логирование работает
- [ ] Accessibility работает (скринридеры, контрастность)
- [ ] CI/CD работает
- [ ] Crash Reporting работает (Crashlytics)
- [ ] Миграция данных работает без потери данных
- [ ] flutter analyze проходит без ошибок (оба проекта)
- [ ] Приложение запускается без ошибок (оба проекта)
- [ ] Приложение работает стабильно (нет вылетов)

**Критерии завершения:**
- ВСЕ проверки пройдены успешно
- Приложение работает идеально на обеих платформах
- flutter analyze проходит без ошибок на обоих проектах
- Нет багов и проблем
- Нет незавершенных заглушек и TODO

**Действие после завершения:**
Если ВСЕ проверки пройдены - разблокировать доступ к ROADMAP для дальнейшего улучшения приложения.
Если есть проблемы - сначала исправить их, затем повторить проверку.

---

# АДАПТАЦИЯ ROADMAP ПОСЛЕ РЕФАКТОРИНГА

## Шаг 5.1: Адаптация ROADMAP к изменениям (1-2 дня)

**Цель:** Адаптировать ROADMAP к изменениям, которые произошли после рефакторинга, и внести необходимые изменения в ROADMAP.

**Задачи:**
5.1.1 Проверить, какие изменения произошли после рефакторинга
5.1.2 Проанализировать влияние изменений на ROADMAP
5.1.3 Адаптировать ROADMAP к новым изменениям в архитектуре
5.1.4 Обновить ROADMAP если это необходимо
5.1.5 Внести необходимые изменения в ROADMAP
5.1.6 Убедиться, что ROADMAP соответствует текущему состоянию проекта
5.1.7 Обновить приоритеты задач в ROADMAP
5.1.8 Обновить оценки времени в ROADMAP

**Проверка:**
- ROADMAP соответствует текущему состоянию проекта
- Все изменения после рефакторинга учтены в ROADMAP
- Приоритеты актуальны
- Оценки времени актуальны

---

## P1 - Важные
- Исправления из глубокого аудита (2.0)
- go_router навигация
- UiState pattern
- Кэширование изображений
- Isolates для тяжелых операций
- Оптимизация дерева виджетов
- Очистка deprecated кода
- Строгий линтер
- Надёжность синхронизации (2.9)

## P2 - Желательные
- Тестирование (unit/widget/integration)
- Accessibility
- CI/CD пайплайн
- Crash Reporting (Firebase Crashlytics)
- Документация API

## P3 - Будущее
- Feature flags
- Система прав доступа

---

# СТРАТЕГИЯ ВЫПОЛНЕНИЯ

## Порядок выполнения
1. Фаза 1 полностью (критические улучшения)
2. Фаза 2 полностью (важные улучшения)
3. Фаза 3 полностью (желательные улучшения)
4. Фаза 4 по необходимости (будущее)

## Правила
- Каждый шаг должен быть протестирован
- flutter analyze должен проходить после каждого шага
- Сохранять бэкапы перед критическими изменениями
- Не переходить к следующему шагу пока текущий не завершен

## Откат
- Git коммит после каждого завершенного шага
- Возможность отката к любому шагу
- Сохранение ветки для каждого шага (опционально)

---

# ОЦЕНКА ВРЕМЕНИ

| Фаза | Оценка | Приоритет |
|------|--------|----------|
| Фаза 1: Критические | 4-5 недель | 🔴 P0 |
| Фаза 2: Важные | 2-2.5 недели | 🟡 P1 |
| Фаза 3: Желательные | 2-2.5 недели | 🟢 P2 |
| Фаза 4: Будущее | 3.5 дня | 🔵 P3 |
| **Итого** | **8.5-10.5 недель** | |

---

# ЧЕК-ЛИСТ ЗАВЕРШЕНИЯ

После завершения рефакторинга проверить:

**Архитектура:**
- [ ] PlantProvider разделен на 7 файлов
- [ ] CloudStorageProvider разделен на сервисы
- [ ] PlantCardScreen разбит на компоненты
- [ ] Repository Pattern реализован (все репозитории)
- [ ] Dependency Injection работает (get_it)
- [ ] Hive заменяет SharedPreferences
- [ ] Clean Architecture соблюдена (3 слоя)
- [ ] SOLID принципы соблюдены

**Функциональность:**
- [ ] Все функции из 00-BEFORE_REFACTORING.md работают
- [ ] Синхронизация работает на обеих платформах
- [ ] OAuth2 работает на обеих платформах
- [ ] QR-коды работают
- [ ] Парсинг GBIF работает
- [ ] Парсинг Llifle работает
- [ ] Погода работает
- [ ] Уведомления работают
- [ ] Зимовка работает
- [ ] Система партий работает
- [ ] Заметки работают
- [ ] Карта работает

**Производительность:**
- [ ] Загрузка 1000 растений < 0.5 сек
- [ ] Фильтрация < 50ms
- [ ] Память < 150 MB
- [ ] UI FPS стабильные 60
- [ ] Галерея загружается быстро (кэширование)
- [ ] UI не блокируется при тяжелых операциях (isolates)
- [ ] Память не растет при скролле (оптимизация виджетов)

**Надежность:**
- [ ] Test coverage >80%
- [ ] flutter analyze без ошибок
- [ ] flutter analyze без предупреждений (строгий линтер)
- [ ] Все тесты проходят
- [ ] CI/CD работает
- [ ] Crash Reporting работает (Crashlytics)
- [ ] Миграция данных работает без потери данных
- [ ] Бэкапы создаются автоматически

**Навигация и UX:**
- [ ] go_router внедрен
- [ ] Deep links работают
- [ ] UiState pattern работает во всех экранах
- [ ] Loading states отображаются
- [ ] Error states отображаются с retry
- [ ] Accessibility работает (скринридеры, контрастность)

**Документация:**
- [ ] Код задокументирован (dartdoc комментарии)
- [ ] Архитектурные диаграммы созданы (Mermaid)
- [ ] README для новых разработчиков
- [ ] docs/architecture.md создан
- [ ] docs/data_flow.md создан
- [ ] docs/api_reference.html сгенерирован
- [ ] docs/contributing.md создан

**Инфраструктура:**
- [ ] Code Generation работает (build_runner)
- [ ] Feature flags работают
- [ ] Система прав доступа работает (если реализована)

---

**Этот план будет обновляться по мере выполнения рефакторинга.**
