--- ANALYSIS_FULL.md (原始)


+++ ANALYSIS_FULL.md (修改后)
# ПОЛНЫЙ ГЛУБОКИЙ АНАЛИЗ ПРОЕКТОВ MY CACTUS

## ОБЩАЯ ИНФОРМАЦИЯ

**Проекты:** My Cactus - каталогизатор коллекции кактусов
**Платформы:** Windows (версия 1.0.0+1) и Android (версия 1.0.1+1)
**Фреймворк:** Flutter (Dart)
**Статус:** Полностью работоспособные приложения с синхронизацией через Яндекс.Диск

---

## 1. АРХИТЕКТУРА ПРИЛОЖЕНИЯ

### 1.1 Архитектурный паттерн
Приложения используют **Provider-based архитектуру** с элементами MVVM:
- **Model:** `Plant`, `GerminationRecord`, `FloweringRecord`, `Note`, `GbifOccurrence`
- **View:** Все экраны в `/screens/` и виджеты в `/widgets/`
- **ViewModel:** `PlantProvider`, `CloudStorageProvider` (ChangeNotifier)

### 1.2 Структура проекта (общая для обеих платформ)
```
lib/
├── main.dart                    # Точка входа, инициализация, роутинг
├── constants/
│   └── app_constants.dart       # Константы (ключи SharedPreferences, статусы)
├── models/
│   └── plant.dart               # Основная модель + вспомогательные классы
├── providers/
│   ├── plant_provider.dart      # Управление состоянием растений
│   └── cloud_storage_provider.dart # Синхронизация с облаком
├── screens/                     # 12 экранов приложения
├── widgets/                     # Переиспользуемые виджеты
├── utils/                       # Утилиты (GBIF, Llifle, погода)
└── theme/                       # Темы оформления
```

### 1.3 Поток данных
1. **Загрузка:** SharedPreferences → PlantProvider.loadPlants() → _plants → UI
2. **Сохранение:** UI → PlantProvider.savePlants() → SharedPreferences
3. **Синхронизация:** CloudStorageProvider.syncData() ↔ Яндекс.Диск

---

## 2. МОДЕЛЬ ДАННЫХ (plant.dart)

### 2.1 Класс Plant - центральная модель
**54 поля**, включая:

**Идентификация:**
- `permanentId` (UUID) - уникальный ID, никогда не меняется
- `displayId` - отображаемый ID ("24-001", "K24-001", "24-001-1" для сеянцев)
- `lastModified` - timestamp последнего изменения (для синхронизации)

**Основная информация:**
- `latinName`, `status`, `year`, `customNumber`, `category`
- `country`, `habitat`, `description`, `synonyms`, `careTips`, `floweringPeriod`
- `fieldNumber`, `seller`, `harvestYear`, `seedsCount`, `germinatedCount`

**Уход:**
- `wateringDates`, `customWateringDates` - история поливов
- `lastFertilization`, `plannedFertilizationDate` - подкормки
- `lastRepotting`, `plannedTransplantDate` - пересадки

**Медиа:**
- `userPhotos` - загруженные пользователем фото (локальные пути или cloud URLs)
- `lliflePhotoUrls` - фото из Llifle
- `gbifPhotoUrls` - фото из GBIF

**Система партий (сеянцы):**
- `isBatch` - true если это витрина-партия
- `parentId` - ID витрины для сеянца
- `childrenIds` - список ID сеянцев для витрины
- `aliveCount` - количество живых сеянцев (ручное или авторасчёт)

**Внешние данные:**
- `gbifOccurrences` - данные о местообитаниях из GBIF
- `lastGbifUpdate` - последнее обновление GBIF

**Вспомогательные классы:**
- `GerminationRecord` - запись о всхожести (date, germinatedCount, deadCount)
- `FloweringRecord` - запись о цветении (date, event)
- `Note` - заметка (id, title, text, createdAt)
- `GbifOccurrence` - координаты, страна, локалитет из GBIF
- `WinteringLogEntry` - запись журнала зимовки

### 2.2 Сериализация
- `toJson()` / `fromJson()` - полная сериализация в JSON
- Обратная совместимость при добавлении новых полей
- Обработка разных форматов статусов (русский/английский)

---

## 3. ПРОВАЙДЕРЫ (State Management)

### 3.1 PlantProvider (2230 строк)

**Основные данные:**
- `_plants: List<Plant>` - основной список
- `_hasUnsavedChanges: bool` - флаг изменений
- `_selectedIds: Set<String>` - выбранные растения для массовых операций
- `_lastLocalUpdate: DateTime?` - метка времени для синхронизации

**Кэширование (для производительности):**
- `_individualWateringDatesCache` - растения по датам полива
- `_customWateringDatesCache` - кастомные поливы
- `_recommendedWateringDatesCache` - рекомендованные поливы
- `_fertilizationDatesCache` - даты подкормок
- Методы `invalidate*Cache()` для сброса

**Система фото:**
- `_needsPhotoSync: bool` - флаг синхронизации фото
- `_deletedUserPhotos`, `_deletedLliflePhotos` - отслеживание удалений
- Методы: `markNeedsPhotoSync()`, `ensureLocalPhotosExist()`, `cleanupLocalPhotosAfterCloudLoad()`

