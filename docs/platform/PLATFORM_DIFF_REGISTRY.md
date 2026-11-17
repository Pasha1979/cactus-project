# PLATFORM DIFF REGISTRY — реестр различий платформ

Сгенерировано механически из git (sha1 содержимого), 2026-11-17.

## Контрольные цифры

- Android/lib: **132** файла · Windows/lib: **131** файл
- Идентичных: **111** · различаются: **19** · только в Android: **2** · только в Windows: **1**

## Уже решённые различия (подтверждены владельцем)

| Файл | Различие | Решение |
|---|---|---|
| `lib/screens/qr_scanner_screen.dart` (только Android) | Сканер камеры | R-014: QR-сканер на Windows не нужен, ручной ввод возможен |
| `lib/widgets/qr_code_widget.dart` (только Android) | Виджет QR | связано с R-014 |
| Обрезка фото (в фото-файлах ниже) | Crop-функция | R-015: обрезка на Windows не нужна |
| `lib/screens/print_settings_screen.dart` | Печать PDF | R-024 + D-26: печать на Windows сломана (pdfium) — чиним; сейчас workaround «сохранение PDF» |
| Кнопка «Выход» | Есть на обеих | R-016: остаётся везде |
| `lib/firebase_options.dart` (только Windows) | Firebase-конфиг | R-027: Firebase убрать в архив (Q-5: зачем в Windows — открытый вопрос) |

## 19 различающихся файлов (механический список, sha1 не совпадает)

| Файл | Статус решения |
|---|---|
| `lib/core/config/app_constants.dart` | ждёт решения владельца |
| `lib/core/config/feature_flags.dart` | ждёт решения владельца |
| `lib/core/logger/app_logger.dart` | ждёт решения владельца |
| `lib/core/utils/responsive_helper.dart` | ждёт решения владельца |
| `lib/data/datasources/local/plant_local_datasource.dart` | ждёт решения владельца |
| `lib/main.dart` | ждёт решения владельца |
| `lib/presentation/providers/photo_provider.dart` | ждёт решения владельца (частично R-015 обрезка) |
| `lib/presentation/providers/plant_crud_provider.dart` | ждёт решения владельца |
| `lib/presentation/routers/app_router.dart` | ждёт решения владельца |
| `lib/presentation/screens/plant_card/plant_card_screen.dart` | ждёт решения владельца |
| `lib/presentation/screens/plant_card/tabs/gallery_tab.dart` | ждёт решения владельца |
| `lib/screens/print_settings_screen.dart` | R-024/D-26: чинить печать на Windows |
| `lib/screens/qr_management_screen.dart` | ждёт решения владельца (частично R-014) |
| `lib/services/api/weather_service.dart` | ждёт решения владельца |
| `lib/services/isolates/http_isolate.dart` | ждёт решения владельца |
| `lib/services/photo_sync_service.dart` | ждёт решения владельца |
| `lib/services/yandex_auth_service.dart` | ждёт решения владельца |
| `lib/utils/responsive_helper.dart` | ждёт решения владельца |
| `lib/widgets/plant_cards.dart` | ждёт решения владельца |

## Правило

Случайные различия устраняются, осознанные — сохраняются по подтверждению владельца (R-011). UI обеих платформ заморожен (R-012, R-020).
