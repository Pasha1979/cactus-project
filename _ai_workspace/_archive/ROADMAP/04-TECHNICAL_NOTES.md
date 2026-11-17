# TECHNICAL NOTES - Технические заметки

**Дата создания:** 2026-05-09  
**Последнее обновление:** 2026-05-09

---

## Архитектурные решения

### Текущая архитектура (BASELINE)

**Паттерн:** Provider + SharedPreferences  
**Хранение:** JSON в SharedPreferences  
**Синхронизация:** Яндекс.Диск (OAuth2)  
**Парсинг:** GBIF API, Llifle HTML  

**Преимущества:**
- Простота
- Быстрая реализация
- Кроссплатформенность

**Недостатки:**
- Ограничение на размер данных
- Нет транзакций
- Нет сложных запросов
- Медленно при большом количестве данных

---

### Целевая архитектура (VISION)

**Паттерн:** Repository + Service Layer  
**Хранение:** SQLite/Realm/WatermelonDB  
**Синхронизация:** Яндекс.Диск (OAuth2) + опционально другие  
**Парсинг:** GBIF API, Llifle HTML + опционально другие  
**Архитектурный стиль:** Offline-First + Event-Driven  

**Преимущества:**
- Масштабируемость
- Транзакции
- Сложные запросы
- Отношения между данными
- Производительность

**Недостатки:**
- Сложность миграции
- Больше кода
- Требует тщательного тестирования

---

## Ключевые файлы и их назначение

### Модели данных (текущие)
- `lib/models/plant.dart` - основная модель растения (все данные в одной модели)

### Провайдеры (текущие)
- `lib/providers/plant_provider.dart` - управление растениями
- `lib/providers/cloud_storage_provider.dart` - синхронизация с Яндекс.Диск

### Утилиты (текущие)
- `lib/utils/gbif_utils.dart` - парсинг GBIF
- `lib/utils/llifle_utils.dart` - парсинг Llifle
- `lib/utils/weather_service.dart` - погода
- `lib/utils/responsive_helper.dart` - адаптивность
- `lib/utils/translation_utils.dart` - перевод

### Экраны (текущие)
- `lib/screens/main.dart` - главная точка входа, HomeScreen
- `lib/screens/welcome_screen.dart` - экран приветствия
- `lib/screens/plant_card_screen.dart` - карточка растения
- `lib/screens/edit_plant_screen.dart` - редактирование растения
- `lib/screens/collection_management_screen.dart` - управление коллекцией
- `lib/screens/care_calendar_screen.dart` - календарь ухода
- `lib/screens/statistics_screen.dart` - статистика
- `lib/screens/plant_statistics_screen.dart` - статистика растения
- `lib/screens/sowing_management_screen.dart` - управление посевами
- `lib/screens/wintering_screen.dart` - управление зимовкой
- `lib/screens/add_sowing_year_screen.dart` - добавление года посева
- `lib/screens/year_germination_chart_screen.dart` - график всхожести

---

## Технический стек

### Текущий (BASELINE)
- **Flutter:** 3.x
- **Dart:** 3.x
- **State Management:** Provider
- **Хранение:** SharedPreferences
- **Сеть:** http, dio
- **OAuth2:** oauth2
- **Безопасность:** flutter_secure_storage
- **Уведомления:** flutter_local_notifications
- **Карта:** flutter_map
- **Фото:** image_picker, image_cropper (только Android)
- **CSV:** csv
- **UUID:** uuid
- **File Picker:** file_picker
- **URL Launcher:** url_launcher
- **Intl:** intl
- **Timezone:** timezone
- **Path Provider:** path_provider
- **HTML:** html

### Целевой (VISION)
- Все текущие зависимости +
- **БД:** SQLite (sqflite) или Realm или WatermelonDB (на выбор)
- **QR:** qr_flutter, flutter_barcode
- **EXIF:** exif
- **Датчики:** flutter_blue_plus (BLE), wifi_iot (Wi-Fi)

---

## Важные технические детали

