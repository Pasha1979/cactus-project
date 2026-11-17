# scripts/brain — механизмы Brain v4

| Команда | Что делает |
|---|---|
| `npm run brain:links` | Все md-ссылки резолвятся; падает при битых (архив не проверяется) |
| `npm run brain:status` | Генерирует `v4/02_СТАТУС.md` из git log + скана кода (заглушки, TODO) |
| `npm run brain:regs` | Каждая запись реестров `_extracted/` имеет резолвящийся источник |
| `npm run brain:check` | links + regs + refs + boot + handoff + coverage + guard |

## Гейт изменений (вшит в 04_ПРАВИЛА):
`flutter analyze` на Android И Windows (оба!) → аудит 9 пунктов → `npm run brain:check` → commit → push.
