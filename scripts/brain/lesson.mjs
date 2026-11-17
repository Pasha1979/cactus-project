// brain:lesson <модуль> (T-200, I-188) — релевантные уроки перед задачей.
// Ищет по колонке «Тема» и тексту урока в _extracted/lessons.md.
import {readFileSync} from 'fs';

const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
const rows=md=>md.split('\n').filter(l=>/^\|\s*L-\d+/.test(l));

export function findLessons(lessonsMd,module,{limit=8}={}){
  const q=module.toLowerCase();
  return rows(lessonsMd)
    .map(l=>({id:cell(l,1),essence:cell(l,2),prevention:cell(l,3),topic:cell(l,6)}))
    .filter(x=>x.topic.toLowerCase().includes(q)||x.essence.toLowerCase().includes(q))
    .slice(0,limit);
}

if(process.argv[1]&&process.argv[1].endsWith('lesson.mjs')){
  const q=process.argv[2];
  if(!q){console.log('Использование: npm run brain:lesson -- <модуль>');process.exit(0)}
  const hits=findLessons(readFileSync('_ai_workspace/_extracted/lessons.md','utf8'),q);
  if(!hits.length)console.log(`📚 «${q}» — уроков не найдено`);
  else{
    console.log(`📚 Уроки по «${q}» (${hits.length}):`);
    hits.forEach(h=>console.log(`  · ${h.id}: ${h.essence.slice(0,90)}${h.prevention?` → ${h.prevention.slice(0,50)}`:''}`));
  }
}
