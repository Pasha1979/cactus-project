# План слияния 1.2: Android + Windows → единый проект

Дата: 2026-11-17. Статус: **подготовка** — документ-план, код не тронут.
Источники данных: FEATURE_REGISTRY.md (sha1-сравнение), PLATFORM_DIFF_REGISTRY.md, решения R-001…R-034.

## 1. Общая структура единого проекта

```
cactus-project/
├── lib/                    ← общая бизнес-логика
│   ├── core/               ← из core/ обеих копий
│   ├── data/               ← из data/ обеих копий
│   ├── domain/             ← из domain/ обеих копий
│   ├── presentation/       ← из presentation/ обеих копий
│   ├── services/           ← из services/ обеих копий
│   ├── platform/           ← НОВЫЙ: платформенные переходники
│   └── main.dart           ← общий entry point
├── android/                ← из Android/android/
├── windows/                ← из Windows/windows/
├── assets/                 ← объединение обеих копий
├── env.json                ← локально, не коммитится
├── env.example.json        ← уже есть
├── pubspec.yaml            ← объединение зависимостей
└── docs/                   ← уже есть
```

## 2. Реестр миграции файлов (механически, sha1)

Контрольные цифры: **133 уникальных пути** = 111 IDENTICAL + 19 DIFFERENT + 2 ANDROID_ONLY + 1 WINDOWS_ONLY.

