# СОСТОЯНИЕ ДО РЕФАКТОРИНГА - MY CACTUS

**Дата создания:** 2026-05-09
**Статус:** Зафиксировано

---

## Связанные файлы

- [PROMPT.md](PROMPT.md) - инструкции для работы
- [CURRENT_STATUS.md](CURRENT_STATUS.md) - текущий статус
- [03-CURRENT_REFACTORING_STEP.md](03-CURRENT_REFACTORING_STEP.md) - текущий шаг
- [01-AFTER_REFACTORING.md](01-AFTER_REFACTORING.md) - состояние после рефакторинга
- [02-REFACTORING_PLAN.md](02-REFACTORING_PLAN.md) - план рефакторинга

---

## Общая информация

### Платформы
- **Android:** G:\cactus-project\Android
- **Windows:** G:\cactus-project\Windows
- **Фреймворк:** Flutter
- **Язык:** Dart

### Структура проекта (общая для обеих платформ)
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

---

## Архитектура

### Архитектурный паттерн
Provider-based архитектура с элементами MVVM:
- **Model:** `Plant`, `GerminationRecord`, `FloweringRecord`, `Note`, `GbifOccurrence`
- **View:** Все экраны в `/screens/` и виджеты в `/widgets/`
- **ViewModel:** `PlantProvider`, `CloudStorageProvider` (ChangeNotifier)

### Поток данных
1. **Загрузка:** SharedPreferences → PlantProvider.loadPlants() → _plants → UI
2. **Сохранение:** UI → PlantProvider.savePlants() → SharedPreferences
3. **Синхронизация:** CloudStorageProvider.syncData() ↔ Яндекс.Диск

---

## Модель данных (plant.dart)

### Класс Plant - центральная модель
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
- `QRCode` - QR код растения
- `QRCodeFile` - файл QR кодов для печати

---

## Провайдеры (State Management)

### PlantProvider (2230 строк)

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

### CloudStorageProvider (736 строк)

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

## Экраны и функциональность

### Список экранов
1. WelcomeScreen - первый запуск, онбординг, авторизация
2. HomeScreen - главный экран со статистикой и списком растений
3. PlantCardScreen - карточка растения с 6 вкладками
4. EditPlantScreen - редактирование растения
5. CollectionManagementScreen - управление коллекцией
6. CareCalendarScreen - календарь ухода
7. PlantStatisticsScreen - статистика с графиками
8. SowingManagementScreen - управление посевами
9. WinteringScreen - настройки зимовки
10. BatchQRCreationScreen - массовое создание QR кодов
11. QRManagementScreen - управление QR кодами
12. SelectPlantsForPrintScreen - выбор растений для печати
13. PrintSettingsScreen - настройки печати (А4, А3, размеры этикеток)
14. QRScannerScreen - сканирование QR кодов (только Android)
15. AddSowingYearScreen - добавление года посева
16. YearGerminationChartScreen - график всхожести по годам

### PlantCardScreen (104KB - самый большой файл)
**Вкладки:**
1. **Основное:** Вся информация, фото GBIF/Llifle, кнопка парсинга
2. **Уход:** История полива/подкормок/пересадок, рекомендации, погодные советы
3. **Галерея:** Добавление/удаление фото, загрузка с устройства
4. **Заметки:** Список заметок, добавление/редактирование/удаление
5. **Карта:** flutter_map с маркерами GBIF occurrences
6. **Сеянцы:** Только если isBatch=true, список детей

---

## Виджеты

### Переиспользуемые виджеты
- **image_selection_dialog.dart** - диалог выбора фото (камера/галерея)
- **notes_bottom_sheet.dart** - bottom sheet для добавления/редактирования заметок
- **plant_cards.dart** - карточки растений для списка
- **print_preview_widget.dart** - предпросмотр печати QR кодов
- **qr_code_widget.dart** - виджет для отображения QR кода

---

## Утилиты

### GBIF Utils (gbif_utils.dart)
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

### Llifle Utils (llifle_utils.dart)
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

### Weather Service (weather_service.dart)
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

### Translation Utils (translation_utils.dart)
**Перевод интерфейса:**
- Поддержка русского и английского
- Методы для перевода статусов, категорий
- Перевод текстов UI

