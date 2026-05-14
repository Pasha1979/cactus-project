# Архитектура приложения My Cactus

## Общая архитектура (Clean Architecture)

```mermaid
graph TB
    subgraph Presentation["Presentation Layer (UI)"]
        UI[Widgets/Screens]
        Providers[ChangeNotifierProviders]
    end

    subgraph Domain["Domain Layer (Business Logic)"]
        Entities[Entities: Plant, etc.]
        Repositories[Repository Interfaces]
    end

    subgraph Data["Data Layer"]
        RepoImpl[Repository Implementations]
        DataSources[Data Sources]
        Models[DTO Models]
    end

    subgraph External["External Services"]
        GBIF[GBIF API]
        Llifle[Llifle API]
        LocalDB[(Hive DB)]
    end

    UI --> Providers
    Providers --> Repositories
    Repositories --> RepoImpl
    RepoImpl --> DataSources
    DataSources --> LocalDB
    DataSources --> GBIF
    DataSources --> Llifle
```

## Слои приложения

### 1. Presentation Layer
- **Screens**: UI экраны (WelcomeScreen, HomeScreen, etc.)
- **Providers**: Управление состоянием (PlantCrudProvider, etc.)
- **Widgets**: Переиспользуемые компоненты

### 2. Domain Layer
- **Entities**: Бизнес-сущности (Plant)
- **Repository Interfaces**: Абстракции для работы с данными

### 3. Data Layer
- **Repository Implementations**: Конкретная реализация репозиториев
- **Data Sources**: Локальные и удалённые источники данных
- **DTO Models**: Модели для сериализации (PlantDto)

## Поток данных

```mermaid
sequenceDiagram
    participant UI as UI/Provider
    participant Repo as Repository
    participant DS as DataSource
    participant DB as Hive DB

    UI->>Repo: getAllPlants()
    Repo->>DS: fetchPlants()
    DS->>DB: query()
    DB-->>DS: List<PlantDto>
    DS-->>Repo: List<Plant>
    Repo-->>UI: List<Plant>
```

## Ключевые компоненты

| Компонент | Назначение | Файл |
|-----------|-----------|------|
| PlantRepository | CRUD операции с растениями | `domain/repositories/plant_repository.dart` |
| GbifService | Интеграция с GBIF API | `services/api/gbif_service.dart` |
| PlantCrudProvider | Управление состоянием UI | `presentation/providers/plant_crud_provider.dart` |
| HiveDatabase | Локальное хранилище | `data/datasources/local/hive_database.dart` |
| AppLogger | Логирование и Crashlytics | `core/logger/app_logger.dart` |

## Dependency Injection

```mermaid
graph LR
    A[UI] -->|uses| B[Provider]
    B -->|uses| C[Repository]
    C -->|uses| D[DataSource]
    D -->|uses| E[(Hive)]

    F[get_it] -->|provides| B
    F -->|provides| C
    F -->|provides| D
```

Используется `get_it` + `injectable` для DI.