| # | Путь в Android | Путь в Windows | Статус | Куда переносим | Решение | Подтверждение |
|---|---|---|---|---|---|---|
| 1 | `Android/lib/core/config/api_config.dart` | `Windows/lib/core/config/api_config.dart` | ANDROID_ONLY | `lib/core/config/api_config.dart` | R-014 (QR Android-only) |  |
| 2 | `Android/lib/core/config/app_constants.dart` | `Windows/lib/core/config/app_constants.dart` | DIFFERENT | `lib/core/config/app_constants.dart` | Android: appVersion 1.0.1 · Windows: 1.0.0. По R-019: единая версия 1.2.0. |  |
| 3 | `Android/lib/core/config/feature_flags.dart` | `Windows/lib/core/config/feature_flags.dart` | DIFFERENT | `lib/core/config/feature_flags.dart` | Android: +44 строки флагов (расширенный набор). Windows: меньше флагов. По R-008/R-027: объединить в общий набор флагов (firebase-флаги — локальные, без Firebase). |  |
| 4 | `Android/lib/core/config/route_config.dart` | `Windows/lib/core/config/route_config.dart` | ANDROID_ONLY | `lib/core/config/route_config.dart` | R-014 (QR Android-only) |  |
| 5 | `Android/lib/core/config/theme_config.dart` | `Windows/lib/core/config/theme_config.dart` | ANDROID_ONLY | `lib/core/config/theme_config.dart` | R-014 (QR Android-only) |  |
| 6 | `Android/lib/core/error/error_boundary.dart` | `Windows/lib/core/error/error_boundary.dart` | ANDROID_ONLY | `lib/core/error/error_boundary.dart` | R-014 (QR Android-only) |  |
| 7 | `Android/lib/core/error/error_handler.dart` | `Windows/lib/core/error/error_handler.dart` | ANDROID_ONLY | `lib/core/error/error_handler.dart` | R-014 (QR Android-only) |  |
| 8 | `Android/lib/core/error/exceptions.dart` | `Windows/lib/core/error/exceptions.dart` | ANDROID_ONLY | `lib/core/error/exceptions.dart` | R-014 (QR Android-only) |  |
| 9 | `Android/lib/core/error/failures.dart` | `Windows/lib/core/error/failures.dart` | ANDROID_ONLY | `lib/core/error/failures.dart` | R-014 (QR Android-only) |  |
| 10 | `Android/lib/core/logger/app_logger.dart` | `Windows/lib/core/logger/app_logger.dart` | DIFFERENT | `lib/core/logger/app_logger.dart` | Различия в платформенной части логирования (~59 строк, 30/29). Ждёт решения владельца — сверить осознанность. |  |
| 11 | `Android/lib/core/logger/logger_service.dart` | `Windows/lib/core/logger/logger_service.dart` | ANDROID_ONLY | `lib/core/logger/logger_service.dart` | R-014 (QR Android-only) |  |
| 12 | `Android/lib/core/network/network_info.dart` | `Windows/lib/core/network/network_info.dart` | ANDROID_ONLY | `lib/core/network/network_info.dart` | R-014 (QR Android-only) |  |
| 13 | `Android/lib/core/ui/ui_state.dart` | `Windows/lib/core/ui/ui_state.dart` | ANDROID_ONLY | `lib/core/ui/ui_state.dart` | R-014 (QR Android-only) |  |
| 14 | `Android/lib/core/ui/ui_state_builder.dart` | `Windows/lib/core/ui/ui_state_builder.dart` | ANDROID_ONLY | `lib/core/ui/ui_state_builder.dart` | R-014 (QR Android-only) |  |
| 15 | `Android/lib/core/utils/date_formatter.dart` | `Windows/lib/core/utils/date_formatter.dart` | ANDROID_ONLY | `lib/core/utils/date_formatter.dart` | R-014 (QR Android-only) |  |
| 16 | `Android/lib/core/utils/plant_status_mapper.dart` | `Windows/lib/core/utils/plant_status_mapper.dart` | ANDROID_ONLY | `lib/core/utils/plant_status_mapper.dart` | R-014 (QR Android-only) |  |
| 17 | `Android/lib/core/utils/responsive_helper.dart` | `Windows/lib/core/utils/responsive_helper.dart` | DIFFERENT | `lib/core/utils/responsive_helper.dart` | adultImageGridCount: Android 2/3 колонки · Windows 3/5. По R-011/012: осознанное различие UI → Platform check; подтверждение владельца. |  |
| 18 | `Android/lib/core/utils/translation_utils.dart` | `Windows/lib/core/utils/translation_utils.dart` | ANDROID_ONLY | `lib/core/utils/translation_utils.dart` | R-014 (QR Android-only) |  |
| 19 | `Android/lib/core/utils/validators.dart` | `Windows/lib/core/utils/validators.dart` | ANDROID_ONLY | `lib/core/utils/validators.dart` | R-014 (QR Android-only) |  |
| 20 | `Android/lib/data/datasources/local/gbif_cache_local_datasource.dart` | `Windows/lib/data/datasources/local/gbif_cache_local_datasource.dart` | ANDROID_ONLY | `lib/data/datasources/local/gbif_cache_local_datasource.dart` | R-014 (QR Android-only) |  |
| 21 | `Android/lib/data/datasources/local/hive_database.dart` | `Windows/lib/data/datasources/local/hive_database.dart` | ANDROID_ONLY | `lib/data/datasources/local/hive_database.dart` | R-014 (QR Android-only) |  |
| 22 | `Android/lib/data/datasources/local/note_local_datasource.dart` | `Windows/lib/data/datasources/local/note_local_datasource.dart` | ANDROID_ONLY | `lib/data/datasources/local/note_local_datasource.dart` | R-014 (QR Android-only) |  |
| 23 | `Android/lib/data/datasources/local/plant_index_manager.dart` | `Windows/lib/data/datasources/local/plant_index_manager.dart` | ANDROID_ONLY | `lib/data/datasources/local/plant_index_manager.dart` | R-014 (QR Android-only) |  |
| 24 | `Android/lib/data/datasources/local/plant_local_datasource.dart` | `Windows/lib/data/datasources/local/plant_local_datasource.dart` | DIFFERENT | `lib/data/datasources/local/plant_local_datasource.dart` | Android: +30 строк логики. Windows: урезанная версия. Ждёт решения владельца — сверка построчно. |  |
| 25 | `Android/lib/data/datasources/local/qr_code_local_datasource.dart` | `Windows/lib/data/datasources/local/qr_code_local_datasource.dart` | ANDROID_ONLY | `lib/data/datasources/local/qr_code_local_datasource.dart` | R-014 (QR Android-only) |  |
| 26 | `Android/lib/data/datasources/local/wintering_local_datasource.dart` | `Windows/lib/data/datasources/local/wintering_local_datasource.dart` | ANDROID_ONLY | `lib/data/datasources/local/wintering_local_datasource.dart` | R-014 (QR Android-only) |  |
| 27 | `Android/lib/data/migrations/data_migration_manager.dart` | `Windows/lib/data/migrations/data_migration_manager.dart` | ANDROID_ONLY | `lib/data/migrations/data_migration_manager.dart` | R-014 (QR Android-only) |  |
| 28 | `Android/lib/data/models/gbif_occurrence_dto.dart` | `Windows/lib/data/models/gbif_occurrence_dto.dart` | ANDROID_ONLY | `lib/data/models/gbif_occurrence_dto.dart` | R-014 (QR Android-only) |  |
| 29 | `Android/lib/data/models/gbif_occurrence_dto.g.dart` | `Windows/lib/data/models/gbif_occurrence_dto.g.dart` | ANDROID_ONLY | `lib/data/models/gbif_occurrence_dto.g.dart` | R-014 (QR Android-only) |  |
| 30 | `Android/lib/data/models/note_dto.dart` | `Windows/lib/data/models/note_dto.dart` | ANDROID_ONLY | `lib/data/models/note_dto.dart` | R-014 (QR Android-only) |  |
| 31 | `Android/lib/data/models/note_dto.g.dart` | `Windows/lib/data/models/note_dto.g.dart` | ANDROID_ONLY | `lib/data/models/note_dto.g.dart` | R-014 (QR Android-only) |  |
| 32 | `Android/lib/data/models/plant_dto.dart` | `Windows/lib/data/models/plant_dto.dart` | ANDROID_ONLY | `lib/data/models/plant_dto.dart` | R-014 (QR Android-only) |  |
| 33 | `Android/lib/data/models/plant_dto.g.dart` | `Windows/lib/data/models/plant_dto.g.dart` | ANDROID_ONLY | `lib/data/models/plant_dto.g.dart` | R-014 (QR Android-only) |  |
| 34 | `Android/lib/data/models/qr_code_dto.dart` | `Windows/lib/data/models/qr_code_dto.dart` | ANDROID_ONLY | `lib/data/models/qr_code_dto.dart` | R-014 (QR Android-only) |  |
| 35 | `Android/lib/data/models/qr_code_dto.g.dart` | `Windows/lib/data/models/qr_code_dto.g.dart` | ANDROID_ONLY | `lib/data/models/qr_code_dto.g.dart` | R-014 (QR Android-only) |  |
| 36 | `Android/lib/data/models/wintering_log_entry_dto.dart` | `Windows/lib/data/models/wintering_log_entry_dto.dart` | ANDROID_ONLY | `lib/data/models/wintering_log_entry_dto.dart` | R-014 (QR Android-only) |  |
| 37 | `Android/lib/data/models/wintering_log_entry_dto.g.dart` | `Windows/lib/data/models/wintering_log_entry_dto.g.dart` | ANDROID_ONLY | `lib/data/models/wintering_log_entry_dto.g.dart` | R-014 (QR Android-only) |  |
| 38 | `Android/lib/data/repositories/batch_repository_impl.dart` | `Windows/lib/data/repositories/batch_repository_impl.dart` | ANDROID_ONLY | `lib/data/repositories/batch_repository_impl.dart` | R-014 (QR Android-only) |  |
| 39 | `Android/lib/data/repositories/note_repository_impl.dart` | `Windows/lib/data/repositories/note_repository_impl.dart` | ANDROID_ONLY | `lib/data/repositories/note_repository_impl.dart` | R-014 (QR Android-only) |  |
| 40 | `Android/lib/data/repositories/photo_repository_impl.dart` | `Windows/lib/data/repositories/photo_repository_impl.dart` | ANDROID_ONLY | `lib/data/repositories/photo_repository_impl.dart` | R-014 (QR Android-only) |  |
| 41 | `Android/lib/data/repositories/plant_repository_impl.dart` | `Windows/lib/data/repositories/plant_repository_impl.dart` | ANDROID_ONLY | `lib/data/repositories/plant_repository_impl.dart` | R-014 (QR Android-only) |  |
| 42 | `Android/lib/data/repositories/qr_code_repository_impl.dart` | `Windows/lib/data/repositories/qr_code_repository_impl.dart` | ANDROID_ONLY | `lib/data/repositories/qr_code_repository_impl.dart` | R-014 (QR Android-only) |  |
| 43 | `Android/lib/data/repositories/sync_repository_impl.dart` | `Windows/lib/data/repositories/sync_repository_impl.dart` | ANDROID_ONLY | `lib/data/repositories/sync_repository_impl.dart` | R-014 (QR Android-only) |  |
| 44 | `Android/lib/data/repositories/watering_repository_impl.dart` | `Windows/lib/data/repositories/watering_repository_impl.dart` | ANDROID_ONLY | `lib/data/repositories/watering_repository_impl.dart` | R-014 (QR Android-only) |  |
| 45 | `Android/lib/data/repositories/wintering_repository_impl.dart` | `Windows/lib/data/repositories/wintering_repository_impl.dart` | ANDROID_ONLY | `lib/data/repositories/wintering_repository_impl.dart` | R-014 (QR Android-only) |  |
| 46 | `Android/lib/domain/repositories/batch_repository.dart` | `Windows/lib/domain/repositories/batch_repository.dart` | ANDROID_ONLY | `lib/domain/repositories/batch_repository.dart` | R-014 (QR Android-only) |  |
| 47 | `Android/lib/domain/repositories/note_repository.dart` | `Windows/lib/domain/repositories/note_repository.dart` | ANDROID_ONLY | `lib/domain/repositories/note_repository.dart` | R-014 (QR Android-only) |  |
| 48 | `Android/lib/domain/repositories/photo_repository.dart` | `Windows/lib/domain/repositories/photo_repository.dart` | ANDROID_ONLY | `lib/domain/repositories/photo_repository.dart` | R-014 (QR Android-only) |  |
| 49 | `Android/lib/domain/repositories/plant_repository.dart` | `Windows/lib/domain/repositories/plant_repository.dart` | ANDROID_ONLY | `lib/domain/repositories/plant_repository.dart` | R-014 (QR Android-only) |  |
| 50 | `Android/lib/domain/repositories/qr_code_repository.dart` | `Windows/lib/domain/repositories/qr_code_repository.dart` | ANDROID_ONLY | `lib/domain/repositories/qr_code_repository.dart` | R-014 (QR Android-only) |  |
| 51 | `Android/lib/domain/repositories/sync_repository.dart` | `Windows/lib/domain/repositories/sync_repository.dart` | ANDROID_ONLY | `lib/domain/repositories/sync_repository.dart` | R-014 (QR Android-only) |  |
| 52 | `Android/lib/domain/repositories/watering_repository.dart` | `Windows/lib/domain/repositories/watering_repository.dart` | ANDROID_ONLY | `lib/domain/repositories/watering_repository.dart` | R-014 (QR Android-only) |  |
| 53 | `Android/lib/domain/repositories/wintering_repository.dart` | `Windows/lib/domain/repositories/wintering_repository.dart` | ANDROID_ONLY | `lib/domain/repositories/wintering_repository.dart` | R-014 (QR Android-only) |  |
| 54 | — | `Windows/lib/firebase_options.dart` | WINDOWS_ONLY | `lib/firebase_options.dart` | R-027: в архив, Firebase удаляется |  |
| 55 | `Android/lib/injection_container.dart` | `Windows/lib/injection_container.dart` | ANDROID_ONLY | `lib/injection_container.dart` | R-014 (QR Android-only) |  |
| 56 | `Android/lib/main.dart` | `Windows/lib/main.dart` | DIFFERENT | `lib/main.dart` | Android: +765 строк (deep links, QR-инициализация, платформенный UI). По R-011/012/013/020: объединить с Platform.isAndroid/isWindows переходниками; UI обеих платформ заморожен. |  |
| 57 | `Android/lib/models/gbif_occurrence.dart` | `Windows/lib/models/gbif_occurrence.dart` | ANDROID_ONLY | `lib/models/gbif_occurrence.dart` | R-014 (QR Android-only) |  |
| 58 | `Android/lib/models/plant.dart` | `Windows/lib/models/plant.dart` | ANDROID_ONLY | `lib/models/plant.dart` | R-014 (QR Android-only) |  |
| 59 | `Android/lib/models/qr_code.dart` | `Windows/lib/models/qr_code.dart` | ANDROID_ONLY | `lib/models/qr_code.dart` | R-014 (QR Android-only) |  |
| 60 | `Android/lib/models/qr_code_file.dart` | `Windows/lib/models/qr_code_file.dart` | ANDROID_ONLY | `lib/models/qr_code_file.dart` | R-014 (QR Android-only) |  |
| 61 | `Android/lib/presentation/providers/batch_provider.dart` | `Windows/lib/presentation/providers/batch_provider.dart` | ANDROID_ONLY | `lib/presentation/providers/batch_provider.dart` | R-014 (QR Android-only) |  |
| 62 | `Android/lib/presentation/providers/cloud_storage_provider.dart` | `Windows/lib/presentation/providers/cloud_storage_provider.dart` | ANDROID_ONLY | `lib/presentation/providers/cloud_storage_provider.dart` | R-014 (QR Android-only) |  |
| 63 | `Android/lib/presentation/providers/photo_provider.dart` | `Windows/lib/presentation/providers/photo_provider.dart` | DIFFERENT | `lib/presentation/providers/photo_provider.dart` | Windows: +14 строк (_validateCloudUrl — валидация cloud URL). Android: без валидации. Фото-синк критичен — ждёт решения владельца. |  |
| 64 | `Android/lib/presentation/providers/plant_crud_provider.dart` | `Windows/lib/presentation/providers/plant_crud_provider.dart` | DIFFERENT | `lib/presentation/providers/plant_crud_provider.dart` | Android: +113 строк. Ждёт решения владельца — сверка построчно. |  |
| 65 | `Android/lib/presentation/providers/providers.dart` | `Windows/lib/presentation/providers/providers.dart` | ANDROID_ONLY | `lib/presentation/providers/providers.dart` | R-014 (QR Android-only) |  |
| 66 | `Android/lib/presentation/providers/qr_code_provider.dart` | `Windows/lib/presentation/providers/qr_code_provider.dart` | ANDROID_ONLY | `lib/presentation/providers/qr_code_provider.dart` | R-014 (QR Android-only) |  |
| 67 | `Android/lib/presentation/providers/settings_provider.dart` | `Windows/lib/presentation/providers/settings_provider.dart` | ANDROID_ONLY | `lib/presentation/providers/settings_provider.dart` | R-014 (QR Android-only) |  |
| 68 | `Android/lib/presentation/providers/sync_provider.dart` | `Windows/lib/presentation/providers/sync_provider.dart` | ANDROID_ONLY | `lib/presentation/providers/sync_provider.dart` | R-014 (QR Android-only) |  |
| 69 | `Android/lib/presentation/providers/watering_provider.dart` | `Windows/lib/presentation/providers/watering_provider.dart` | ANDROID_ONLY | `lib/presentation/providers/watering_provider.dart` | R-014 (QR Android-only) |  |
| 70 | `Android/lib/presentation/providers/weather_provider.dart` | `Windows/lib/presentation/providers/weather_provider.dart` | ANDROID_ONLY | `lib/presentation/providers/weather_provider.dart` | R-014 (QR Android-only) |  |
| 71 | `Android/lib/presentation/providers/wintering_provider.dart` | `Windows/lib/presentation/providers/wintering_provider.dart` | ANDROID_ONLY | `lib/presentation/providers/wintering_provider.dart` | R-014 (QR Android-only) |  |
| 72 | `Android/lib/presentation/routers/app_router.dart` | `Windows/lib/presentation/routers/app_router.dart` | DIFFERENT | `lib/presentation/routers/app_router.dart` | Android: маршрут /qr/scan (QRScannerScreen). По R-014: оставить маршрут, экран обернуть Platform.isAndroid. |  |
| 73 | `Android/lib/presentation/screens/plant_card/plant_card_screen.dart` | `Windows/lib/presentation/screens/plant_card/plant_card_screen.dart` | DIFFERENT | `lib/presentation/screens/plant_card/plant_card_screen.dart` | Android: +83 строки. Ждёт решения владельца — сверка построчно. |  |
| 74 | `Android/lib/presentation/screens/plant_card/tabs/care_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/care_tab.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/tabs/care_tab.dart` | R-014 (QR Android-only) |  |
| 75 | `Android/lib/presentation/screens/plant_card/tabs/distribution_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/distribution_tab.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/tabs/distribution_tab.dart` | R-014 (QR Android-only) |  |
| 76 | `Android/lib/presentation/screens/plant_card/tabs/gallery_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/gallery_tab.dart` | DIFFERENT | `lib/presentation/screens/plant_card/tabs/gallery_tab.dart` | 285 изменённых строк (141/144) — различия в работе с фото. По R-015 (обрезка не нужна на Windows): объединить с Platform check. |  |
| 77 | `Android/lib/presentation/screens/plant_card/tabs/history_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/history_tab.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/tabs/history_tab.dart` | R-014 (QR Android-only) |  |
| 78 | `Android/lib/presentation/screens/plant_card/tabs/overview_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/overview_tab.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/tabs/overview_tab.dart` | R-014 (QR Android-only) |  |
| 79 | `Android/lib/presentation/screens/plant_card/tabs/seedlings_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/seedlings_tab.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/tabs/seedlings_tab.dart` | R-014 (QR Android-only) |  |
| 80 | `Android/lib/presentation/screens/plant_card/widgets/action_card.dart` | `Windows/lib/presentation/screens/plant_card/widgets/action_card.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/widgets/action_card.dart` | R-014 (QR Android-only) |  |
| 81 | `Android/lib/presentation/screens/plant_card/widgets/care_tips_section.dart` | `Windows/lib/presentation/screens/plant_card/widgets/care_tips_section.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/widgets/care_tips_section.dart` | R-014 (QR Android-only) |  |
| 82 | `Android/lib/presentation/screens/plant_card/widgets/description_section.dart` | `Windows/lib/presentation/screens/plant_card/widgets/description_section.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/widgets/description_section.dart` | R-014 (QR Android-only) |  |
| 83 | `Android/lib/presentation/screens/plant_card/widgets/empty_gbif_state.dart` | `Windows/lib/presentation/screens/plant_card/widgets/empty_gbif_state.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/widgets/empty_gbif_state.dart` | R-014 (QR Android-only) |  |
| 84 | `Android/lib/presentation/screens/plant_card/widgets/geography_section.dart` | `Windows/lib/presentation/screens/plant_card/widgets/geography_section.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/widgets/geography_section.dart` | R-014 (QR Android-only) |  |
| 85 | `Android/lib/presentation/screens/plant_card/widgets/stat_card.dart` | `Windows/lib/presentation/screens/plant_card/widgets/stat_card.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/widgets/stat_card.dart` | R-014 (QR Android-only) |  |
| 86 | `Android/lib/presentation/screens/plant_card/widgets/synonyms_section.dart` | `Windows/lib/presentation/screens/plant_card/widgets/synonyms_section.dart` | ANDROID_ONLY | `lib/presentation/screens/plant_card/widgets/synonyms_section.dart` | R-014 (QR Android-only) |  |
| 87 | `Android/lib/presentation/screens/settings/about_screen.dart` | `Windows/lib/presentation/screens/settings/about_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/about_screen.dart` | R-014 (QR Android-only) |  |
| 88 | `Android/lib/presentation/screens/settings/appearance_settings_screen.dart` | `Windows/lib/presentation/screens/settings/appearance_settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/appearance_settings_screen.dart` | R-014 (QR Android-only) |  |
| 89 | `Android/lib/presentation/screens/settings/backup_settings_screen.dart` | `Windows/lib/presentation/screens/settings/backup_settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/backup_settings_screen.dart` | R-014 (QR Android-only) |  |
| 90 | `Android/lib/presentation/screens/settings/behavior_settings_screen.dart` | `Windows/lib/presentation/screens/settings/behavior_settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/behavior_settings_screen.dart` | R-014 (QR Android-only) |  |
| 91 | `Android/lib/presentation/screens/settings/cloud_settings_screen.dart` | `Windows/lib/presentation/screens/settings/cloud_settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/cloud_settings_screen.dart` | R-014 (QR Android-only) |  |
| 92 | `Android/lib/presentation/screens/settings/data_management_screen.dart` | `Windows/lib/presentation/screens/settings/data_management_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/data_management_screen.dart` | R-014 (QR Android-only) |  |
| 93 | `Android/lib/presentation/screens/settings/debug_settings_screen.dart` | `Windows/lib/presentation/screens/settings/debug_settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/debug_settings_screen.dart` | R-014 (QR Android-only) |  |
| 94 | `Android/lib/presentation/screens/settings/experiments_settings_screen.dart` | `Windows/lib/presentation/screens/settings/experiments_settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/experiments_settings_screen.dart` | R-014 (QR Android-only) |  |
| 95 | `Android/lib/presentation/screens/settings/notifications_settings_screen.dart` | `Windows/lib/presentation/screens/settings/notifications_settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/notifications_settings_screen.dart` | R-014 (QR Android-only) |  |
| 96 | `Android/lib/presentation/screens/settings/settings_screen.dart` | `Windows/lib/presentation/screens/settings/settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/settings_screen.dart` | R-014 (QR Android-only) |  |
| 97 | `Android/lib/presentation/screens/settings/system_settings_screen.dart` | `Windows/lib/presentation/screens/settings/system_settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/system_settings_screen.dart` | R-014 (QR Android-only) |  |
| 98 | `Android/lib/presentation/screens/settings/weather_settings_screen.dart` | `Windows/lib/presentation/screens/settings/weather_settings_screen.dart` | ANDROID_ONLY | `lib/presentation/screens/settings/weather_settings_screen.dart` | R-014 (QR Android-only) |  |
| 99 | `Android/lib/screens/add_plant_screen.dart` | `Windows/lib/screens/add_plant_screen.dart` | ANDROID_ONLY | `lib/screens/add_plant_screen.dart` | R-014 (QR Android-only) |  |
| 100 | `Android/lib/screens/add_sowing_year_screen.dart` | `Windows/lib/screens/add_sowing_year_screen.dart` | ANDROID_ONLY | `lib/screens/add_sowing_year_screen.dart` | R-014 (QR Android-only) |  |
| 101 | `Android/lib/screens/batch_qr_creation_screen.dart` | `Windows/lib/screens/batch_qr_creation_screen.dart` | ANDROID_ONLY | `lib/screens/batch_qr_creation_screen.dart` | R-014 (QR Android-only) |  |
| 102 | `Android/lib/screens/care_calendar_screen.dart` | `Windows/lib/screens/care_calendar_screen.dart` | ANDROID_ONLY | `lib/screens/care_calendar_screen.dart` | R-014 (QR Android-only) |  |
| 103 | `Android/lib/screens/collection_management_screen.dart` | `Windows/lib/screens/collection_management_screen.dart` | ANDROID_ONLY | `lib/screens/collection_management_screen.dart` | R-014 (QR Android-only) |  |
| 104 | `Android/lib/screens/edit_plant_screen.dart` | `Windows/lib/screens/edit_plant_screen.dart` | ANDROID_ONLY | `lib/screens/edit_plant_screen.dart` | R-014 (QR Android-only) |  |
| 105 | `Android/lib/screens/plant_statistics_screen.dart` | `Windows/lib/screens/plant_statistics_screen.dart` | ANDROID_ONLY | `lib/screens/plant_statistics_screen.dart` | R-014 (QR Android-only) |  |
| 106 | `Android/lib/screens/print_settings_screen.dart` | `Windows/lib/screens/print_settings_screen.dart` | DIFFERENT | `lib/screens/print_settings_screen.dart` | Windows: printing закомментирован (pdfium), workaround — сохранение PDF. По R-024/D-26: оставить единый файл с Platform check до починки печати. |  |
| 107 | `Android/lib/screens/qr_management_screen.dart` | `Windows/lib/screens/qr_management_screen.dart` | DIFFERENT | `lib/screens/qr_management_screen.dart` | Windows: printing закомментирован + snackbar-замена. По R-024/D-26: то же, что print_settings. |  |
| 108 | `Android/lib/screens/qr_scanner_screen.dart` | — | ANDROID_ONLY | `lib/screens/qr_scanner_screen.dart` | R-014: переносим, обёртка Platform.isAndroid |  |
| 109 | `Android/lib/screens/select_plants_for_print_screen.dart` | `Windows/lib/screens/select_plants_for_print_screen.dart` | ANDROID_ONLY | `lib/screens/select_plants_for_print_screen.dart` | R-014 (QR Android-only) |  |
| 110 | `Android/lib/screens/sowing_management_screen.dart` | `Windows/lib/screens/sowing_management_screen.dart` | ANDROID_ONLY | `lib/screens/sowing_management_screen.dart` | R-014 (QR Android-only) |  |
| 111 | `Android/lib/screens/statistics_screen.dart` | `Windows/lib/screens/statistics_screen.dart` | ANDROID_ONLY | `lib/screens/statistics_screen.dart` | R-014 (QR Android-only) |  |
| 112 | `Android/lib/screens/welcome_screen.dart` | `Windows/lib/screens/welcome_screen.dart` | ANDROID_ONLY | `lib/screens/welcome_screen.dart` | R-014 (QR Android-only) |  |
| 113 | `Android/lib/screens/wintering_screen.dart` | `Windows/lib/screens/wintering_screen.dart` | ANDROID_ONLY | `lib/screens/wintering_screen.dart` | R-014 (QR Android-only) |  |
| 114 | `Android/lib/screens/year_germination_chart_screen.dart` | `Windows/lib/screens/year_germination_chart_screen.dart` | ANDROID_ONLY | `lib/screens/year_germination_chart_screen.dart` | R-014 (QR Android-only) |  |
| 115 | `Android/lib/services/api/gbif_service.dart` | `Windows/lib/services/api/gbif_service.dart` | ANDROID_ONLY | `lib/services/api/gbif_service.dart` | R-014 (QR Android-only) |  |
| 116 | `Android/lib/services/api/llifle_service.dart` | `Windows/lib/services/api/llifle_service.dart` | ANDROID_ONLY | `lib/services/api/llifle_service.dart` | R-014 (QR Android-only) |  |
| 117 | `Android/lib/services/api/weather_service.dart` | `Windows/lib/services/api/weather_service.dart` | DIFFERENT | `lib/services/api/weather_service.dart` | Различие: позиция импорта api_config (косметика; битый импорт исправлен в 0.2, R-033). Объединить. |  |
| 118 | `Android/lib/services/backup/auto_backup_service.dart` | `Windows/lib/services/backup/auto_backup_service.dart` | ANDROID_ONLY | `lib/services/backup/auto_backup_service.dart` | R-014 (QR Android-only) |  |
| 119 | `Android/lib/services/data_export_service.dart` | `Windows/lib/services/data_export_service.dart` | ANDROID_ONLY | `lib/services/data_export_service.dart` | R-014 (QR Android-only) |  |
| 120 | `Android/lib/services/image/image_processor.dart` | `Windows/lib/services/image/image_processor.dart` | ANDROID_ONLY | `lib/services/image/image_processor.dart` | R-014 (QR Android-only) |  |
| 121 | `Android/lib/services/image/photo_cache_manager.dart` | `Windows/lib/services/image/photo_cache_manager.dart` | ANDROID_ONLY | `lib/services/image/photo_cache_manager.dart` | R-014 (QR Android-only) |  |
| 122 | `Android/lib/services/isolates/http_isolate.dart` | `Windows/lib/services/isolates/http_isolate.dart` | DIFFERENT | `lib/services/isolates/http_isolate.dart` | Различие: 1 строка комментария. Объединить. |  |
| 123 | `Android/lib/services/photo_sync_service.dart` | `Windows/lib/services/photo_sync_service.dart` | DIFFERENT | `lib/services/photo_sync_service.dart` | Windows: валидация cloud URL + удаление битых локальных путей. Android: локальный fallback сохраняется. Фото-синк критичен — ждёт решения владельца (контекст R-004). |  |
| 124 | `Android/lib/services/sync_manager.dart` | `Windows/lib/services/sync_manager.dart` | ANDROID_ONLY | `lib/services/sync_manager.dart` | R-014 (QR Android-only) |  |
| 125 | `Android/lib/services/yandex_auth_service.dart` | `Windows/lib/services/yandex_auth_service.dart` | DIFFERENT | `lib/services/yandex_auth_service.dart` | Android: +24 строки MethodChannel deep_link handler. По R-011: осознанное различие → Platform.isAndroid. |  |
| 126 | `Android/lib/services/yandex_disk_service.dart` | `Windows/lib/services/yandex_disk_service.dart` | ANDROID_ONLY | `lib/services/yandex_disk_service.dart` | R-014 (QR Android-only) |  |
| 127 | `Android/lib/theme/cactus_theme.dart` | `Windows/lib/theme/cactus_theme.dart` | ANDROID_ONLY | `lib/theme/cactus_theme.dart` | R-014 (QR Android-only) |  |
| 128 | `Android/lib/utils/responsive_helper.dart` | `Windows/lib/utils/responsive_helper.dart` | DIFFERENT | `lib/utils/responsive_helper.dart` | То же, что core/utils/responsive_helper.dart (старый дубль): Android 2/3 · Windows 3/5 колонок. Platform check. |  |
| 129 | `Android/lib/widgets/image_selection_dialog.dart` | `Windows/lib/widgets/image_selection_dialog.dart` | ANDROID_ONLY | `lib/widgets/image_selection_dialog.dart` | R-014 (QR Android-only) |  |
| 130 | `Android/lib/widgets/notes_bottom_sheet.dart` | `Windows/lib/widgets/notes_bottom_sheet.dart` | ANDROID_ONLY | `lib/widgets/notes_bottom_sheet.dart` | R-014 (QR Android-only) |  |
| 131 | `Android/lib/widgets/plant_cards.dart` | `Windows/lib/widgets/plant_cards.dart` | DIFFERENT | `lib/widgets/plant_cards.dart` | 191 изменённая строка (114/77) — платформенный UI карточек. По R-011/012/020: осознанные различия → Platform check, заморозка UI. |  |
| 132 | `Android/lib/widgets/print_preview_widget.dart` | `Windows/lib/widgets/print_preview_widget.dart` | ANDROID_ONLY | `lib/widgets/print_preview_widget.dart` | R-014 (QR Android-only) |  |
| 133 | `Android/lib/widgets/qr_code_widget.dart` | — | ANDROID_ONLY | `lib/widgets/qr_code_widget.dart` | R-014 (QR Android-only) |  |