### Responsive Helper (responsive_helper.dart)
**Определение типа устройства:**
- `isMobile(context)` - ширина <600
- `isDesktop(context)` - ширина >=600
- Адаптивные отступы

---

## Тема оформления (cactus_theme.dart)

### Цветовая палитра
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

### Компоненты темы
- AppBarTheme - зелёный фон, белые иконки
- CardTheme - elevation 3, borderRadius 16
- ChipTheme - песочный фон
- ElevatedButtonTheme - зелёные кнопки
- InputDecorationTheme - скруглённые поля

---

## Система уведомлений

### Инициализация (main.dart)
```dart
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin
AndroidInitializationSettings('@mipmap/ic_launcher')
requestNotificationsPermission() для Android 13+
```

### Логика уведомлений о поливе
**PlantProvider.checkWateringNotifications():**
- Расчет следующей даты полива для каждого растения
- Сравнение с текущей датой
- Установка `hasUnreadNotification = true`
- Отображение индикатора на карточке

### Ежедневная проверка погоды
**scheduleDailyWeatherCheck():**
- timezone package для локального времени
- Ежедневно в 8:00
- Уведомление с прогнозом погоды

---

## OAuth2 Flow (детально)

### Windows OAuth2 Flow
1. `connectToYandexDisk()` → AuthorizationCodeGrant
2. Открытие браузера на https://oauth.yandex.com/authorize
3. Пользователь авторизуется
4. Редирект на http://localhost:8080?code=XXX
5. `_startLocalServer()` перехватывает код
6. `handleYandexCallback()` обменивает код на токены
7. Сохранение в FlutterSecureStorage

### Android OAuth2 Flow
1. `connectToYandexDisk()` → AuthorizationCodeGrant
2. Redirect URI: `mycactus://callback`
3. Редирект на mycactus://callback?code=XXX
4. MainActivity.onNewIntent() получает intent
5. MethodChannel('deep_link') отправляет в Dart
6. `handleDeepLink()` обрабатывает URI
7. `handleYandexCallback()` обменивает код на токены

---

## Межплатформенная синхронизация

### Механизм
1. **Общий формат данных:** JSON сериализация идентична на обеих платформах
2. **Облако как посредник:** Данные синхронизируются через Яндекс.Диск
3. **Timestamp-based резолюшн:** lastLocalUpdate сравнивается с lastCloudUpdate
4. **Фото конвертация:** При загрузке из облака URLs заменяются на локальные пути

### Поток синхронизации Windows → Android
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

### Поток синхронизации Android → Windows
```
Аналогично, но в обратном направлении:
1. Android загружает фото в облако
2. Windows скачивает plant_provider.json
3. Windows скачивает фото из облака в %APPDATA%/plant_photos/
4. Замена URLs на локальные пути Windows
```

### Обработка конфликтов
- Допуск 2 секунды (timeTolerance)
- Если cloudUpdate > localUpdate + 2sec → загрузка из облака
- Если localUpdate > cloudUpdate + 2sec → загрузка в облако
- Автоматический бэкап перед загрузкой из облака

### Специфичные данные платформ
- Пути к фото разные, но конвертируются при синхронизации
- Токены хранятся локально (не синхронизируются)
- Настройки (remember_me, has_seen_welcome) локальные

---

## Взаимосвязи между файлами и методами

### main.dart → Providers
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

### PlantProvider → Plant model
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

### PlantProvider → Utils
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

### CloudStorageProvider ↔ PlantProvider
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

### Screens → Widgets
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

### Utils → SharedPreferences
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

## Точки входа и жизненный цикл

### Инициализация приложения (main())
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

### Инициализация MyApp
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

### Жизненный цикл экрана
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

## Безопасность

### Хранение токенов
- FlutterSecureStorage (AES шифрование)
- Access token + refresh token
- Автоматическое обновление токена через oauth2.Client

### OAuth2 security
- Authorization Code Grant
- Client secret хранится в коде (не идеально, но приемлемо для desktop/mobile)
- Scopes ограничены: cloud_api:disk.read, cloud_api:disk.write

### Защита данных
- Локальное хранение без шифрования (кроме токенов)
- HTTPS для всех API запросов
- Валидация cloud URLs перед использованием

