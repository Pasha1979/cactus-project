# Руководство для разработчиков

## Быстрый старт

### Требования
- Flutter SDK 3.19+
- Dart 3.0+
- Android Studio / VS Code
- Git

### Установка

```bash
# Клонирование репозитория
git clone <repo-url>
cd cactus-project/Android  # или Windows

# Установка зависимостей
flutter pub get

# Генерация кода (DI, Hive adapters)
flutter pub run build_runner build --delete-conflicting-outputs

# Запуск
flutter run
```

## Структура проекта

```
lib/
├── core/               # Ядро приложения
│   ├── config/         # Константы, настройки
│   ├── logger/         # Логирование (AppLogger)
│   └── ui/             # UI утилиты
├── data/               # Data Layer
│   ├── datasources/    # Локальные и удалённые источники
│   ├── models/         # DTO модели (PlantDto)
│   └── repositories/   # Реализации репозиториев
├── domain/             # Domain Layer
│   ├── entities/       # Бизнес-сущности
│   └── repositories/   # Интерфейсы репозиториев
├── presentation/       # Presentation Layer
│   ├── providers/      # State management
│   ├── screens/        # UI экраны
│   └── widgets/        # Переиспользуемые виджеты
├── services/           # Внешние сервисы
│   ├── api/            # GBIF, Llifle API
│   └── isolates/       # Background processing
└── injection_container.dart  # DI контейнер
```

## Архитектура

Приложение следует **Clean Architecture** с тремя слоями:

1. **Presentation**: UI и Providers (ChangeNotifier)
2. **Domain**: Бизнес-логика и сущности
3. **Data**: Работа с данными (Hive, API)

## Тестирование

### Запуск тестов

```bash
# Все тесты
flutter test

# С покрытием
flutter test --coverage

# Генерация отчёта о покрытии
genhtml coverage/lcov.info -o coverage/html
```

### Структура тестов

```
test/
├── unit/               # Unit тесты
│   ├── repositories/   # Тесты репозиториев
│   └── services/       # Тесты сервисов
├── widget/             # Widget тесты
│   └── screens/        # Тесты экранов
└── integration/        # Интеграционные тесты
```

## Код-стайл

### Именование
- Файлы: `snake_case.dart`
- Классы: `PascalCase`
- Методы/переменные: `camelCase`
- Константы: `lowerCamelCase` или `SCREAMING_SNAKE_CASE`

### Комментарии
- Используйте `///` для dartdoc
- Описывайте публичные API
- Добавляйте примеры кода для сложных методов

### Пример:
```dart
/// Получает данные о растении из GBIF API.
///
/// Сначала проверяет локальный кэш (TTL: 7 дней),
/// затем делает HTTP-запрос к GBIF.
///
/// [latinName] - латинское название растения
/// Returns: Map с данными или null при ошибке
///
/// Пример:
/// ```dart
/// final data = await gbifService.fetchGbifData('Aloe vera');
/// ```
Future<Map<String, dynamic>?> fetchGbifData(String latinName) async {
  // ...
}
```

## Отладка

### Логирование

Используйте `AppLogger`:
```dart
AppLogger.api('Запрос данных', tag: 'GBIF');
AppLogger.db('Сохранение в Hive', tag: 'PLANT');
AppLogger.error('Ошибка сети', error: e, stackTrace: stack);
```

### Firebase Crashlytics

Краши автоматически отправляются в Firebase Console (только в release mode).

## Работа с Hive

### Добавление нового типа

1. Создайте модель с аннотациями:
```dart
@HiveType(typeId: 1)
class MyModel {
  @HiveField(0)
  final String id;
}
```

2. Запустите генерацию:
```bash
flutter pub run build_runner build
```

3. Зарегистрируйте адаптер в `hive_database.dart`:
```dart
Hive.registerAdapter(MyModelAdapter());
```

## Полезные команды

```bash
# Анализ кода
flutter analyze

# Форматирование
flutter format lib/

# Сборка APK (Android)
flutter build apk --release

# Сборка Windows
flutter build windows --release

# Сборка App Bundle (Android Play Store)
flutter build appbundle
```

## Контакты

По вопросам архитектуры и кода обращайтесь к [владельцу репозитория].
