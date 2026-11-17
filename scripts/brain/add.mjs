#!/usr/bin/env node
/**
 * brain:add — атомарная запись в реестры _extracted/.
 * Авто: следующий ID (I-/T-/R-/L-/Q-/D-N), сегодняшняя дата, экранирование |.
 *
 * Использование:
 *   node scripts/brain/add.mjs <тип> "<текст1>" "<текст2>" "<текст3>" [текст4]
 *
 * Типы и маппинг аргументов:
 *   idea     <цитата> <суть> <модуль> [источник]      → ideas.md    (статус 💭)
 *   task     <цитата> <суть> <модуль> [источник]      → tasks.md    (статус 📅)
 *   rule     <цитата> <суть> <модуль> [источник]      → rules.md    (статус 💭)
 *   question <вопрос> <суть> <модуль> [источник]      → questions.md(статус ❓)
 *   decision <цитата> <решение> <тема> [источник]     → decisions.md(статус ✅)
 *   lesson   <суть/проблема> <предотвращение> <тема> [источник] → lessons.md
 *
 * Пример: node scripts/brain/add.mjs idea "а давайте чёрную тему" "тёмная тема UI" "интерфейс"
 */
import { readFileSync, appendFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const ROOT = join(import.meta.dirname, '..', '..', '_ai_workspace', '_extracted')
const today = () => {
  const d = new Date()
  return `${String(d.getDate()).padStart(2, '0')}.${String(d.getMonth() + 1).padStart(2, '0')}.${d.getFullYear()}`
}
const esc = (s) => (s ?? '').replace(/\|/g, '\\|').replace(/\s+/g, ' ').trim()

const TYPES = {
  idea:     { file: 'ideas.md',     prefix: 'I', status: '💭' },
  task:     { file: 'tasks.md',     prefix: 'T', status: '📅' },
  rule:     { file: 'rules.md',     prefix: 'R', status: '💭' },
  question: { file: 'questions.md', prefix: 'Q', status: '❓' },
  decision: { file: 'decisions.md', prefix: 'D', status: '✅' },
  lesson:   { file: 'lessons.md',   prefix: 'L', status: '✅' },
}

const [type, a1, a2, a3, a4] = process.argv.slice(2)
if (!TYPES[type] || !a1 || !a2 || !a3) {
  console.error('Использование: node scripts/brain/add.mjs <idea|task|rule|question|decision|lesson> <текст1> <текст2> <текст3> [источник]')
  process.exit(1)
}

const cfg = TYPES[type]
const path = join(ROOT, cfg.file)
if (!existsSync(path)) { console.error(`Нет файла: ${path}`); process.exit(1) }

const content = readFileSync(path, 'utf8')
const ids = [...content.matchAll(new RegExp(`\\b${cfg.prefix}-(\\d+)\\b`, 'g'))].map(m => +m[1])
const next = `${cfg.prefix}-${ids.length ? Math.max(...ids) + 1 : 1}`
const date = today()
const source = esc(a4) || `пользователь ${date}`

const row = type === 'lesson'
  ? `| ${next} | ${esc(a1)} | ${esc(a2)} | ${source} | ${date} | ${esc(a3)} | — |`
  : `| ${next} | ${esc(a1)} | ${esc(a2)} | ${source} | ${date} | ${esc(a3)} | ${cfg.status} | — | — |`

appendFileSync(path, (content.endsWith('\n') ? '' : '\n') + row + '\n')
console.log(`✅ ${next} → _extracted/${cfg.file}`)