### Обработка ошибок
- Try-catch блоки во всех критических операциях
- Логирование ошибок
- Graceful degradation (работа офлайн при отсутствии облака)

---

## Производительность

### Кэширование
- Dates watering кэшируются до изменения данных
- GBIF/Llifle данные кэшируются в SharedPreferences
- Weather кэшируется на 1 час
- Seasonal tips кэшируются по месяцу

### Оптимизация рендеринга
- Consumer<PlantProvider> для точечных обновлений
- Provider.of(context, listen: false) когда не нужны обновления
- Кэширование виджетов где возможно

### Проблемные места
- SharedPreferences при 1000+ растениях (медленная загрузка)
- Парсинг больших списков фото
- Синхронизация большого количества фото

---

## Хранение данных

### SharedPreferences
**Ключи:**
- `plants` - JSON список всех растений
- `global_watering_dates` - глобальные даты полива
- `adult_images` - маппинг растение→фото взрослого
- `wintering_start_date`, `wintering_end_date`, `wintering_temperature`
- `wintering_log_entries` - журнал зимовки
- `last_local_update` - метка времени синхронизации
- `remember_me`, `has_seen_welcome` - настройки
- `cloud_storage_type` - тип облака
- `tokens_cleaned_after_rebuild` - флаг очистки токенов после пересборки
- `gbif_data_*`, `plant_data_*` - кэши парсинга
- `weather_cache` - кэш погоды

**Ограничения:**
- Размер ~несколько МБ
- Нет транзакций
- Нет сложных запросов
- Медленно при 1000+ растениях (2-5 секунд)

### FlutterSecureStorage
**Токены Яндекс.Диска:**
- `yandex_access_token`
- `yandex_refresh_token`

**Защита от BadPaddingException:**
- Очистка при обнаружении повреждённых токенов
- Флаг `tokens_cleaned_after_rebuild` для однократной очистки

### Локальное хранение фото
**Пути:**
- Windows: `%APPDATA%/plant_photos/`
- Android: `/data/user/0/com.example.my_cactus/files/plant_photos/`

---

## Синхронизация с Яндекс.Диском

### Структура на Яндекс.Диске
```
/MyCactus/
├── plant_provider.json    # Все данные (растения, настройки, зимовка)
└── photos/                # Фото пользователей
    ├── {uuid}_{filename}.jpg
    └── ...
```

### Алгоритм синхронизации
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

### Синхронизация фото
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

## Платформенные различия

### pubspec.yaml различия

**Android только:**
- `image_picker: ^1.1.2` - выбор фото из галереи/камеры
- `image_cropper: ^12.2.0` - обрезка фото
- `mobile_scanner: ^4.0.1` - сканирование QR кодов

**Windows только:**
- `file_picker: ^10.1.9` - выбор файлов (для импорта/экспорта)
- `excel: ^4.0.6` - экспорт в Excel (CSV тоже)
- Конфигурация MSIX для установки
- `printing: ^5.13.4` - временно отключено из-за pdfium

### OAuth2 различия

**Windows:**
- Redirect URI: `http://localhost:8080`
- `_startLocalServer()` - HTTP сервер

**Android:**
- Redirect URI: `mycactus://callback`
- Deep link через MainActivity
- MethodChannel('deep_link')

### Android специфичные файлы

