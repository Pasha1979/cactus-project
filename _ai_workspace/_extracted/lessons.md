# lessons — реестр извлечения v4 (cactus-project)
# Формат: ID | проблема/суть | предотвращение | источник | дата | тема | —

## Из ROADMAP/LESSONS_LEARNED.md

| L-1 | Реализация только в Android, забыли Windows → рассинхронизация кодовой базы | Перед шагом: «Какие файлы в обоих проектах?»; вести парный список Android↔Windows; никогда не менять один проект без разрешения | ROAD/LESSONS_LEARNED.md + REF/LESSONS_LEARNED.md (ф.2.0 Ош.1) | 09-11.05.2026 | платформы | — |
| L-2 | Ошибки сборки printing/pdfium на Windows (нет VS2022 build tools v143) → пакет printing закомментирован в Windows | Проверять pubspec.yaml Windows перед копированием; платформенные ограничения — отдельная проверка; см. Q-1 | ROAD/LESSONS_LEARNED.md | 09.05.2026 | windows | — |
| L-3 | Жёстко зашитые OAuth-креденшелы в коде → вынесены в api_config | Секреты и ключи — в конфиг, не в код | ROAD/LESSONS_LEARNED.md | 09.05.2026 | безопасность | — |
| L-4 | Потеря данных при рефакторинге (преждевременное удаление полей/методов) | Двухфазное удаление: deprecated → удаление после верификации; тест полного цикла; git tag бэкап | ROAD/LESSONS_LEARNED.md | 09.05.2026 | рефакторинг | — |
| L-5 | Неконсистентное именование (camelCase/snake_case) → путаница | Единый стиль на проект; проверка при ревью | ROAD/LESSONS_LEARNED.md | 09.05.2026 | код | — |
| L-6 | Изменения без проверки «до vs после» → потерянная функциональность находилась поздно | Сравнение со Стабильной/оригиналом обязательно | ROAD/LESSONS_LEARNED.md | 09.05.2026 | рефакторинг | — |

## Из REFACTORING_ROADMAP/LESSONS_LEARNED.md (успешные паттерны)

| L-7 | Странная ошибка компиляции/анализа → лечится рестартом IDE/анализатора, не правкой кода | Сначала restart analyzer/IDE, потом диагностика | REF/LESSONS_LEARNED.md (паттерны) | 09-11.05.2026 | инструменты | — |
| L-8 | Flutter hot reload/restart создаёт фантомные ошибки после рефакторинга провайдеров | Полный hot restart после изменений провайдеров; не доверять hot reload | REF/LESSONS_LEARNED.md | 09-11.05.2026 | flutter | — |
| L-9 | Hive.initFlutter() race condition: миграция и репозитории одновременно открывали box | Порядок инициализации: миграция → репозитории; await цепочка | REF/LESSONS_LEARNED.md | 09-11.05.2026 | hive | — |
| L-10 | Использование JSON-маппинга как промежуточного слоя Entity↔DTO → потери полей | Прямой маппинг полей, без JSON-прослойки | REF/LESSONS_LEARNED.md | 09-11.05.2026 | архитектура | — |
| L-11 | Дубли номеров шагов и пропущенная перенумерация в плане → путаница | После правки плана: проверка нумерации и ссылок (R-13) | REF/LESSONS_LEARNED.md | 09-11.05.2026 | план | — |
| L-12 | Strangler Fig при разделении PlantProvider (2230 строк) → 8 провайдеров без потери работы | Монолит не делить за раз: создать новое → параллельно → мигрировать → удалить старое; каждый провайдер автономен; barrel-файл providers.dart | REF/LESSONS_LEARNED.md | 10.05.2026 | рефакторинг | — |
| L-13 | Перенос экранов на новые провайдеры — итеративно: методы в провайдер ДО переноса, один экран → analyze → синхронизация платформ | По одному экрану; savePlants() no-op для совместимости; context.watch для простых случаев, context.read в initState | REF/LESSONS_LEARNED.md | 10.05.2026 | рефакторинг | — |
| L-14 | Пользователь попросил разделить statistics_screen (1347 строк) на мелкие подзадачи — сработало | Сложный экран >3 Consumer или >500 строк → подзадачи | REF/LESSONS_LEARNED.md | 10.05.2026 | рефакторинг | — |

