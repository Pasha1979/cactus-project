# FEATURE REGISTRY — реестр файлов функций

Сгенерировано механически из git (sha1 содержимого), 2026-11-17. Не править руками — перегенерировать скриптом.

## Контрольные цифры (сверено с утверждёнными)

| Метрика | Значение |
|---|---|
| Android/lib | 132 |
| Windows/lib | 131 |
| Идентичных | 111 |
| Различаются | 19 |
| Только в Android | 2 |
| Только в Windows | 1 |

## Таблица

| путь в Android/lib | путь в Windows/lib | статус | куда перенесён | подтверждение |
|---|---|---|---|---|
| `Android/lib/core/config/api_config.dart` | `Windows/lib/core/config/api_config.dart` | идентичен | — | — |
| `Android/lib/core/config/app_constants.dart` | `Windows/lib/core/config/app_constants.dart` | различается | — | ждёт решения владельца |
| `Android/lib/core/config/feature_flags.dart` | `Windows/lib/core/config/feature_flags.dart` | различается | — | ждёт решения владельца |
| `Android/lib/core/config/route_config.dart` | `Windows/lib/core/config/route_config.dart` | идентичен | — | — |
| `Android/lib/core/config/theme_config.dart` | `Windows/lib/core/config/theme_config.dart` | идентичен | — | — |
| `Android/lib/core/error/error_boundary.dart` | `Windows/lib/core/error/error_boundary.dart` | идентичен | — | — |
| `Android/lib/core/error/error_handler.dart` | `Windows/lib/core/error/error_handler.dart` | идентичен | — | — |
| `Android/lib/core/error/exceptions.dart` | `Windows/lib/core/error/exceptions.dart` | идентичен | — | — |
| `Android/lib/core/error/failures.dart` | `Windows/lib/core/error/failures.dart` | идентичен | — | — |
| `Android/lib/core/logger/app_logger.dart` | `Windows/lib/core/logger/app_logger.dart` | различается | — | ждёт решения владельца |
| `Android/lib/core/logger/logger_service.dart` | `Windows/lib/core/logger/logger_service.dart` | идентичен | — | — |
| `Android/lib/core/network/network_info.dart` | `Windows/lib/core/network/network_info.dart` | идентичен | — | — |
| `Android/lib/core/ui/ui_state.dart` | `Windows/lib/core/ui/ui_state.dart` | идентичен | — | — |
| `Android/lib/core/ui/ui_state_builder.dart` | `Windows/lib/core/ui/ui_state_builder.dart` | идентичен | — | — |
| `Android/lib/core/utils/date_formatter.dart` | `Windows/lib/core/utils/date_formatter.dart` | идентичен | — | — |
| `Android/lib/core/utils/plant_status_mapper.dart` | `Windows/lib/core/utils/plant_status_mapper.dart` | идентичен | — | — |
| `Android/lib/core/utils/responsive_helper.dart` | `Windows/lib/core/utils/responsive_helper.dart` | различается | — | ждёт решения владельца |
| `Android/lib/core/utils/translation_utils.dart` | `Windows/lib/core/utils/translation_utils.dart` | идентичен | — | — |
| `Android/lib/core/utils/validators.dart` | `Windows/lib/core/utils/validators.dart` | идентичен | — | — |
| `Android/lib/data/datasources/local/gbif_cache_local_datasource.dart` | `Windows/lib/data/datasources/local/gbif_cache_local_datasource.dart` | идентичен | — | — |
| `Android/lib/data/datasources/local/hive_database.dart` | `Windows/lib/data/datasources/local/hive_database.dart` | идентичен | — | — |
| `Android/lib/data/datasources/local/note_local_datasource.dart` | `Windows/lib/data/datasources/local/note_local_datasource.dart` | идентичен | — | — |
| `Android/lib/data/datasources/local/plant_index_manager.dart` | `Windows/lib/data/datasources/local/plant_index_manager.dart` | идентичен | — | — |
| `Android/lib/data/datasources/local/plant_local_datasource.dart` | `Windows/lib/data/datasources/local/plant_local_datasource.dart` | различается | — | ждёт решения владельца |
| `Android/lib/data/datasources/local/qr_code_local_datasource.dart` | `Windows/lib/data/datasources/local/qr_code_local_datasource.dart` | идентичен | — | — |
| `Android/lib/data/datasources/local/wintering_local_datasource.dart` | `Windows/lib/data/datasources/local/wintering_local_datasource.dart` | идентичен | — | — |
| `Android/lib/data/migrations/data_migration_manager.dart` | `Windows/lib/data/migrations/data_migration_manager.dart` | идентичен | — | — |
| `Android/lib/data/models/gbif_occurrence_dto.dart` | `Windows/lib/data/models/gbif_occurrence_dto.dart` | идентичен | — | — |
| `Android/lib/data/models/gbif_occurrence_dto.g.dart` | `Windows/lib/data/models/gbif_occurrence_dto.g.dart` | идентичен | — | — |
| `Android/lib/data/models/note_dto.dart` | `Windows/lib/data/models/note_dto.dart` | идентичен | — | — |
| `Android/lib/data/models/note_dto.g.dart` | `Windows/lib/data/models/note_dto.g.dart` | идентичен | — | — |
| `Android/lib/data/models/plant_dto.dart` | `Windows/lib/data/models/plant_dto.dart` | идентичен | — | — |
| `Android/lib/data/models/plant_dto.g.dart` | `Windows/lib/data/models/plant_dto.g.dart` | идентичен | — | — |
| `Android/lib/data/models/qr_code_dto.dart` | `Windows/lib/data/models/qr_code_dto.dart` | идентичен | — | — |
| `Android/lib/data/models/qr_code_dto.g.dart` | `Windows/lib/data/models/qr_code_dto.g.dart` | идентичен | — | — |
| `Android/lib/data/models/wintering_log_entry_dto.dart` | `Windows/lib/data/models/wintering_log_entry_dto.dart` | идентичен | — | — |
| `Android/lib/data/models/wintering_log_entry_dto.g.dart` | `Windows/lib/data/models/wintering_log_entry_dto.g.dart` | идентичен | — | — |
| `Android/lib/data/repositories/batch_repository_impl.dart` | `Windows/lib/data/repositories/batch_repository_impl.dart` | идентичен | — | — |
| `Android/lib/data/repositories/note_repository_impl.dart` | `Windows/lib/data/repositories/note_repository_impl.dart` | идентичен | — | — |
| `Android/lib/data/repositories/photo_repository_impl.dart` | `Windows/lib/data/repositories/photo_repository_impl.dart` | идентичен | — | — |
| `Android/lib/data/repositories/plant_repository_impl.dart` | `Windows/lib/data/repositories/plant_repository_impl.dart` | идентичен | — | — |
| `Android/lib/data/repositories/qr_code_repository_impl.dart` | `Windows/lib/data/repositories/qr_code_repository_impl.dart` | идентичен | — | — |
| `Android/lib/data/repositories/sync_repository_impl.dart` | `Windows/lib/data/repositories/sync_repository_impl.dart` | идентичен | — | — |
| `Android/lib/data/repositories/watering_repository_impl.dart` | `Windows/lib/data/repositories/watering_repository_impl.dart` | идентичен | — | — |
| `Android/lib/data/repositories/wintering_repository_impl.dart` | `Windows/lib/data/repositories/wintering_repository_impl.dart` | идентичен | — | — |
| `Android/lib/domain/repositories/batch_repository.dart` | `Windows/lib/domain/repositories/batch_repository.dart` | идентичен | — | — |
| `Android/lib/domain/repositories/note_repository.dart` | `Windows/lib/domain/repositories/note_repository.dart` | идентичен | — | — |
| `Android/lib/domain/repositories/photo_repository.dart` | `Windows/lib/domain/repositories/photo_repository.dart` | идентичен | — | — |
| `Android/lib/domain/repositories/plant_repository.dart` | `Windows/lib/domain/repositories/plant_repository.dart` | идентичен | — | — |
| `Android/lib/domain/repositories/qr_code_repository.dart` | `Windows/lib/domain/repositories/qr_code_repository.dart` | идентичен | — | — |
| `Android/lib/domain/repositories/sync_repository.dart` | `Windows/lib/domain/repositories/sync_repository.dart` | идентичен | — | — |
| `Android/lib/domain/repositories/watering_repository.dart` | `Windows/lib/domain/repositories/watering_repository.dart` | идентичен | — | — |
| `Android/lib/domain/repositories/wintering_repository.dart` | `Windows/lib/domain/repositories/wintering_repository.dart` | идентичен | — | — |
| `—` | `Windows/lib/firebase_options.dart` | только в Windows | — | R-027: Firebase убрать в архив; Q-5 открытый вопрос |
| `Android/lib/injection_container.dart` | `Windows/lib/injection_container.dart` | идентичен | — | — |
| `Android/lib/main.dart` | `Windows/lib/main.dart` | различается | — | ждёт решения владельца |
| `Android/lib/models/gbif_occurrence.dart` | `Windows/lib/models/gbif_occurrence.dart` | идентичен | — | — |
| `Android/lib/models/plant.dart` | `Windows/lib/models/plant.dart` | идентичен | — | — |
| `Android/lib/models/qr_code.dart` | `Windows/lib/models/qr_code.dart` | идентичен | — | — |
| `Android/lib/models/qr_code_file.dart` | `Windows/lib/models/qr_code_file.dart` | идентичен | — | — |
| `Android/lib/presentation/providers/batch_provider.dart` | `Windows/lib/presentation/providers/batch_provider.dart` | идентичен | — | — |
| `Android/lib/presentation/providers/cloud_storage_provider.dart` | `Windows/lib/presentation/providers/cloud_storage_provider.dart` | идентичен | — | — |
| `Android/lib/presentation/providers/photo_provider.dart` | `Windows/lib/presentation/providers/photo_provider.dart` | различается | — | ждёт решения владельца |
| `Android/lib/presentation/providers/plant_crud_provider.dart` | `Windows/lib/presentation/providers/plant_crud_provider.dart` | различается | — | ждёт решения владельца |
| `Android/lib/presentation/providers/providers.dart` | `Windows/lib/presentation/providers/providers.dart` | идентичен | — | — |
| `Android/lib/presentation/providers/qr_code_provider.dart` | `Windows/lib/presentation/providers/qr_code_provider.dart` | идентичен | — | — |
| `Android/lib/presentation/providers/settings_provider.dart` | `Windows/lib/presentation/providers/settings_provider.dart` | идентичен | — | — |
| `Android/lib/presentation/providers/sync_provider.dart` | `Windows/lib/presentation/providers/sync_provider.dart` | идентичен | — | — |
| `Android/lib/presentation/providers/watering_provider.dart` | `Windows/lib/presentation/providers/watering_provider.dart` | идентичен | — | — |
| `Android/lib/presentation/providers/weather_provider.dart` | `Windows/lib/presentation/providers/weather_provider.dart` | идентичен | — | — |
| `Android/lib/presentation/providers/wintering_provider.dart` | `Windows/lib/presentation/providers/wintering_provider.dart` | идентичен | — | — |
| `Android/lib/presentation/routers/app_router.dart` | `Windows/lib/presentation/routers/app_router.dart` | различается | — | ждёт решения владельца |
| `Android/lib/presentation/screens/plant_card/plant_card_screen.dart` | `Windows/lib/presentation/screens/plant_card/plant_card_screen.dart` | различается | — | ждёт решения владельца |
| `Android/lib/presentation/screens/plant_card/tabs/care_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/care_tab.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/tabs/distribution_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/distribution_tab.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/tabs/gallery_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/gallery_tab.dart` | различается | — | ждёт решения владельца |
| `Android/lib/presentation/screens/plant_card/tabs/history_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/history_tab.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/tabs/overview_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/overview_tab.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/tabs/seedlings_tab.dart` | `Windows/lib/presentation/screens/plant_card/tabs/seedlings_tab.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/widgets/action_card.dart` | `Windows/lib/presentation/screens/plant_card/widgets/action_card.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/widgets/care_tips_section.dart` | `Windows/lib/presentation/screens/plant_card/widgets/care_tips_section.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/widgets/description_section.dart` | `Windows/lib/presentation/screens/plant_card/widgets/description_section.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/widgets/empty_gbif_state.dart` | `Windows/lib/presentation/screens/plant_card/widgets/empty_gbif_state.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/widgets/geography_section.dart` | `Windows/lib/presentation/screens/plant_card/widgets/geography_section.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/widgets/stat_card.dart` | `Windows/lib/presentation/screens/plant_card/widgets/stat_card.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/plant_card/widgets/synonyms_section.dart` | `Windows/lib/presentation/screens/plant_card/widgets/synonyms_section.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/about_screen.dart` | `Windows/lib/presentation/screens/settings/about_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/appearance_settings_screen.dart` | `Windows/lib/presentation/screens/settings/appearance_settings_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/backup_settings_screen.dart` | `Windows/lib/presentation/screens/settings/backup_settings_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/behavior_settings_screen.dart` | `Windows/lib/presentation/screens/settings/behavior_settings_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/cloud_settings_screen.dart` | `Windows/lib/presentation/screens/settings/cloud_settings_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/data_management_screen.dart` | `Windows/lib/presentation/screens/settings/data_management_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/debug_settings_screen.dart` | `Windows/lib/presentation/screens/settings/debug_settings_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/experiments_settings_screen.dart` | `Windows/lib/presentation/screens/settings/experiments_settings_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/notifications_settings_screen.dart` | `Windows/lib/presentation/screens/settings/notifications_settings_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/settings_screen.dart` | `Windows/lib/presentation/screens/settings/settings_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/system_settings_screen.dart` | `Windows/lib/presentation/screens/settings/system_settings_screen.dart` | идентичен | — | — |
| `Android/lib/presentation/screens/settings/weather_settings_screen.dart` | `Windows/lib/presentation/screens/settings/weather_settings_screen.dart` | идентичен | — | — |
| `Android/lib/screens/add_plant_screen.dart` | `Windows/lib/screens/add_plant_screen.dart` | идентичен | — | — |
| `Android/lib/screens/add_sowing_year_screen.dart` | `Windows/lib/screens/add_sowing_year_screen.dart` | идентичен | — | — |
| `Android/lib/screens/batch_qr_creation_screen.dart` | `Windows/lib/screens/batch_qr_creation_screen.dart` | идентичен | — | — |
| `Android/lib/screens/care_calendar_screen.dart` | `Windows/lib/screens/care_calendar_screen.dart` | идентичен | — | — |
| `Android/lib/screens/collection_management_screen.dart` | `Windows/lib/screens/collection_management_screen.dart` | идентичен | — | — |
| `Android/lib/screens/edit_plant_screen.dart` | `Windows/lib/screens/edit_plant_screen.dart` | идентичен | — | — |
| `Android/lib/screens/plant_statistics_screen.dart` | `Windows/lib/screens/plant_statistics_screen.dart` | идентичен | — | — |
| `Android/lib/screens/print_settings_screen.dart` | `Windows/lib/screens/print_settings_screen.dart` | различается | — | R-024/D-26: печать Windows сломана — чиним (PDF-workaround) |
| `Android/lib/screens/qr_management_screen.dart` | `Windows/lib/screens/qr_management_screen.dart` | различается | — | ждёт решения владельца |
| `Android/lib/screens/qr_scanner_screen.dart` | `—` | только в Android | — | R-014: QR-сканер только Android, на Windows ручной ввод |
| `Android/lib/screens/select_plants_for_print_screen.dart` | `Windows/lib/screens/select_plants_for_print_screen.dart` | идентичен | — | — |
| `Android/lib/screens/sowing_management_screen.dart` | `Windows/lib/screens/sowing_management_screen.dart` | идентичен | — | — |
| `Android/lib/screens/statistics_screen.dart` | `Windows/lib/screens/statistics_screen.dart` | идентичен | — | — |
| `Android/lib/screens/welcome_screen.dart` | `Windows/lib/screens/welcome_screen.dart` | идентичен | — | — |
| `Android/lib/screens/wintering_screen.dart` | `Windows/lib/screens/wintering_screen.dart` | идентичен | — | — |
| `Android/lib/screens/year_germination_chart_screen.dart` | `Windows/lib/screens/year_germination_chart_screen.dart` | идентичен | — | — |
| `Android/lib/services/api/gbif_service.dart` | `Windows/lib/services/api/gbif_service.dart` | идентичен | — | — |
| `Android/lib/services/api/llifle_service.dart` | `Windows/lib/services/api/llifle_service.dart` | идентичен | — | — |
| `Android/lib/services/api/weather_service.dart` | `Windows/lib/services/api/weather_service.dart` | различается | — | ждёт решения владельца |
| `Android/lib/services/backup/auto_backup_service.dart` | `Windows/lib/services/backup/auto_backup_service.dart` | идентичен | — | — |
| `Android/lib/services/data_export_service.dart` | `Windows/lib/services/data_export_service.dart` | идентичен | — | — |
| `Android/lib/services/image/image_processor.dart` | `Windows/lib/services/image/image_processor.dart` | идентичен | — | — |
| `Android/lib/services/image/photo_cache_manager.dart` | `Windows/lib/services/image/photo_cache_manager.dart` | идентичен | — | — |
| `Android/lib/services/isolates/http_isolate.dart` | `Windows/lib/services/isolates/http_isolate.dart` | различается | — | ждёт решения владельца |
| `Android/lib/services/photo_sync_service.dart` | `Windows/lib/services/photo_sync_service.dart` | различается | — | ждёт решения владельца |
| `Android/lib/services/sync_manager.dart` | `Windows/lib/services/sync_manager.dart` | идентичен | — | — |
| `Android/lib/services/yandex_auth_service.dart` | `Windows/lib/services/yandex_auth_service.dart` | различается | — | ждёт решения владельца |
| `Android/lib/services/yandex_disk_service.dart` | `Windows/lib/services/yandex_disk_service.dart` | идентичен | — | — |
| `Android/lib/theme/cactus_theme.dart` | `Windows/lib/theme/cactus_theme.dart` | идентичен | — | — |
| `Android/lib/utils/responsive_helper.dart` | `Windows/lib/utils/responsive_helper.dart` | различается | — | ждёт решения владельца |
| `Android/lib/widgets/image_selection_dialog.dart` | `Windows/lib/widgets/image_selection_dialog.dart` | идентичен | — | — |
| `Android/lib/widgets/notes_bottom_sheet.dart` | `Windows/lib/widgets/notes_bottom_sheet.dart` | идентичен | — | — |
| `Android/lib/widgets/plant_cards.dart` | `Windows/lib/widgets/plant_cards.dart` | различается | — | ждёт решения владельца |
| `Android/lib/widgets/print_preview_widget.dart` | `Windows/lib/widgets/print_preview_widget.dart` | идентичен | — | — |
| `Android/lib/widgets/qr_code_widget.dart` | `—` | только в Android | — | связано с R-014 |