**MainActivity.kt:**
```kotlin
override fun onNewIntent(intent: Intent) {
  super.onNewIntent(intent)
  setIntent(intent)
  val data = intent.dataString
  if (data != null && data.startsWith("mycactus://")) {
    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
      val channel = MethodChannel(messenger, "deep_link")
      channel.invokeMethod("deep_link", data)
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

**Разрешения Android:**
- INTERNET
- ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION
- POST_NOTIFICATIONS (Android 13+)
- CAMERA

### Windows специфичные файлы

**win32_window.cpp:**
- Dark mode поддержка через DWMWA_USE_IMMERSIVE_DARK_MODE
- DPI scaling
- Window class регистрация

**msix_config.yaml:**
- Display name, publisher, identity
- Certificate для подписи
- Capabilities: internetClient, privateNetworkClientServer

---

## Реализованные функции

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

**QR-коды:**
- ✅ Генерация QR-кодов с ID и названием
- ✅ Массовое создание для выбранных растений
- ✅ PDF для печати (А4, А3, размеры этикеток)
- ✅ Экран управления QR-кодами
- ✅ Сканирование QR-кодов (Android)
- ✅ Создание листа для печати из существующих QR

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

---

## Критические проблемы

### Архитектурные проблемы
1. **PlantProvider: 2230 строк** - God Class, нарушение SRP
2. **PlantCardScreen: 104KB (~2500 строк)** - монолитный UI
3. **CloudStorageProvider: 736 строк** - смешение авторизации, синхронизации, platform-specific кода
4. **Отсутствие Repository Pattern** - Providers напрямую работают с SharedPreferences
5. **Отсутствие слоев абстракции** - бизнес-логика смешана с логикой хранения

### Хранение данных
1. **SharedPreferences не масштабируется** - 2-5 секунд для 1000 растений
2. **Нет транзакций** - риск потери данных при ошибках
3. **Нет индексов** - медленный поиск
4. **Ограничение по размеру** - ~несколько МБ

### Обработка ошибок
1. **Try-catch разбросаны по коду** - нет единого стандарта
2. **Пользователь видит технические сообщения** - плохой UX
3. **Нет централизованного логирования** - трудно отлаживать
4. **Нет crash reporting** - невозможно отслеживать ошибки в продакшене

### Тестирование
1. **Полное отсутствие тестов** - 0% coverage
2. **Невозможно рефакторить с уверенностью** - высокий риск регрессий
3. **Ручное тестирование занимает часы** - медленная разработка

### Производительность
1. **Загрузка фото без кэширования** - медленная галерея
2. **Парсинг HTML в main isolate** - блокировка UI
3. **Нет lazy loading** для больших списков
4. **Memory leaks** при загрузке изображений

### Платформенные различия
1. **Platform-specific код внутри общих классов** - сложная поддержка
2. **Дублирование логики** для Windows/Android
3. **Сложная обработка deep links** только на Android

---

## Зависимости (pubspec.yaml)

### Основные зависимости (общие)
```yaml
flutter: sdk: flutter
provider: ^6.1.1              # State management
shared_preferences: ^2.5.2    # Локальное хранение
flutter_secure_storage: ^9.2.2 # Токены
```

### Сеть и OAuth2
```yaml
http: ^1.3.0                  # HTTP запросы
dio: ^5.7.0                   # Продвинутый HTTP клиент
oauth2: ^2.0.2                # OAuth2 авторизация
url_launcher: ^6.2.0          # Открытие URL
```

### UI компоненты
```yaml
syncfusion_flutter_charts: ^29.2.9   # Графики
syncfusion_flutter_treemap: ^29.2.9  # Treemap
table_calendar: ^3.0.9               # Календарь
flutter_map: ^6.1.0                  # Интерактивная карта
latlong2: ^0.9.1                     # Координаты для карты
cached_network_image: ^3.2.0         # Кэширование изображений
flutter_local_notifications: ^17.2.2 # Уведомления
```

### Утилиты
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

### Платформенно-специфичные

**Android:**
```yaml
image_picker: ^1.1.2          # Выбор фото
image_cropper: ^12.2.0        # Обрезка фото
geolocator: ^11.0.1           # Геолокация
mobile_scanner: ^4.0.1        # Сканирование QR
```

**Windows:**
```yaml
file_picker: ^10.1.9          # Выбор файлов
excel: ^4.0.6                 # Excel/CSV
msix: ^3.16.8                 # MSIX packaging
printing: ^5.13.4            # Печать PDF (временно отключено)
```

### Dev зависимости
```yaml
flutter_test: sdk: flutter
flutter_lints: ^6.0.0
flutter_launcher_icons: ^0.14.3
```

---

## Пользовательские сценарии

### Сценарий 1: Добавление нового растения
**Действия пользователя:**
1. Нажать кнопку "+" на главном экране
2. Заполнить основные поля (латинское название, статус, год, номер, категория)
3. Загрузить фото (опционально)
4. Нажать кнопку "Парсинг Llifle" для автоматического заполнения (опционально)
5. Нажать кнопку "Поиск GBIF" для получения фото и данных о местообитаниях (опционально)
6. Сохранить

**Что происходит в системе:**
- Генерируется уникальный permanentId (UUID)
- Генерируется displayId (например: "24-001" или "K24-001")
- Данные сохраняются в SharedPreferences
- Если фото загружены, сохраняются локально
- Если включена синхронизация, данные загружаются в Яндекс.Диск

### Сценарий 2: Просмотр коллекции и массовые операции
**Действия пользователя:**
1. Открыть главный экран
2. Просмотреть статистику (фильтры: все, коллекция, семена, покупка)
3. Поиск по названию, ID, году
4. Сортировка по названию, статусу, году, категории
5. Выбрать растения (checkbox)
6. Выбрать действие из меню (удаление фото, изменение статуса/категории, удаление, экспорт)

**Что происходит в системе:**
- Фильтрация и сортировка выполняются на клиенте
- Массовые операции применяются к выбранным растениям
- При удалении фото помечаются как удаленные
- При экспорте генерируется CSV файл

### Сценарий 3: Просмотр карточки растения
**Действия пользователя:**
1. Нажать на растение в списке
2. Просмотреть вкладки (Основное, Уход, Галерея, Заметки, Карта, Сеянцы)
3. Отметить полив (кнопка "Полить сейчас")
4. Добавить заметку
5. Загрузить фото

**Что происходит в системе:**
- При отметке полива добавляется дата в wateringDates
- При добавлении заметки добавляется в notes
- При загрузке фото добавляется в userPhotos
- Если включена синхронизация, данные загружаются в Яндекс.Диск

### Сценарий 4: Подключение Яндекс.Диска
**Действия пользователя:**
1. Нажать кнопку "Подключить Яндекс.Диск" на главном экране
2. Android: открывается браузер для авторизации
3. Windows: открывается локальный браузер для авторизации
4. Авторизоваться в Яндекс.Диск
5. Разрешить доступ к диску
6. Вернуться в приложение

**Что происходит в системе:**
- Android: обрабатывается deep link (mycactus://callback)
- Windows: локальный сервер получает callback
- Токены сохраняются в FlutterSecureStorage
- Создаются папки на Яндекс.Диске
- Выполняется первая синхронизация

### Сценарий 5: Синхронизация данных
**Действия пользователя:**
1. Включить "Запомнить меня" на WelcomeScreen
2. Приложение автоматически синхронизируется при запуске
3. Или нажать кнопку синхронизации (если есть)

**Что происходит в системе:**
- Сравниваются lastLocalUpdate и lastCloudUpdate
- Если облако новее → загрузка из облака
- Если локально новее → загрузка в облако
- Если локально пусто → загрузка из облака
- Создается бэкап перед загрузкой из облака
- Фото синхронизируются отдельно

### Сценарий 6: Управление посевами и сеянцами
**Действия пользователя:**
1. Открыть экран управления посевами
2. Добавить год посева
3. Ввести количество семян
4. Создать витрину-партию (isBatch = true)
5. Добавить сеянцы (parentId = ID витрины)
6. Управлять количеством живых сеянцев (aliveCount)
7. Просматривать график всхожести

**Что происходит в системе:**
- Витрина получает displayId "24-001" или "K24-001"
- Сеянцы получают displayId "24-001-1", "24-001-2", и т.д.
- aliveCount может быть ручным или авторасчетом
- История всхожести сохраняется в germinationHistory

### Сценарий 7: Зимовка
**Действия пользователя:**
1. Открыть экран зимовки
2. Настроить дату начала зимовки
3. Настроить дату окончания зимовки
4. Настроить температуру зимовки
5. Добавить запись в журнал
6. Сохранить

**Что происходит в системе:**
- Данные сохраняются в SharedPreferences
- Журнал сохраняется в winteringLogEntries
- Влияет на график полива (уменьшает частоту)

---

## Автоматические операции
- Синхронизация при старте (если включено "Запомнить меня")
- Проверка уведомлений о поливе
- Кэширование данных
- Очистка старых дат полива (90 дней)
- Миграция фото

---

## Текущие ограничения архитектуры

### SharedPreferences как хранилище
- Ограничение на размер данных (обычно несколько МБ)
- Нет транзакций (если ошибка при сохранении, данные могут быть частично сохранены)
- Нет сложных запросов (нужно загружать все данные в память)
- Нет отношений между данными (все в одной модели Plant)
- Нет индексов (поиск выполняется перебором всех элементов)
- Медленно при большом количестве данных (1000+ растений)

### Отсутствие разделения данных
- Все данные о растении в одной модели Plant
- Нет отдельной модели для вида (SpeciesTemplate)
- Нет отдельной модели для экземпляра (PlantInstance)
- Нет отдельной модели для логов (CareLog)
- Нет отдельной модели для среды (EnvironmentSnapshot)
- Нет отдельной модели для калибровки (CalibrationHistory)

### Простая система полива
- Фиксированные интервалы (не адаптивная)
- Нет учета физиологии растения
- Нет учета среды (температура, влажность, свет)
- Нет учета фазы растения (покой, рост, цветение)
- Нет автокалибровки на основе истории
- Нет индекса готовности к поливу

### Отсутствие системы здоровья
- Только свободные заметки (нет структуры)
- Нет структурированного ввода симптомов
- Нет гипотез причин проблем
- Нет протоколов лечения
- Нет аналитики эффективности методов

### Отсутствие машины состояний
- Нет фаз растения (Dormant, Transition, ActiveGrowth, Flowering, PreDormant)
- Нет автоматического определения фазы
- Нет сезонных триггеров
- Нет правил-блокировок (например, блокировка полива в покое)

### Отсутствие планировщика с приоритетами
- Уведомления без приоритетов
- Нет контекста в уведомлениях (почему поливать)
- Нет группировки уведомлений
- Нет отложенных уведомлений

---

## Текущие ограничения UI

### Отсутствующие функции UI
- QR-этикетки для растений
- Фото-сравнение с метаданными
- Карта теплицы с локациями
- Структурированная вкладка "Здоровье"
- Индекс готовности к поливу
- Объяснение рекомендаций по уходу
- История синонимов таксономии
- Валидация научных названий
- Ручной ввод среды (температура, влажность, свет)
- Графики среды
- Отображение калибровки

### Ограничения текущего UI
- Фильтрация только по статусу, категории, году
- Сортировка только по названию, статусу, году, категории
- Нет фильтрации по локации
- Нет фильтрации по фазе
- Нет фильтрации по здоровью
- Нет расширенного поиска (по синонимам, местам сбора)

---

## Текущие ограничения синхронизации

### Яндекс.Диск только
- Нет поддержки других облачных сервисов
- Нет выбора облачного сервиса
- Нет шифрования данных в облаке
- Нет дифференциальной синхронизации (всегда полная загрузка)

### Конфликты
- Простая стратегия: более новая версия побеждает
- Нет ручного разрешения конфликтов
- Нет визуализации конфликтов
- Допуск 2 секунды для определения конфликта

---

## Текущие ограничения фото

### Хранение фото
- Локальное хранение (путь зависит от платформы)
- Облачное хранение (Яндекс.Диск)
- Нет метаданных фото (EXIF не используется)
- Нет фото-сравнения (до/после)
- Нет референсных фото
- Нет метаданных фото (дата съемки, камера, настройки)

### Управление фото
- Ручное удаление старых фото
- Ручное удаление всех фото
- Нет автоматической очистки дубликатов (только UUID именование)
- Нет автоматического сжатия
- Нет автоматического поворота

---

## Текущие ограничения парсинга

### GBIF
- Только поиск по названию
- Нет фильтрации по стране
- Нет фильтрации по году сбора
- Нет фильтрации по коллекциям
- Нет кэширования результатов

### Llifle
- Только парсинг HTML (нет API)
- Нет обработки ошибок парсинга
- Нет кэширования результатов
- Нет обновления данных

---

## Текущие ограничения уведомлений

### Уведомления о поливе
- Только на основе рекомендованных дат
- Нет приоритетов
- Нет контекста (почему поливать)
- Нет группировки
- Нет сезонных изменений

### Отсутствующие типы уведомлений
- Уведомления о подкормке
- Уведомления о пересадке
- Уведомления о проблемах со здоровьем
- Уведомления о критических значениях среды
- Уведомления о смене фазы

---

## Текущие ограничения статистики

### Отсутствующая аналитика
- Нет анализа эффективности методов лечения
- Нет статистики по типам проблем
- Нет сезонных паттернов
- Нет анализа цветения
- Нет анализа всхожести
- Нет анализа роста

---

## Известные проблемы

### BadPaddingException на Android
**Проблема:** После пересборки APK токены не расшифровываются
**Решение:** Автоматическая очистка токенов при обнаружении ошибки + флаг tokens_cleaned_after_rebuild

### Race conditions при синхронизации фото
**Проблема:** Несколько одновременных загрузок фото
**Решение:** Флаг _isEnsuringPhotos + проверка перед загрузкой

### Дубликаты фото в облаке
**Проблема:** Одинаковые имена файлов
**Решение:** UUID + оригинальное имя ({uuid}_{filename})

### Пути к фото на разных платформах
**Проблема:** Windows пути не работают на Android и наоборот
**Решение:** Проверка префиксов (C:\Users, /data/user/) и замена на локальные пути при синхронизации

### Windows printing пакет
**Проблема:** Build step for pdfium failed даже с установленной VS2022
**Решение:** Временно отключен, печать заменена на сохранение PDF файла

---

## Сильные стороны

- ✅ Полностью рабочие кроссплатформенные приложения
- ✅ Надёжная синхронизация через Яндекс.Диск
- ✅ Богатый функционал (парсинг, уведомления, карта, статистика)
- ✅ Система партий сеянцев
- ✅ Кэширование для производительности
- ✅ Хорошая структура кода (providers, utils, screens)
- ✅ QR-коды и печать этикеток

---

## Метрики производительности (до рефакторинга)

| Метрика | Значение |
|---------|----------|
| Загрузка 1000 растений | 2-5 секунд |
| Фильтрация 1000 растений | 500ms |
| Синхронизация фото (50 шт) | 10-30 секунд |
| Загрузка галереи с фото | 1-3 секунды |
| UI FPS при скролле | 45-55 |
| Потребление памяти | 150-200 MB |
| Время запуска приложения | 3-5 секунд |
| Test coverage | 0% |
| Размер PlantProvider | 2230 строк |
| Размер PlantCardScreen | 104KB (~2500 строк) |

---

## Файлы для проверки после рефакторинга

После завершения рефакторинга убедиться, что все функции сохранены:

**Управление растениями:**
- [ ] Добавление/редактирование/удаление растений
- [ ] Все статусы и категории работают
- [ ] Автогенерация ID работает
- [ ] Массовые операции работают

**Парсинг данных:**
- [ ] Llifle парсинг работает
- [ ] GBIF парсинг работает
- [ ] Кэширование работает
- [ ] Флаги стран отображаются

**Уход:**
- [ ] Все типы дат полива работают
- [ ] Подкормки работают
- [ ] Пересадки работают
- [ ] Календарь ухода работает
- [ ] Зимовка влияет на полив

**Система партий:**
- [ ] Витрины работают
- [ ] Сеянцы работают
- [ ] aliveCount рассчитывается
- [ ] Генерация ID сеянцев работает

**Фото:**
- [ ] Загрузка фото работает
- [ ] Галерея работает
- [ ] Синхронизация фото работает
- [ ] Удаление фото работает

**QR-коды:**
- [ ] Генерация QR работает
- [ ] Массовое создание работает
- [ ] Печать PDF работает
- [ ] Сканирование QR работает (Android)
- [ ] Создание листа для печати работает

**Синхронизация:**
- [ ] Авторизация работает
- [ ] Автосинхронизация работает
- [ ] Ручная синхронизация работает
- [ ] Конфликт-резолюшн работает
- [ ] Синхронизация фото работает

**Уведомления:**
- [ ] Уведомления о поливе работают
- [ ] Проверка погоды работает
- [ ] Разрешения Android работают

**Погода:**
- [ ] Геолокация работает
- [ ] Получение погоды работает
- [ ] Советы по поливу работают

**Экспорт:**
- [ ] CSV экспорт работает

**Поиск и фильтрация:**
- [ ] Поиск работает
- [ ] Фильтры работают
- [ ] Сортировка работает

**Темы:**
- [ ] Light тема работает
- [ ] Dark тема работает
- [ ] System theme работает

---

**Этот файл фиксирует состояние приложения ДО рефакторинга для проверки сохранения всех функций.**
