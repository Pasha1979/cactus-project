#!/usr/bin/env node
// promote: идеи без связанной задачи → кандидаты в T-задачи (по запросу, НЕ в гейте)
// логика: берём I-… из _extracted/ideas.md без ссылки на их ID в _extracted/tasks.md,
// фильтруем завершённые (✅/❌), сортируем по приоритету (⭐/P0 > P1 > P2 > —), топ-5
import {readFileSync} from 'fs';
const EX='_ai_workspace/_extracted';
const rows=r=>readFileSync(`${EX}/${r}.md`,'utf8').split('\n').filter(l=>/^\|\s*[A-Z]-\d+/.test(l));
const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
const tasksBlob=readFileSync(`${EX}/tasks.md`,'utf8');
const P=s=>s.includes('⭐')||s.includes('P0')?0:s.includes('P1')?1:s.includes('P2')?2:s.includes('P3')?3:4;
const ideas=rows('ideas').filter(l=>/^\|\s*I-\d+/.test(l));
const ready=ideas
 .filter(l=>{
  const id=cell(l,1).replace(/\s*\(.*\)/,'').trim();
  const st=cell(l,7);
  if(st.startsWith('✅')||st.startsWith('❌'))return false;           // закрытые/отменённые не предлагаем
  return !new RegExp(`\\b${id}\\b`).test(tasksBlob);                 // нет ссылки на идею в задачах
 })
 .map(l=>({id:cell(l,1),gist:cell(l,3),st:cell(l,7),p:P(cell(l,8)),pr:cell(l,8)}))
 .sort((a,b)=>a.p-b.p);
console.log(`Идей всего: ${ideas.length} · без задачи и незакрытых: ${ready.length}`);
console.log('\nГотовы к превращению в задачу (топ-5):');
for(const r of ready.slice(0,5))
 console.log(`  ${r.id} — ${r.gist.slice(0,60)} [${r.st}${r.pr&&r.pr!=='—'?' · '+r.pr:''}]`);
if(ready.length>5)console.log(`  … и ещё ${ready.length-5} — полный список: _extracted/ideas.md`);
console.log('\nЧтобы превратить: добавь задачу в _extracted/tasks.md с новым T-ID и ссылкой на I-ID в колонке «дубли/связи».');