**Зимовка:**
- `_winteringStartDate`, `_winteringEndDate`, `_winteringTemperature`
- `_winteringLogEntries: List<WinteringLogEntry>`
- Геттеры/сеттеры с автосохранением

**Ключевые методы:**
- CRUD: `addPlant()`, `updatePlant()`, `deletePlant()`
- Массовые операции: `updateMultipleStatus()`, `deleteMultiplePlants()`
- Экспорт: `exportSelectedToCSV()`
- Уведомления: `checkWateringNotifications()`, `scheduleDailyWeatherCheck()`
- Бэкап: `createLocalBackup()` перед критическими операциями
- Синхронизация: `loadFromCloudJson()`

### 3.2 CloudStorageProvider (736 строк)

**OAuth2 конфигурация Яндекс.Диска:**
- Client ID: `066c5dd1fda94c15ac2dc248cdb0f1e8`
- Scopes: `cloud_api:disk.read`, `cloud_api:disk.write`
- Папки: `/MyCactus/`, `/MyCactus/photos/`

**Платформенно-специфичная авторизация:**

**Windows:**
- `_startLocalServer()` - HTTP сервер на localhost:8080
- Перехват callback с кодом авторизации
- `connectToYandexDisk()` - стандартный OAuth2 flow

**Android:**
- Deep link: `mycactus://callback`
- `handleDeepLink(Uri uri)` - обработка из MainActivity
- Platform channel: `MethodChannel('deep_link')`
- `_currentGrant` - сохранение состояния авторизации

**Синхронизация:**
1. `fetchLastCloudUpdate()` - получение даты из облака
2. `syncData()` - сравнение `_lastLocalUpdate` vs `_lastCloudUpdate`
3. `_uploadToCloud()` - загрузка plant_provider.json + фото
4. `loadDataFromCloud()` - загрузка + `ensureLocalPhotosExist()`

**Конфликт-резолюшн:**
- Допуск 2 секунды
- Приоритет более новой версии
- Автоматический бэкап перед загрузкой из облака

**Синхронизация фото:**
- Загрузка локальных фото в облако с UUID именами
- Замена локальных путей на cloud URLs
- Валидация доступности URLs
- `_syncDeletedPhotos()` - удаление из облака помеченных фото

---

## 4. ЭКРАНЫ И ФУНКЦИОНАЛЬНОСТЬ

### 4.1 WelcomeScreen
- Первый запуск, онбординг
- Авторизация в Яндекс.Диск
- Checkbox "Запомнить меня" → автосинхронизация при старте
- Флаг `has_seen_welcome` в SharedPreferences

### 4.2 HomeScreen (главный экран)
**Статистика:**
- Карточки: Всего, В коллекции, Выращено из семян, Купленные, Сеянцы, Партий
- onTapFilter - фильтрация по клику

**Поиск и сортировка:**
- Поиск по latinName, displayId, году
- Сортировка: название, статус, год, категория
- Ascending/descending

**Массовые операции:**
- Чекбоксы для выбора
- Меню: удалить старые фото, удалить все фото, изменить статус/категорию

**Сезонный совет:**
- `_getSeasonalTip()` - советы по месяцам
- Кэширование при изменении месяца/состава коллекции

**Погода:**
- Кнопка вызова WeatherService
- Советы по поливу на основе погоды

### 4.3 PlantCardScreen (104KB - самый большой файл)
**Вкладки:**
1. **Основное:** Вся информация, фото GBIF/Llifle, кнопка парсинга
2. **Уход:** История полива/подкормок/пересадок, рекомендации, погодные советы
3. **Галерея:** Добавление/удаление фото, загрузка с устройства
4. **Заметки:** Список заметок, добавление/редактирование/удаление
5. **Карта:** flutter_map с маркерами GBIF occurrences
6. **Сеянцы:** Только если isBatch=true, список детей

**Функции:**
- Отметка полива ("Полить сейчас")
- Парсинг Llifle/GBIF прямо из карточки
- Редактирование через EditPlantScreen
- Индикатор уведомления о поливе

### 4.4 EditPlantScreen
**Автозаполнение:**
- Кнопка "Парсинг Llifle" - fetchPlantData() из llifle_utils.dart
- Кнопка "Поиск GBIF" - fetchGbifData() из gbif_utils.dart
- Кэширование результатов в SharedPreferences

**Валидация:**
- Проверка уникальности номера (`isNumberUnique()`)
- Автогенерация следующего номера

**Флаги стран:**
- REST Countries API
- Кэширование URL флагов

### 4.5 CollectionManagementScreen
**Фильтры:**
- По статусу, категории, году
- "Только без QR кодов" (запланировано)

**Массовые операции:**
- Изменение статуса/категории
- Удаление
- Экспорт в CSV

### 4.6 CareCalendarScreen
**Отображение:**
- TableCalendar widget
- Глобальные даты полива
- Индивидуальные даты (на растение)
- Кастомные даты (пользовательские)
- Рекомендованные даты (расчетные)
- Подкормки (фактические и плановые)

