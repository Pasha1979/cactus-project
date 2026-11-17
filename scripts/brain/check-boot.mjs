#!/usr/bin/env node
// check-boot: бюджет размера boot-набора (00_ВИДЕНИЕ + 02_СТАТУС + 04_ПРАВИЛА + «СЕЙЧАС» из 01_ПЛАН)
// бюджет: BOOT_BUDGET env или 8000 символов (≈ 2 страницы; текущий ~6478, запас ~23%)
import {readFileSync,existsSync} from 'fs';
const BUDGET=+(process.env.BOOT_BUDGET||8000);
const V4='_ai_workspace/v4';
const parts=[];
for(const f of ['SESSION_HANDOFF.md','CONTEXT_CHECKPOINT.md','00_ВИДЕНИЕ.md','TARGET_STATE.md','02_СТАТУС.md','04_ПРАВИЛА.md'])
 parts.push([f,existsSync(`${V4}/${f}`)?readFileSync(`${V4}/${f}`,'utf8').length:0]);
const plan=readFileSync(`${V4}/01_ПЛАН.md`,'utf8');
const m=plan.match(/## 🔴 СЕЙЧАС[\s\S]*?(?=\n## (?!🔴)|$)/);
parts.push(['01_ПЛАН.md «СЕЙЧАС»',(m?m[0]:'').length]);
const total=parts.reduce((s,[,n])=>s+n,0);
const max=Math.max(...parts.map(([,n])=>n));
for(const [f,n] of parts){
 const share=Math.round(n/BUDGET*100);
 const mark=n===max?' ← самый большой':'';
 console.log(`  ${String(n).padStart(6)} ${String(share).padStart(3)}%  ${f}${mark}`);
}
// T-20: наглядный прогресс бюджета — шкала 20 делений
const pct=Math.round(total/BUDGET*100);
const filled=Math.min(20,Math.round(pct/5));
const bar='█'.repeat(filled)+'░'.repeat(20-filled);
console.log(`boot-набор: ${total} символов · бюджет: ${BUDGET}`);
console.log(`  [${bar}] ${pct}%`);
if(total>BUDGET){console.log(`❌ check-boot: превышение на ${total-BUDGET} символов — boot раздут (правило: ≤2 страницы)`);process.exit(1)}
console.log(`✅ check-boot: в пределах бюджета (запас ${BUDGET-total})`);
