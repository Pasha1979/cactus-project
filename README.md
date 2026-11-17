# My Cactus — коллекционер кактусов

Flutter-приложение: одно приложение, две платформы — `Android/` и `Windows/` (сейчас две копии проекта). Целевая версия пересборки: **1.2.0**.

## Документы проекта

- [docs/decisions/DECISIONS.md](docs/decisions/DECISIONS.md) — 32 решения владельца (дословно, baseline)
- [docs/PROJECT_RULES.md](docs/PROJECT_RULES.md) — правила работы для любого ИИ-ассистента
- [docs/features/FEATURE_REGISTRY.md](docs/features/FEATURE_REGISTRY.md) — реестр файлов функций (Android × Windows)
- [docs/platform/PLATFORM_DIFF_REGISTRY.md](docs/platform/PLATFORM_DIFF_REGISTRY.md) — реестр различий платформ
- [docs/cleanup/JUNK_INVENTORY.md](docs/cleanup/JUNK_INVENTORY.md) — инвентарь мусора (~102.85 MB)
- `_ai_workspace/` — мозг проекта (brain v4): планы, реестры знаний, архив документации

## Страховка

- Ветка `archive/legacy-2026-11-17` и тег `pre-rebuild-baseline` — точка возврата перед пересборкой.

## Главное правило

**Ничего не удаляем без архива.** Ноль потерь: полнота доказывается счётчиками в реестрах (R-007).

## Секреты и ключи (env.json)

Ключи API вынесены из кода в локальный файл `env.json` (в `.gitignore`, в репозиторий не попадает). Шаблон — `env.example.json`. Копия `env.json` лежит в корне репозитория; команды выполняются из папки платформы (`Android/` или `Windows/`).

### env.json (корень репо, НЕ коммитить)

```json
{
  "YANDEX_CLIENT_ID": "...",
  "YANDEX_CLIENT_SECRET": "...",
  "OPENWEATHER_API_KEY": "...",
  "TRANSLATION_API_TOKEN": "...",
  "TRANSLATION_API_REFERER": "https://lingvanex.com/translate/",
  "MSIX_CERT_PASSWORD": "..."
}
```

### Запуск и сборка

Из папки `Android/` или `Windows/`:

```bash
flutter run --dart-define-from-file=../env.json
flutter build apk --dart-define-from-file=../env.json
flutter build windows --dart-define-from-file=../env.json
```

Если скопировать `env.json` в папку проекта (`Android/env.json` / `Windows/env.json` — тоже в `.gitignore`), команды короче:

```bash
flutter run --dart-define-from-file=env.json
flutter build apk --dart-define-from-file=env.json
flutter build windows --dart-define-from-file=env.json
```

Без `env.json` приложение запускается и работает; сервисы с ключами (Яндекс.Диск, погода, переводчик) пишут в лог «Ключ ИМЯ_КЛЮЧА не настроен (env.json)» и пропускают запрос — краша нет.

### Подпись MSIX (Windows-пакет)

`certificate_password` убран из `pubspec.yaml`. Пароль — только в `env.json` (`MSIX_CERT_PASSWORD`). При создании пакета передавать флагом:

```bash
dart run msix:create --certificate-password=<MSIX_CERT_PASSWORD>
```

(подставить значение из `env.json`; в командной строке не сохранять историю с паролем).