## 3. Правила слияния (по решениям владельца)

- **IDENTICAL**: берём любую копию (одинаковы по sha1).
- **DIFFERENT**: разбираем по файлу согласно таблице выше и PLATFORM_DIFF_REGISTRY.md.
- **ANDROID_ONLY**: переносим как есть в lib/ (R-014: QR-сканер только на Android). Обёртка: `if (Platform.isAndroid)`.
- **WINDOWS_ONLY** (`firebase_options.dart`): **В АРХИВ** (R-027: Firebase удаляется).
- **52 файла в lib/{screens,models,widgets,theme,utils}**: старые папки параллельно новой структуре (незаконченный рефакторинг, R-025). Проверка по sha1 + reachability: см. раздел «Старые папки».

## 4. Старые папки lib/{screens,models,widgets,theme,utils}

Механический анализ: имя-аналог в новой структуре по sha1 + подсчёт импортов.
**Результат: все 52 файла живые (импортируются). Дублей по sha1 — только `utils/responsive_helper.dart` (= `core/utils/responsive_helper.dart`).** Новые аналоги существуют под другими именами в `presentation/` — сверка по функции при переносе (задача 1.2Б).

| Старый путь | Новый аналог (sha1) | Решение | Подтверждение |
|---|---|---|---|
| `lib/models/gbif_occurrence.dart` | — | не дубль, живой (6 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/models/plant.dart` | — | не дубль, живой (40 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/models/qr_code.dart` | — | не дубль, живой (3 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/models/qr_code_file.dart` | — | не дубль, живой (6 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/add_plant_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/add_sowing_year_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/batch_qr_creation_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/care_calendar_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/collection_management_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/edit_plant_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/plant_statistics_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/print_settings_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/qr_management_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/qr_scanner_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/select_plants_for_print_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/sowing_management_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/statistics_screen.dart` | — | не дубль, живой (2 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/welcome_screen.dart` | — | не дубль, живой (2 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/wintering_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/screens/year_germination_chart_screen.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/theme/cactus_theme.dart` | — | не дубль, живой (4 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/utils/responsive_helper.dart` | `lib/core/utils/responsive_helper.dart` | дубль (sha1 = core-аналог): объединить импорты на core-версию → архив | |
| `lib/widgets/image_selection_dialog.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/widgets/notes_bottom_sheet.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/widgets/plant_cards.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/widgets/print_preview_widget.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |
| `lib/widgets/qr_code_widget.dart` | — | не дубль, живой (1 импортов): перенести / сверить с presentation-аналогом по функции | |

### Итоги по старым папкам
Таблица по уникальным путям (27 строк = 52 файла в двух копиях: Android 27 + Windows 25).
- Удалить/в архив как дубль: **2 файла / 1 путь** (`utils/responsive_helper.dart` в обеих копиях — после объединения импортов на core-версию)
- Перенести/сверить с presentation-аналогом: **50 файлов / 26 путей** (все живые, импортируются)
- Оставить как есть: **0**

## 5. Реестр ассетов

Android/assets: 4 · Windows/assets: 4 · общих: 4 · все sha1-идентичны. Слияние тривиально.

| Android | Windows | Статус | Куда |
|---|---|---|---|
| `assets/country_mapping.json` | `assets/country_mapping.json` | sha1-идентичен | `assets/country_mapping.json` |
| `assets/icons/Icon 1.png` | `assets/icons/Icon 1.png` | sha1-идентичен; msix logo_path | `assets/icons/Icon 1.png` |
| `assets/placeholder1.jpg` | `assets/placeholder1.jpg` | sha1-идентичен | `assets/placeholder1.jpg` |
| `assets/placeholder2.jpg` | `assets/placeholder2.jpg` | sha1-идентичен | `assets/placeholder2.jpg` |

## 6. Таблица зависимостей pubspec.yaml

Android: 49 dep + 7 dev · Windows: 41 dep + 7 dev · общих: 41+7.
Различия только в Android-only пакетах (в Windows отсутствуют или закомментированы).

| Зависимость | Android | Windows | Вердикт |
|---|---|---|---|
| `cached_network_image: ^3.2.0` | ✔ | ✔ | оставить |
| `collection: ^1.19.1` | ✔ | ✔ | оставить |
| `csv: ^6.0.0` | ✔ | ✔ | оставить |
| `excel: ^4.0.6` | ✔ | ✔ | оставить |
| `file_picker: ^10.1.9` | ✔ | ✔ | оставить |
| `flutter:` | ✔ | ✔ | оставить |
| `flutter_lints: ^6.0.0` | ✔ | ✔ | оставить |
| `image_cropper: ^12.2.0` | ✔ | — (нет/закоммент.) | оставить с platform check (R-015: обрезка Android) |
| `html: ^0.15.5+1` | ✔ | ✔ | оставить |
| `http: ^1.3.0` | ✔ | ✔ | оставить |
| `path_provider: ^2.1.4` | ✔ | ✔ | оставить |
| `provider: ^6.1.1` | ✔ | ✔ | оставить |
| `shared_preferences: ^2.5.2` | ✔ | ✔ | оставить |
| `syncfusion_flutter_charts: ^29.2.9` | ✔ | ✔ | оставить |
| `syncfusion_flutter_treemap: ^29.2.9` | ✔ | ✔ | оставить |
| `url_launcher: ^6.2.0` | ✔ | ✔ | оставить |
| `uuid: ^4.5.1` | ✔ | ✔ | оставить |
| `table_calendar: ^3.0.9` | ✔ | ✔ | оставить |
| `image_picker: ^1.1.2` | ✔ | — (нет/закоммент.) | оставить с platform check (выбор фото) |
| `intl: ^0.20.2` | ✔ | ✔ | оставить |
| `oauth2: ^2.0.2` | ✔ | ✔ | оставить |
| `path: ^1.8.3` | ✔ | ✔ | оставить |
| `dio: ^5.7.0` | ✔ | ✔ | оставить |
| `flutter_secure_storage: ^9.2.2` | ✔ | ✔ | оставить |
| `go_router: ^14.8.0` | ✔ | ✔ | оставить |
| `flutter_launcher_icons: ^0.14.3` | ✔ | ✔ | оставить |
| `msix: ^3.16.8` | ✔ | ✔ | оставить |
| `image: ^4.1.3` | ✔ | ✔ | оставить |
| `timezone: ^0.9.2` | ✔ | ✔ | оставить |
| `geolocator: ^11.0.1` | ✔ | ✔ | оставить |
| `flutter_local_notifications: ^17.2.2` | ✔ | ✔ | оставить |
| `flutter_map: ^6.1.0` | ✔ | ✔ | оставить |
| `latlong2: ^0.9.1` | ✔ | ✔ | оставить |
| `qr_flutter: ^4.1.0` | ✔ | ✔ | оставить |
| `mobile_scanner: ^5.0.0` | ✔ | — (нет/закоммент.) | оставить с platform check (R-014: QR-сканер Android) |
| `pdf: ^3.10.8` | ✔ | ✔ | оставить |
| `printing: ^5.13.4` | ✔ | — (нет/закоммент.) | оставить с platform check (R-024: печать чиним; Windows — save-PDF workaround) |
| `get_it: ^7.6.0` | ✔ | ✔ | оставить |
| `injectable: ^2.3.2` | ✔ | ✔ | оставить |
| `hive: ^2.2.3` | ✔ | ✔ | оставить |
| `hive_flutter: ^1.1.0` | ✔ | ✔ | оставить |
| `logger: ^2.0.0+1` | ✔ | ✔ | оставить |
| `flutter_image_compress: ^2.4.0` | ✔ | ✔ | оставить |
| `flutter_cache_manager: ^3.4.1` | ✔ | ✔ | оставить |
| `firebase_core: ^2.24.2` | ✔ | — (нет/закоммент.) | убрать (R-027) |
| `firebase_crashlytics: ^3.4.9` | ✔ | — (нет/закоммент.) | убрать (R-027) |
| `firebase_analytics: ^10.8.0` | ✔ | — (нет/закоммент.) | убрать (R-027) |
| `firebase_remote_config: ^4.3.2` | ✔ | — (нет/закоммент.) | убрать (R-027) |
| `share_plus: ^10.0.0` | ✔ | ✔ | оставить |

### dev_dependencies (идентичны, 7 шт.)
| Зависимость | Android | Windows | Вердикт |
|---|---|---|---|
| `flutter_test:` | ✔ | ✔ | оставить |
| `integration_test:` | ✔ | ✔ | оставить |
| `mockito: ^5.4.4` | ✔ | ✔ | оставить |
| `mocktail: ^1.0.4` | ✔ | ✔ | оставить |
| `injectable_generator: ^2.4.1` | ✔ | ✔ | оставить |
| `build_runner: ^2.4.8` | ✔ | ✔ | оставить |
| `hive_generator: ^2.0.1` | ✔ | ✔ | оставить |

## 7. Что НЕ входит в этот план

- Сам перенос файлов (задача 1.2Б), правка pubspec (1.2В), починка печати (этап 4).
- Каталоги `android/`, `windows/` платформенных оболочек — мерж отдельным шагом с подтверждением.
