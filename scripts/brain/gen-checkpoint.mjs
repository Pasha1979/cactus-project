#!/usr/bin/env node
// gen-checkpoint: CONTEXT_CHECKPOINT.md — страховка от потери контекста ВНУТРИ сессии (автоген, ≤1500 симв)
// генерируется по запросу (npm run brain:checkpoint): перед ответвлением, сменой модуля, при потере нити
import {execSync} from 'child_process';
import {readFileSync,writeFileSync,existsSync,copyFileSync,mkdirSync,readdirSync,unlinkSync} from 'fs';
const sh=c=>{try{return execSync(c,{encoding:'utf8'}).trim()}catch{return''}};
// T-20: автоархив — прежняя версия уходит в _archive/contexts/ до перезаписи (храним 30 последних)
const archive=(src,name)=>{if(!existsSync(src))return;const AR='_ai_workspace/_archive/contexts';
 mkdirSync(AR,{recursive:true});
 const ts=new Date().toISOString().slice(0,16).replace(/[:T]/g,'-');
 copyFileSync(src,`${AR}/${name}-${ts}.md`);
 const old=readdirSync(AR).filter(f=>f.startsWith(name+'-')).sort();
 old.slice(0,Math.max(0,old.length-30)).forEach(f=>unlinkSync(`${AR}/${f}`));};
const branch=sh('git rev-parse --abbrev-ref HEAD'),head=sh('git log --oneline -1').slice(0,50);
const EX='_ai_workspace/_extracted';
const rows=r=>readFileSync(`${EX}/${r}.md`,'utf8').split('\n').filter(l=>/^\|\s*[A-Z]-\d+/.test(l));
const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
const plan=readFileSync('_ai_workspace/v4/01_ПЛАН.md','utf8');
const sec=(plan.match(/## 🔴 СЕЙЧАС[\s\S]*?(?=\n## (?!🔴)|$)/)||[''])[0];
// текущая задача — первая строка таблицы СЕЙЧАС; активный модуль — её колонка «Модуль»
const taskRows=[...sec.matchAll(/^\|\s*(\d+)\s*\|([^|]+)\|([^|]*)\|([^|]*)\|/gm)];
const cur=taskRows[0];
const wip=rows('tasks').filter(l=>cell(l,7).startsWith('🔄'))
 .map(l=>`${cell(l,1)} ${cell(l,3).slice(0,55)}`).slice(0,3);
const lastD=rows('decisions').slice(-1).map(l=>`${cell(l,1)} — ${cell(l,3).slice(0,60)}`);
const openQ=rows('questions').filter(l=>!cell(l,7).startsWith('✅')).map(l=>cell(l,1));
const now=new Date();
const date=now.toISOString().slice(0,10),time=now.toTimeString().slice(0,5);
const md=`# CONTEXT_CHECKPOINT (автоген) · ${date} ${time} · \`${branch}\` · ${head}
> Страховка внутри сессии. Перед ответвлением/сменой модуля/потерей нити: npm run brain:checkpoint

## Текущая задача
${cur?cur[2].trim():'— см. 01_ПЛАН «СЕЙЧАС»'}${cur&&cur[3].trim()?` · модуль: ${cur[3].trim()}`:''}

## В работе (🔄)
${wip.length?wip.map(w=>'- '+w).join('\n'):'- нет'}

## СЕЙЧАС из плана
${taskRows.slice(0,3).map(m=>`${m[1]}. ${m[2].trim().slice(0,65)}`).join('\n')||'—'}

Ждут решения: ${openQ.join(', ')||'нет'} · Последнее решение: ${lastD[0]||'—'}
`;
archive('_ai_workspace/v4/CONTEXT_CHECKPOINT.md','CONTEXT_CHECKPOINT');
writeFileSync('_ai_workspace/v4/CONTEXT_CHECKPOINT.md',md);
console.log(`✅ CONTEXT_CHECKPOINT: ${md.length} символов · ветка ${branch} · 🔄 ${wip.length} · вопросов ${openQ.length}`);
if(md.length>1500)console.log('⚠️ превышен лимит 1500 — сократи генератор');
