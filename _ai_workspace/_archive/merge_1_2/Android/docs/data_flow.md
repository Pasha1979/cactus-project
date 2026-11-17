# Потоки данных в приложении

## 1. Добавление нового растения

```mermaid
flowchart TD
    A[Пользователь вводит данные] --> B[AddPlantScreen]
    B --> C[PlantCrudProvider.addPlant]
    C --> D{Валидация}
    D -->|OK| E[PlantRepository.addPlant]
    E --> F[PlantLocalDataSource]
    F --> G[(Hive: PlantDto)]
    G --> H[Уведомление UI]
    D -->|Error| I[Показать ошибку]
```

## 2. Загрузка данных из GBIF

```mermaid
flowchart TD
    A[Ввод латинского названия] --> B[GbifService.fetchGbifData]
    B --> C{Проверка кэша}
    C -->|Hit| D[Вернуть кэшированные данные]
    C -->|Miss| E[HTTP запрос к GBIF API]
    E --> F[Парсинг JSON]
    F --> G[Сохранение в кэш SharedPreferences]
    G --> H[Возврат данных]
```

## 3. Синхронизация с облаком (Yandex Disk)

```mermaid
sequenceDiagram
    participant User
    participant CloudProvider as CloudStorageProvider
    participant Repo as PlantRepository
    participant Yandex as Yandex Disk API

    User->>CloudProvider: Нажать "Синхронизировать"
    CloudProvider->>Repo: Экспорт всех растений
    Repo-->>CloudProvider: JSON
    CloudProvider->>Yandex: Upload file
    Yandex-->>CloudProvider: Success/Error
    CloudProvider-->>User: Показать результат
```

## 4. Полив растения

```mermaid
flowchart LR
    A[Нажатие "Полить"] --> B[WateringProvider.addWateringDate]
    B --> C[Обновление PlantDto]
    C --> D[Сохранение в Hive]
    D --> E[Обновление уведомлений]
    E --> F[UI обновляется]
```

## 5. Уведомления

```mermaid
flowchart TD
    A[Регулярная проверка] --> B{Дата полива?}
    B -->|Да| C[Показать Local Notification]
    B -->|Нет| D[Проверить зимовку]
    D -->|Да| E[Показать уведомление]
    D -->|Нет| F[Ничего не делать]
```

## Модели данных

### Plant (Entity)
```dart
class Plant {
  final String id;
  final String latinName;
  final String status; // alive, dead, etc.
  final List<String> userPhotos;
  final List<DateTime> wateringDates;
  // ...
}
```

### PlantDto (Data Transfer Object)
```dart
@HiveType(typeId: 0)
class PlantDto extends HiveObject {
  @HiveField(0)
  final String permanentId;
  // ...
}
```

### Преобразование
```
PlantDto (Hive) ↔ Plant (Domain) ↔ JSON (Cloud)
```