**Интерактивность:**
- Клик на дату → показать растения
- Клик на растение → отметить полив

### 4.7 StatisticsScreen (53KB)
**Графики (Syncfusion Charts):**
- Распределение по статусам (pie chart)
- Распределение по категориям (bar chart)
- Распределение по годам (line chart)
- Treemap коллекции

### 4.8 SowingManagementScreen
**Система партий:**
- Создание витрины (isBatch=true)
- Добавление сеянцев (parentId=vitrineId)
- Управление aliveCount (ручное или авто)
- История всхожести по годам

### 4.9 WinteringScreen
**Настройки:**
- Дата начала/окончания зимовки
- Температура зимовки
- Журнал записей

**Влияние:**
- Уменьшение частоты полива в период зимовки

---

## 5. УТИЛИТЫ

### 5.1 GBIF Utils (gbif_utils.dart)
**API:** https://api.gbif.org/v1/occurrence/search

**Функции:**
- `fetchGbifData(latinName)` - основной метод
- `_fetchFromGbifApi()` - HTTP запрос с retry (3 попытки)
- `_parseGbifResponse()` - парсинг JSON ответа
- `getMostFrequentCountry()` - определение страны по majority vote
- `_createHabitatDescription()` - генерация описания ареала

**Кэширование:**
- Ключ: `gbif_data_{latinName}`
- Срок жизни: 7 дней
- Методы: `cacheGbifData()`, `getCachedGbifData()`, `clearGbifCache()`

**GbifOccurrence модель:**
- latitude, longitude, country, locality, habitat
- coordinateUncertainty, year, month, day
- `hasValidCoordinates` геттер

### 5.2 Llifle Utils (llifle_utils.dart)
**Парсинг HTML:**
- `fetchPlantData(latinName)` - поиск и парсинг
- `parseLlifleData(document)` - извлечение данных

**Извлекаемые данные:**
- Description (из `p.Description_Sheet_Description`)
- Habitat (из `p.Description_Sheet_Origin_and_Habitat`)
- CareTips (из `p.Description_Sheet_Cultivation_and_Propagation`)
- Synonyms (из `#short_synonyms_list ul`)
- Country (извлечение из списка стран в habitat)