## Из REFACTORING_ROADMAP/LESSONS_LEARNED.md (ошибки)

| L-15 | Упрощённый loadFromCloudJson заменял локальные данные облачными; toJson терял globalWateringDates/adultImages/wintering → синхронизация между устройствами сломана | Ни один метод нельзя упростить без diff с оригиналом; чек-лист: все методы перенесены/осознанно удалены; sync/serialization логика идентична | REF/LESSONS_LEARNED.md (Ош. sync) | 11.05.2026 | синхронизация | — |
| L-16 | Новые провайдеры без persistence: globalWateringDates, adultImages, wintering — in-memory → потеря при перезапуске; savePlants() стал no-op; restoreFromLocalBackup заглушка | flutter analyze ≠ работает. Persistence-чек R-30; TODO в persistence = критический дефект; ручной тест перезапуска | REF/LESSONS_LEARNED.md (Ош. persistence) | 11.05.2026 | persistence | — |
| L-17 | ensureLocalPhotosExist (~40 строк: download, retry, валидация URL, очистка кэша) потерян при переносе → пустая заглушка без маркировки | diff реализаций при переносе; пустая заглушка без throw = критическая ошибка; FIXME для известных проблем | REF/LESSONS_LEARNED.md Ош.12 | 11.05.2026 | рефакторинг | — |
| L-18 | Alias loadDataFromCloud делегировал в syncData вместо loadDataFromCloud → полная синхронизация вместо download на первом подключении | Попарная проверка alias: основной → сервис X, alias → тот же X; не доверять названиям | REF/LESSONS_LEARNED.md Ош.13 | 11.05.2026 | рефакторинг | — |
| L-19 | Не все throw UnimplementedError найдены за первый grep (truncation top-N) → 1 остался | После исправления N ошибок проверить что 0; grep без truncation; список ВСЕХ заглушек | REF/LESSONS_LEARNED.md Ош.14 | 11.05.2026 | процесс | — |
| L-20 | FIXME без скобки «FIXME (шаг 1.10.11)» не находился grep'ом TODO\(|FIXME\(; + снова потеряны реализации cleanupUnusedPhotosForSelected | Проверять все форматы маркеров (R-24); повторная потеря реализации = провал обучения | REF/LESSONS_LEARNED.md Ош.15 | 11.05.2026 | процесс | — |
| L-21 | main.dart Windows: isRelease → _cleanAppData() очищал SharedPreferences+SecureStorage+фото при КАЖДОМ запуске release | Никогда не очищать данные в release; main.dart обеих платформ — особый контроль | REF/LESSONS_LEARNED.md Ош.16 | 11.05.2026 | безопасность | — |
| L-22 | Повторное .withOpacity() в 8 файлах (23 warnings) — пользователь уже указывал | Запрещён .withOpacity → withValues(alpha:); grep-паттерн; читать уроки перед сессией | REF/LESSONS_LEARNED.md Ош.17 | 11.05.2026 | код | — |
| L-23 | getPlantById через firstWhere O(n) вместо box.get(id) O(1); нет индексов для 1000+ растений | Нативные O(1) операции БД; PlantIndexManager с индексами status/category/displayId; fallback к O(n) | REF/LESSONS_LEARNED.md Ош.18 | 11.05.2026 | производительность | — |
| L-24 | Фаза 2.0: все 6 фиксов применены только к Android → полный rollback | Аудит обоих проектов перед шагом; парный список файлов | REF/LESSONS_LEARNED.md (ф.2.0 Ош.1) | 11.05.2026 | платформы | — |
| L-25 | Невалидные вызовы инструментов (пустые {}) 3 раза подряд → сбой процесса | Самопроверка «Все параметры? Валидны? Не пустые?» перед каждым вызовом; при повторе — стоп и запись в уроки | REF/LESSONS_LEARNED.md (ф.2.0 Ош.2/4) | 11.05.2026 | инструменты | — |
| L-26 | Проверка по 9 пунктам отложена до конца фазы → накопление ошибок → rollback | Чек-лист после КАЖДОЙ задачи; не переходить к N+1 без all-clear | REF/LESSONS_LEARNED.md (ф.2.0 Ош.3) | 11.05.2026 | процесс | — |
| L-27 | DateTime.parse без защиты в GerminationRecord/FloweringRecord/Note → краш на битых данных | tryParse + fallback во ВСЕХ fromJson включая вложенные модели; grep DateTime.parse( | REF/LESSONS_LEARNED.md Ош.9/10 | 12.05.2026 | данные | — |
| L-28 | Миграция дат полива: prefs.getString() vs setStringList → type cast ошибка | Учитывать ВСЕ форматы хранения старой версии; fallback; тест на реальных данных | REF/LESSONS_LEARNED.md Ош.25 | 13.05.2026 | миграция | — |
| L-29 | Маршрут /add-sowing-year ≠ вызов context.push('/sowing/add') → 404 | Маршрут = вызову в коде, не имени файла; grep context.push перед созданием | REF/LESSONS_LEARNED.md Ош.5 | 12.05.2026 | навигация | — |
| L-30 | GoRouter redirect перенаправлял deep link cactusapp://plant/123 на /welcome | Redirect различает initial launch и deep link (path != '/' → null); deep links приоритетнее | REF/LESSONS_LEARNED.md Ош.6 | 12.05.2026 | навигация | — |
| L-31 | Пропущены 10 вызовов Navigator.push в widgets/ при микро-шаге — список файлов был неполный | Глобальный grep по всему проекту ПЕРЕД завершением; включать widgets/tabs/подпапки | REF/LESSONS_LEARNED.md Ош.7 | 12.05.2026 | навигация | — |
| L-32 | Закомментированный import printing раскомментирован в Windows → пакет не найден | Проверять pubspec.yaml Windows; понять ПОЧЕМУ закомментировано прежде чем менять | REF/LESSONS_LEARNED.md Ош.8 | 12.05.2026 | windows | — |
| L-33 | При завершении шага 2.5 вычеркнуты ВСЕ оставшиеся шаги вместо одного → путаница пользователя | Правило одного шага: вычеркивать только выполненный; сверять с todo_list перед отправкой | REF/LESSONS_LEARNED.md Ош.26 | 16.05.2026 | коммуникация | — |
| L-34 | Перестал следовать правилам REFACTORING_ROADMAP (комфортность/автоматизм) — пользователь заметил | Нет автоматических напоминаний → нужен мозг с правилами (эта миграция); 9 пунктов обязательны; проверка рисков ПЕРЕД кодом | REF/LESSONS_LEARNED.md Ош.27 | 16.05.2026 | процесс | — |

## Предсказательные паттерны (из REF/LESSONS_LEARNED.md)

| L-35 | Топ повторяющихся ошибок: DateTime.parse без защиты; потеря функциональности при рефакторинге; platform-specific при копировании; route mismatch; пропущенные вызовы при микро-шагах | Критические зоны: providers, migrations, routers, theme, models → медленный режим R-18 | REF/LESSONS_LEARNED.md (паттерны) | 05.2026 | паттерны | — |
| L-36 | mcp_flutter на Windows: build_skill_assets падает на CRLF | При сборке flutter-mcp-toolkit из исходников на Windows SKILL.md может быть в CRLF; нормализовать line endings перед разбором frontmatter или использовать патч. Релизных Windows-бинарей нет — сервер собирается из источника. | пользователь 27.11.2026 | 27.11.2026 | tooling | — |