### Синхронизация с Яндекс.Диск

**OAuth2 авторизация:**
- Android: Deep link (mycactus://callback)
- Windows: Локальный сервер (localhost:8080)
- Client ID: 066c5dd1fda94c15ac2dc248cdb0f1e8
- Client Secret: c624749917a34e6a8579e5ff2685f0f7
- Redirect URI: mycactus://callback

**Структура папок:**
```
/MyCactus/
├── plant_provider.json
└── photos/
```

**Логика синхронизации:**
1. Сравнение lastLocalUpdate и lastCloudUpdate
2. Допуск: 2 секунды
3. Если облако новее → загрузка из облака
4. Если локально новее → загрузка в облако
5. Автоматическое создание бэкапа

**Проблемы и решения:**
- BadPaddingException после пересборки APK → автоматическая очистка токенов
- Дубликаты фото → UUID именование
- Race conditions → флаг _isEnsuringPhotos

---

### Система уведомлений

**Инициализация:**
- Android: @mipmap/ic_launcher
- Windows: auto
- Разрешения: Android 13+

**Текущая логика:**
- Проверка рекомендованных дат полива
- Установка флага hasUnreadNotification
- Базовые уведомления

---

### Хранение фото

**Android:**
- Путь: /data/user/0/com.example.cactus/files/plant_photos/
- Миграция из старых путей

**Windows:**
- Путь: %APPDATA%/plant_photos/

**Облачные фото:**
- Загрузка на Яндекс.Диск
- Замена локальных путей на cloud URLs
- Валидация доступности

---

### Система партий (сеянцы)

**Концепция:**
- Витрина-партия (isBatch = true)
- Сеянцы (parentId != null)
- childrenIds - список ID сеянцев
- parentId - ID витрины
- aliveCount - количество живых сеянцев

**Генерация ID:**
- Витрина: "24-001" или "K24-001"
- Сеянцы: "24-001-1", "24-001-2"

---

## Ошибки и решения

### BadPaddingException после пересборки APK

**Проблема:**
После пересборки APK токены в FlutterSecureStorage становятся недоступными (BadPaddingException).

**Решение:**
Автоматическая очистка токенов при первой ошибке BadPaddingException (один раз после пересборки).

**Код:**
```dart
if (e.toString().contains('BadPaddingException') || e.toString().contains('BAD_DECRYPT')) {
  final alreadyCleaned = prefs.getBool('tokens_cleaned_after_rebuild') ?? false;
  if (!alreadyCleaned) {
    await _storage.deleteAll();
    await prefs.setBool('tokens_cleaned_after_rebuild', true);
  }
}
```

---

### Дубликаты фото в облаке

**Проблема:**
При загрузке фото с одинаковыми именами создаются дубликаты.

**Решение:**
UUID именование файлов: `{uuid}_{original_name}`.

**Код:**
```dart
final uuid = const Uuid();
final originalName = path.basename(filePath);
final fileName = '${uuid.v4()}_$originalName';
```

---

### Race conditions при синхронизации фото

**Проблема:**
Одновременные запросы на синхронизацию фото.

**Решение:**
Флаг _isEnsuringPhotos для защиты от race conditions.

---

## План миграции данных

### От SharedPreferences к БД

**Шаг 1: Подготовка**
- Создание схемы БД
- Создание DatabaseProvider
- Создание репозиториев

**Шаг 2: Миграция**
- Чтение данных из SharedPreferences
- Преобразование в новые модели
- Запись в БД
- Создание бэкапа

**Шаг 3: Валидация**
- Проверка целостности данных
- Сравнение количества записей
- Тестирование функциональности

**Шаг 4: Переключение**
- Обновление провайдеров
- Обновление UI
- Удаление старого кода

**Шаг 5: Мониторинг**
- Наблюдение за ошибками
- Обратная связь от пользователей

---

### От Plant к новым моделям

**Шаг 1: Создание новых моделей**
- SpeciesTemplate
- PlantInstance
- CareLog
- EnvironmentSnapshot
- CalibrationHistory

**Шаг 2: Миграция данных**
- Разделение Plant на SpeciesTemplate и PlantInstance
- Создание CareLog из wateringDates
- Создание EnvironmentSnapshot (если есть данные)
- Создание CalibrationHistory (пустой)

**Шаг 3: Обновление связей**
- Связь PlantInstance → SpeciesTemplate
- Связь PlantInstance → CareLog
- Связь PlantInstance → EnvironmentSnapshot
- Связь PlantInstance → CalibrationHistory

**Шаг 4: Обновление кода**
- Провайдеры
- Экраны
- Утилиты

**Шаг 5: Тестирование**
- Все функции
- Производительность
- Целостность данных

---

## Производительность

### Текущие проблемы

**SharedPreferences:**
- Медленно при большом количестве растений (>1000)
- Нет индексов
- Нет кэширования

**Решения:**
- Кэширование данных в памяти
- Ленивая загрузка
- Пагинация

### Целевые решения

**SQLite/Realm:**
- Индексы
- Транзакции
- Оптимизированные запросы
- Кэширование

---

## Безопасность

### Текущие меры

- Токены в FlutterSecureStorage
- OAuth2 для Яндекс.Диска
- Локальное хранение данных

### Целевые меры

- Шифрование БД (опционально)
- Биометрическая аутентификация (опционально)
- Безопасный экспорт/импорт

---

## Кроссплатформенность

### Android

**Особенности:**
- Deep link для OAuth2
- Разрешения уведомлений (Android 13+)
- Хранение фото: /data/user/0/
- image_picker, image_cropper

### Windows

**Особенности:**
- Локальный сервер для OAuth2 (localhost:8080)
- Уведомления работают сразу
- Хранение фото: %APPDATA%
- MSIX packaging

### Общие

**Решения:**
- Условная компиляция (Platform.isAndroid, Platform.isWindows)
- Абстракция платформозависимого кода
- Общие интерфейсы

---

## Тестирование

### Текущее тестирование

- Ручное тестирование
- Базовое тестирование на Android и Windows

### Целевое тестирование

- Unit тесты для бизнес-логики
- Integration тесты для провайдеров
- Widget тесты для UI
- E2E тесты для критических путей
- Performance тесты для БД
- Миграционные тесты

---

## Логирование

### Текущее логирование

- Console logging
- Подробные логи всех операций

### Целевое логирование

- Структурированное логирование
- Уровни логирования (debug, info, warning, error)
- Логи в файл (опционально)
- Crash reporting (опционально)

---

## Мониторинг

### Текущий мониторинг

- Нет

### Целевой мониторинг

- Аналитика использования (опционально)
- Crash reporting (опционально)
- Performance monitoring (опционально)

---

## Резервные планы

### Если миграция данных не удастся

- Оставить SharedPreferences для текущих данных
- Внедрить БД только для новых функций
- Гибридный подход

### Если автокалибровка нестабильна

- Отключить по умолчанию
- Добавить ручную калибровку
- Ограничить корректировки

### Если датчики проблемные

- Оставить только ручной ввод
- Отложить интеграцию датчиков
- Добавить позже как опцию

---

## Ссылки на ключевые ресурсы

### Документация
- Flutter: https://flutter.dev/docs
- Provider: https://pub.dev/packages/provider
- SQLite: https://pub.dev/packages/sqflite
- Realm: https://pub.dev/packages/realm
- WatermelonDB: https://pub.dev/packages/watermelondb

### API
- GBIF: https://api.gbif.org/v1/
- Llifle: https://llifle.net/
- Яндекс.Диск: https://cloud-api.yandex.net/v1/disk/

### Инструменты
- Pandoc: https://pandoc.org/
- Word COM automation (для конвертации .docx)

---

## История изменений

**2026-05-09**
- Создан файл 04-TECHNICAL_NOTES.md
- Документирована текущая архитектура
- Документированы решения для миграции
- Добавлены планы для тестирования и мониторинга