**Фото:**
- Главное фото (#main_photo_container)
- Второстепенные (.secondary_photo_container)
- Миниатюры (#thumbnail_container)
- Альбомы (сканирование ссылок)

**Интеграция с GBIF:**
- Обогащение данных: приоритет GBIF для country
- Объединение habitat из обоих источников
- Добавление gbifPhotoUrls к lliflePhotoUrls

**Кэширование:**
- Ключ: `plant_data_{latinName}`
- Бессрочное (до ручного обновления)

### 5.3 Weather Service (weather_service.dart)
**API:** OpenWeatherMap (apikey: 7fd64eefdd81d17943bbcd4e17a87e5d)

**Методы:**
- `getCurrentLocation()` - Geolocator для GPS координат
- `getCurrentWeather(lat, lon)` - погода по координатам
- `getWeatherByCity(city)` - погода по городу
- `getWateringAdvice(weather, plant)` - советы по поливу
- `formatWeather(weather)` - форматирование для отображения

**Кэширование:**
- Срок жизни: 1 час
- Ключи: `weather_cache`, `weather_cache_time`

**Логика советов:**
- Дождь или влажность >60% (70% для purchased) → отложить полив
- Температура >25°C и влажность <40% → проверить почву
- Температура <10°C → сократить поливы

### 5.4 Translation Utils
**Перевод интерфейса:**
- Поддержка русского и английского
- Методы для перевода статусов, категорий

### 5.5 Responsive Helper
**Определение типа устройства:**
- `isMobile(context)` - ширина <600
- `isDesktop(context)` - ширина >=600
- Адаптивные отступы

---

## 6. ТЕМА ОФОРМЛЕНИЯ (cactus_theme.dart)

### 6.1 Цветовая палитра
**Light тема:**
- Primary: #4A7043 (спокойный зелёный)
- Accent: #B36A4E (приглушённая терракота)
- Background: #FBF7F2 (очень светлый)
- Surface: #F5EDE4 (светлый песок)

**Dark тема:**
- Primary: #2E4A2B
- Accent: #9A5A40
- Background: #1F1F1F
- Surface: #2A2A2A

### 6.2 Компоненты темы
- AppBarTheme - зелёный фон, белые иконки
- CardTheme - elevation 3, borderRadius 16
- ChipTheme - песочный фон
- ElevatedButtonTheme - зелёные кнопки
- InputDecorationTheme - скруглённые поля

---

## 7. СИСТЕМА УВЕДОМЛЕНИЙ

### 7.1 Инициализация (main.dart)
```dart
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin
AndroidInitializationSettings('@mipmap/ic_launcher')
requestNotificationsPermission() для Android 13+
```

### 7.2 Логика уведомлений о поливе
**PlantProvider.checkWateringNotifications():**
- Расчет следующей даты полива для каждого растения
- Сравнение с текущей датой
- Установка `hasUnreadNotification = true`
- Отображение индикатора на карточке

### 7.3 Ежедневная проверка погоды
**scheduleDailyWeatherCheck():**
- timezone package для локального времени
- Ежедневно в 8:00
- Уведомление с прогнозом погоды

---

## 8. ХРАНЕНИЕ ДАННЫХ

### 8.1 SharedPreferences
**Ключи (app_constants.dart):**
- `plants` - JSON список всех растений
- `global_watering_dates` - глобальные даты полива
- `adult_images` - маппинг растение→фото взрослого
- `wintering_start_date`, `wintering_end_date`, `wintering_temperature`
- `wintering_log_entries` - журнал зимовки
- `last_local_update` - метка времени синхронизации
- `remember_me`, `has_seen_welcome` - настройки
- `cloud_storage_type` - тип облака
- `tokens_cleaned_after_rebuild` - флаг очистки токенов
- `gbif_data_*`, `plant_data_*` - кэши парсинга
- `weather_cache` - кэш погоды

**Ограничения:**
- Размер ~несколько МБ
- Нет транзакций
- Нет сложных запросов
- Медленно при 1000+ растениях

### 8.2 FlutterSecureStorage
**Токены Яндекс.Диска:**
- `yandex_access_token`
- `yandex_refresh_token`

**Защита от BadPaddingException:**
- Очистка при обнаружении повреждённых токенов
- Флаг `tokens_cleaned_after_rebuild` для однократной очистки

### 8.3 Локальное хранение фото
**Пути:**
- Windows: `%APPDATA%/plant_photos/`
- Android: `/data/user/0/com.example.my_cactus/files/plant_photos/`

**Миграция:**
- `migrateExistingPhotos()` - копирование старых фото в новую папку
- Проверка существования файлов

---

## 9. СИНХРОНИЗАЦИЯ С ЯНДЕКС.ДИСКОМ

### 9.1 OAuth2 Flow

**Windows:**
1. `connectToYandexDisk()` → AuthorizationCodeGrant
2. Открытие браузера на https://oauth.yandex.com/authorize
3. Пользователь авторизуется
4. Редирект на http://localhost:8080?code=XXX
5. `_startLocalServer()` перехватывает код
6. `handleYandexCallback()` обменивает код на токены
7. Сохранение в FlutterSecureStorage

**Android:**
1. `connectToYandexDisk()` → AuthorizationCodeGrant
2. Redirect URI: `mycactus://callback`
3. Редирект на mycactus://callback?code=XXX
4. MainActivity.onNewIntent() получает intent
5. MethodChannel('deep_link') отправляет в Dart
6. `handleDeepLink()` обрабатывает URI
7. `handleYandexCallback()` обменивает код на токены

### 9.2 Структура на Яндекс.Диске
```
/MyCactus/
├── plant_provider.json    # Все данные (растения, настройки, зимовка)
└── photos/                # Фото пользователей
    ├── {uuid}_{filename}.jpg
    └── ...
```

### 9.3 Алгоритм синхронизации
**syncData():**
1. `fetchLastCloudUpdate()` - получить дату файла из облака
2. Сравнить `_lastLocalUpdate` и `_lastCloudUpdate`
3. Если облако новее (с допуском 2 сек):
   - `createLocalBackup()`
   - `loadDataFromCloud()`
   - `savePlants()`
4. Если локально новее:
   - `_uploadToCloud()`
5. Если локально пусто:
   - `loadDataFromCloud()`

**_uploadToCloud():**
1. Установить `_lastLocalUpdate = DateTime.now().toUtc()`
2. Сериализовать PlantProvider в JSON
3. Получить upload URL от Яндекс.Диска
4. PUT запрос с данными
5. `syncUserPhotos()` - загрузка фото

**loadDataFromCloud():**
1. `createLocalBackup()`
2. Скачать plant_provider.json
3. `loadFromCloudJson(data)` - десериализация
4. `ensureLocalPhotosExist()` - скачать фото локально
5. `cleanupLocalPhotosAfterCloudLoad()` - удалить лишнее
6. `_cleanDuplicatePhotos()` - убрать дубликаты

### 9.4 Синхронизация фото
**syncUserPhotos():**
1. Для каждого растения:
   - Найти локальные фото (не начинающиеся с https://)
   - Пропустить пути другой платформы (C:\Users, /data/user/)
   - Для каждого локального фото:
     - `uploadPhotoToYandexDisk()` - загрузить в облако
     - Заменить локальный путь на cloud URL
2. `_syncDeletedPhotos()` - удалить помеченные фото из облака

**uploadPhotoToYandexDisk():**
- UUID + оригинальное имя для уникальности
- Папка /MyCactus/photos/
- Публикация файла (public URL)
- Возврат public URL

**ensureLocalPhotosExist():**
- Для каждого cloud URL в растениях:
  - Если файл не существует локально:
    - Скачать из облака
    - Сохранить в локальную папку
    - Заменить URL на локальный путь

---

## 10. ПЛАТФОРМЕННЫЕ РАЗЛИЧИЯ

### 10.1 pubspec.yaml различия

**Android только:**
- `image_picker: ^1.1.2` - выбор фото из галереи/камеры
- `image_cropper: ^12.2.0` - обрезка фото

**Windows только:**
- `file_picker: ^10.1.9` - выбор файлов (для импорта/экспорта)
- `excel: ^4.0.6` - экспорт в Excel (CSV тоже)
- Конфигурация MSIX для установки

### 10.2 main.dart различия

**Windows:**
```dart
const bool isRelease = bool.fromEnvironment('dart.vm.product');
if (isRelease) {
  await _cleanAppData();  // Очистка данных в релизе
}
```

**Android:**
```dart
// Обработка deep links
if (Platform.isAndroid) {
  const deepLinkChannel = MethodChannel('deep_link');
  deepLinkChannel.setMethodCallHandler((call) async {
    if (call.method == 'deepLink') {
      final String? url = call.arguments as String?;
      // Обработка mycactus://callback
      await cloudProvider.handleDeepLink(uri);
    }
  });
}

// Глобальный обработчик ошибок
FlutterError.onError = (FlutterErrorDetails details) {
  FlutterError.presentError(details);
  print('=== FLUTTER ERROR ===');
  print(details.exception);
  print(details.stack);
};
```

### 10.3 cloud_storage_provider.dart различия

**Android:**
- `handleDeepLink(Uri uri)` - обработка callback от Яндекс.Диска
- `_currentGrant` - сохранение grant между перезапусками
- Защита от BadPaddingException после пересборки APK
- Redirect URI: `mycactus://callback`

**Windows:**
- `_startLocalServer()` - HTTP сервер на localhost:8080
- Redirect URI: `http://localhost:8080`
- Нет обработки deep links

### 10.4 Android специфичные файлы

**MainActivity.kt:**
```kotlin
override fun onNewIntent(intent: Intent) {
  super.onNewIntent(intent)
  setIntent(intent)
  val data = intent.dataString
  if (data != null && data.startsWith("mycactus://")) {
    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
      val channel = MethodChannel(messenger, "deep_link")
      channel.invokeMethod("deepLink", data)
    }
  }
}
```

**AndroidManifest.xml:**
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="mycactus" />
</intent-filter>
```

**Разрешения:**
- INTERNET
- ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION
- POST_NOTIFICATIONS (Android 13+)
- CAMERA

### 10.5 Windows специфичные файлы

**win32_window.cpp:**
- Dark mode поддержка через DWMWA_USE_IMMERSIVE_DARK_MODE
- DPI scaling
- Window class регистрация

**msix_config.yaml:**
- Display name, publisher, identity
- Certificate для подписи
- Capabilities: internetClient, privateNetworkClientServer

---

## 11. ФУНКЦИИ И ФИЧИ

### 11.1 Реализованные функции

**Управление растениями:**
- ✅ Добавление/редактирование/удаление
- ✅ Статусы: sown, growing, in_collection, dead, failed
- ✅ Категории: sown, purchased
- ✅ Автогенерация ID с проверкой уникальности
- ✅ Массовые операции (статус, категория, удаление)

**Парсинг данных:**
- ✅ Llifle - описание, habitat, careTips, synonyms, фото
- ✅ GBIF - occurrence данные, фото, страна, habitat
- ✅ Кэширование результатов
- ✅ REST Countries API для флагов

**Уход:**
- ✅ Глобальные даты полива
- ✅ Индивидуальные даты полива на растение
- ✅ Кастомные даты полива
- ✅ Рекомендованные даты (расчетные)
- ✅ Подкормки (фактические и плановые)
- ✅ Пересадки (последняя и плановая)
- ✅ Календарь ухода (table_calendar)

**Зимовка:**
- ✅ Настройка периода зимовки
- ✅ Температура зимовки
- ✅ Журнал записей
- ✅ Влияние на график полива

**Система партий (сеянцы):**
- ✅ Витрины-партии (isBatch=true)
- ✅ Сеянцы с parentId
- ✅ childrenIds список
- ✅ aliveCount (ручной или авторасчет)
- ✅ Генерация ID сеянцев (24-001-1, 24-001-2)
- ✅ История всхожести по годам
- ✅ График всхожести

**Фото:**
- ✅ Загрузка с устройства
- ✅ Галерея с просмотром
- ✅ Несколько фото на растение
- ✅ Фото из Llifle/GBIF
- ✅ Синхронизация с облаком
- ✅ Удаление старых/всех фото
- ✅ Отображение взрослых растений

**Заметки:**
- ✅ Добавление/редактирование/удаление
- ✅ Список заметок в карточке
- ✅ Bottom sheet для ввода

**Карта:**
- ✅ flutter_map с OpenStreetMap
- ✅ Маркеры GBIF occurrences
- ✅ Отображение координат, страны, локалитета

**Уведомления:**
- ✅ О поливе (по рекомендованным датам)
- ✅ Индикатор на карточке растения
- ✅ Ежедневная проверка погоды (8:00)
- ✅ Разрешения Android 13+

**Погода:**
- ✅ Геолокация (Geolocator)
- ✅ OpenWeatherMap API
- ✅ Советы по поливу на основе погоды
- ✅ Кэширование (1 час)

**Синхронизация:**
- ✅ Яндекс.Диск OAuth2
- ✅ Автосинхронизация при старте (если "Запомнить меня")
- ✅ Ручная синхронизация
- ✅ Конфликт-резолюшн по timestamp
- ✅ Синхронизация фото
- ✅ Бэкап перед загрузкой из облака

**Экспорт:**
- ✅ CSV экспорт выбранных растений

**Поиск и фильтрация:**
- ✅ Поиск по названию, ID, году
- ✅ Фильтры по статусу, категории
- ✅ Сортировка по различным полям
- ✅ Сезонные советы

**Темы:**
- ✅ Light/Dark тема
- ✅ System theme mode
- ✅ Кактусовая цветовая палитра

### 11.2 Запланированные функции (из ROADMAP)

**QR-коды (этап 1.1):**
- Генерация QR-кодов с ID и названием
- Массовое создание для выбранных растений
- PDF для печати (А4, А3, размеры этикеток)
- Экран управления QR-кодами
- Сканирование QR-кодов (Android)
- Фильтрация по отсканированному QR

**Не реализовано из "идеальной" архитектуры:**
- ❌ Адаптивный график ухода (только фиксированный)
- ❌ Машина состояний растения (фазы: Dormant, ActiveGrowth и т.д.)
- ❌ Индекс готовности к поливу
- ❌ Автокалибровка на основе истории
- ❌ Структурированная система здоровья (симптомы, гипотезы, лечение)
- ❌ QR-этикетки (в процессе)
- ❌ Фото-сравнение с метаданными
- ❌ Карта теплицы с локациями
- ❌ EnvironmentSnapshot (температура, влажность, свет)
- ❌ CalibrationHistory
- ❌ SpeciesTemplate (отдельная модель вида)

---

## 12. ОРГАНИЗАЦИЯ СИНХРОНИЗАЦИИ И СОХРАНЕНИЯ

### 12.1 Локальное сохранение

**PlantProvider.savePlants():**
```dart
1. Проверка _hasUnsavedChanges
2. createLocalBackup() - бэкап перед сохранением
3. Сериализация растений в JSON
4. Запись в SharedPreferences (ключ: 'plants')
5. Сохранение adult_images
6. Установка _lastLocalUpdate = DateTime.now()
7. Сохранение данных зимовки
8. Сброс _hasUnsavedChanges = false
9. notifyListeners()
```

**Триггеры сохранения:**
- Добавление/обновление/удаление растения
- Изменение дат полива
- Изменение настроек зимовки
- Изменение adult images
- Массовые операции

### 12.2 Облачная синхронизация

**Автосинхронизация при старте (main.dart):**
```dart
_syncData(plantProvider, cloudProvider):
1. loadPlants() - загрузка локальных данных
2. Если нет подключения к облаку → выход
3. fetchLastCloudUpdate() - дата из облака
4. Сравнение localUpdate и cloudUpdate:
   - Если оба пусты → выход
   - Если локально пусто → загрузка из облака
   - Если облако новее → загрузка из облака
   - Если локально новее → загрузка в облако
   - Иначе → данные синхронизированы
```

**Ручная синхронизация:**
- Кнопка на главном экране (если подключено облако)
- Вызывает cloudProvider.syncData()

### 12.3 Межплатформенная синхронизация

**Механизм:**
1. **Общий формат данных:** JSON сериализация идентична на обеих платформах
2. **Облако как посредник:** Данные синхронизируются через Яндекс.Диск
3. **Timestamp-based резолюшн:** lastLocalUpdate сравнивается с lastCloudUpdate
4. **Фото конвертация:** При загрузке из облака URLs заменяются на локальные пути

**Поток синхронизации Windows → Android:**
```
Windows:
1. Изменение растения → savePlants() → _lastLocalUpdate обновляется
2. syncData() → _uploadToCloud() → plant_provider.json на Яндекс.Диск
3. syncUserPhotos() → загрузка фото в /MyCactus/photos/

Android:
1. При старте или вручную → syncData()
2. fetchLastCloudUpdate() → cloudUpdate новее localUpdate
3. loadDataFromCloud() → скачивание plant_provider.json
4. loadFromCloudJson() → десериализация в Plant объекты
5. ensureLocalPhotosExist() → скачивание фото из облака в локальную папку
6. Замена cloud URLs на локальные пути в userPhotos
```

**Поток синхронизации Android → Windows:**
```
Аналогично, но в обратном направлении:
1. Android загружает фото в облако
2. Windows скачивает plant_provider.json
3. Windows скачивает фото из облака в %APPDATA%/plant_photos/
4. Замена URLs на локальные пути Windows
```

**Обработка конфликтов:**
- Допуск 2 секунды (timeTolerance)
- Если cloudUpdate > localUpdate + 2sec → загрузка из облака
- Если localUpdate > cloudUpdate + 2sec → загрузка в облако
- Автоматический бэкап перед загрузкой из облака

**Специфичные данные платформ:**
- Пути к фото разные, но конвертируются при синхронизации
- Токены хранятся локально (не синхронизируются)
- Настройки (remember_me, has_seen_welcome) локальные

---

## 13. ЗАВИСИМОСТИ (pubspec.yaml)

### 13.1 Основные зависимости (общие)
```yaml
flutter: sdk: flutter
provider: ^6.1.1              # State management
shared_preferences: ^2.5.2    # Локальное хранение
flutter_secure_storage: ^9.2.2 # Токены
```

### 13.2 Сеть и OAuth2
```yaml
http: ^1.3.0                  # HTTP запросы
dio: ^5.7.0                   # Продвинутый HTTP клиент
oauth2: ^2.0.2                # OAuth2 авторизация
url_launcher: ^6.2.0          # Открытие URL
```

### 13.3 UI компоненты
```yaml
syncfusion_flutter_charts: ^29.2.9   # Графики
syncfusion_flutter_treemap: ^29.2.9  # Treemap
table_calendar: ^3.0.9               # Календарь
flutter_map: ^6.1.0                  # Интерактивная карта
latlong2: ^0.9.1                     # Координаты для карты
cached_network_image: ^3.2.0         # Кэширование изображений
flutter_local_notifications: ^17.2.2 # Уведомления
```

### 13.4 Утилиты
```yaml
uuid: ^4.5.1                  # Генерация UUID
csv: ^6.0.0                   # CSV экспорт
path_provider: ^2.1.4         # Пути к файлам
path: ^1.8.3                  # Работа с путями
collection: ^1.19.1           # Утилиты коллекций
intl: ^0.20.2                 # Интернационализация
timezone: ^0.9.2              # Часовые пояса
html: ^0.15.5+1               # HTML парсинг
```

### 13.5 Платформенно-специфичные

**Android:**
```yaml
image_picker: ^1.1.2          # Выбор фото
image_cropper: ^12.2.0        # Обрезка фото
geolocator: ^11.0.1           # Геолокация
```

**Windows:**
```yaml
file_picker: ^10.1.9          # Выбор файлов
excel: ^4.0.6                 # Excel/CSV
msix: ^3.16.8                 # MSIX packaging
```

### 13.6 Dev зависимости
```yaml
flutter_test: sdk: flutter
flutter_lints: ^6.0.0
flutter_launcher_icons: ^0.14.3
```

---

## 14. ВЗАИМОСВЯЗИ МЕЖДУ ФАЙЛАМИ И МЕТОДАМИ

### 14.1 main.dart → Providers
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => PlantProvider()),
    ChangeNotifierProvider(create: (_) => CloudStorageProvider()),
  ],
  child: MaterialApp(...)
)
```

**Использование в экранах:**
```dart
final provider = context.watch<PlantProvider>();  // Для UI updates
final provider = context.read<PlantProvider>();   // Для действий
final provider = Provider.of<PlantProvider>(context, listen: false);
```

### 14.2 PlantProvider → Plant model
```dart
List<Plant> _plants;

void addPlant(Plant newPlant) {
  _plants.add(newPlant);
  savePlants();
}

void updatePlant(String id, Plant updatedPlant) {
  final index = _plants.indexWhere((p) => p.permanentId == id);
  _plants[index] = updatedPlant;
  savePlants();
}
```

### 14.3 PlantProvider → Utils
```dart
import '../utils/gbif_utils.dart';
import '../utils/llifle_utils.dart';
import '../utils/weather_service.dart';

Future<void> parseLlifleData() async {
  final data = await fetchPlantData(latinName);  // из llifle_utils
}

Future<void> searchGbif() async {
  final data = await fetchGbifData(latinName);   // из gbif_utils
}

String getWeatherAdvice() {
  return weatherService.getWateringAdvice(weather, plant);
}
```

### 14.4 CloudStorageProvider ↔ PlantProvider
```dart
// Загрузка из облака
await cloudProvider.loadDataFromCloud(plantProvider);
// Внутри loadDataFromCloud:
plantProvider.loadFromCloudJson(data);

// Синхронизация в облако
await cloudProvider.syncData(plantProvider);
// Внутри syncData:
final plantProviderData = utf8.encode(jsonEncode(plantProvider.toJson()));
```

### 14.5 Screens → Widgets
```dart
// PlantCards widget используется в HomeScreen
PlantCards(
  plants: filteredPlants,
  onPlantTap: (plant) => navigateToCard(plant),
)

// NotesBottomSheet в PlantCardScreen
showNotesBottomSheet(context, plant);

// ImageSelectionDialog при выборе фото
showImageSelectionDialog(context);
```

### 14.6 Utils → SharedPreferences
```dart
// gbif_utils.dart
Future<void> cacheGbifData(String latinName, Map<String, dynamic> data) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('gbif_data_$latinName', jsonEncode(data));
}

// llifle_utils.dart
Future<Map<String, dynamic>?> fetchPlantData(String latinName) async {
  final prefs = await SharedPreferences.getInstance();
  final cachedData = prefs.getString('plant_data_$searchName');
}
```

---

## 15. ТОЧКИ ВХОДА И ЖИЗНЕННЫЙ ЦИКЛ

### 15.1 Инициализация приложения (main())
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Очистка в релизе (Windows)
  if (isRelease) await _cleanAppData();

  // Инициализация уведомлений
  await _initNotifications();

  // Timezones
  tz.initializeTimeZones();

  // Запуск с Providers
  runApp(MultiProvider(...));
}
```

### 15.2 Инициализация MyApp
```dart
class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeAndCheckStatus(cloudProvider),
      builder: (context, snapshot) {
        // Загрузка credentials
        await cloudProvider.loadCredentials();

        // Проверка hasSeenWelcome, rememberMe

        // PostFrameCallback для синхронизации
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncData(plantProvider, cloudProvider);
        });

        return MaterialApp(home: showWelcomeScreen ? WelcomeScreen() : HomeScreen());
      }
    );
  }
}
```

### 15.3 Жизненный цикл экрана
```dart
class HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  void initState() {
    super.initState();
    context.read<PlantProvider>().loadPlants();
    if (widget.initialFilter != null) {
      // Применение фильтра
    }
  }

  void dispose() {
    _addController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
```

---

## 16. БЕЗОПАСНОСТЬ

### 16.1 Хранение токенов
- FlutterSecureStorage (AES шифрование)
- Access token + refresh token
- Автоматическое обновление токена через oauth2.Client

### 16.2 OAuth2 security
- Authorization Code Grant
- Client secret хранится в коде (не идеально, но приемлемо для desktop/mobile)
- Scopes ограничены: cloud_api:disk.read, cloud_api:disk.write

### 16.3 Защита данных
- Локальное хранение без шифрования (кроме токенов)
- HTTPS для всех API запросов
- Валидация cloud URLs перед использованием

### 16.4 Обработка ошибок
- Try-catch блоки во всех критических операциях
- Логирование ошибок
- Graceful degradation (работа офлайн при отсутствии облака)

---

## 17. ПРОИЗВОДИТЕЛЬНОСТЬ

### 17.1 Кэширование
- Dates watering кэшируются до изменения данных
- GBIF/Llifle данные кэшируются в SharedPreferences
- Weather кэшируется на 1 час
- Seasonal tips кэшируются по месяцу

### 17.2 Оптимизация рендеринга
- Consumer<PlantProvider> для точечных обновлений
- Provider.of(context, listen: false) когда не нужны обновления
- Кэширование виджетов где возможно

### 17.3 Проблемные места
- SharedPreferences при 1000+ растениях (медленная загрузка)
- Парсинг больших списков фото
- Синхронизация большого количества фото

---

## 18. ИЗВЕСТНЫЕ ПРОБЛЕМЫ И РЕШЕНИЯ

### 18.1 BadPaddingException на Android
**Проблема:** После пересборки APK токены не расшифровываются
**Решение:** Автоматическая очистка токенов при обнаружении ошибки + флаг tokens_cleaned_after_rebuild

### 18.2 Race conditions при синхронизации фото
**Проблема:** Несколько одновременных загрузок фото
**Решение:** Флаг _isEnsuringPhotos + проверка перед загрузкой

### 18.3 Дубликаты фото в облаке
**Проблема:** Одинаковые имена файлов
**Решение:** UUID + оригинальное имя ({uuid}_{filename})

### 18.4 Пути к фото на разных платформах
**Проблема:** Windows пути не работают на Android и наоборот
**Решение:** Проверка префиксов (C:\Users, /data/user/) и замена на локальные пути при синхронизации

---

## 19. ДОКУМЕНТАЦИЯ И ROADMAP

### 19.1 Файлы в /workspace/ROADMAP/
- **00-BASELINE.md** - Текущее состояние проекта
- **01-VISION.md** - Конечная цель и идеальная архитектура
- **02-IMPLEMENTATION_PLAN.md** - План реализации по этапам
- **03-CURRENT_STATUS.md** - Текущий прогресс
- **04-TECHNICAL_NOTES.md** - Технические заметки
- **LESSONS_LEARNED.md** - Ошибки и уроки
- **PROMPT.md** - Инструкция для AI помощника

### 19.2 Принципы проекта (/workspace/Принципы проекта/)
- Постепенное внедрение изменений
- Сохранение существующих функций
- Тестирование на обеих платформах
- Документирование всех изменений

---

## 20. ВЫВОДЫ

### 20.1 Сильные стороны
- ✅ Полностью рабочие кроссплатформенные приложения
- ✅ Надёжная синхронизация через Яндекс.Диск
- ✅ Богатый функционал (парсинг, уведомления, карта, статистика)
- ✅ Система партий сеянцев
- ✅ Кэширование для производительности
- ✅ Хорошая структура кода (providers, utils, screens)

### 20.2 Ограничения
- ⚠️ SharedPreferences не масштабируется на 1000+ растений
- ⚠️ Нет настоящей БД с транзакциями
- ⚠️ Простая система полива (не адаптивная)
- ⚠️ Нет структурированной системы здоровья
- ⚠️ Нет машины состояний растения

### 20.3 Архитектурные решения
- Provider pattern для state management
- JSON сериализация для хранения
- OAuth2 для авторизации
- Timestamp-based конфликт-резолюшн
- Platform channels для Android deep links

### 20.4 Платформенные особенности
- Windows: локальный сервер для OAuth, file_picker, Excel экспорт
- Android: deep links, image_picker, camera, геолокация

---

**Это полный, глубокий и подробный анализ обоих проектов. Код не изменялся, только анализ существующей реализации.**