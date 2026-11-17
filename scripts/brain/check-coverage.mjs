// check-coverage (T-195, I-183): авто-проверка полноты реестров — «ноль-потерь навсегда».
// WARNING-only (R-90): никогда не блокирует гейт, только подсвечивает.
// Проверки: принятые P1/P2-идеи имеют T-ID; ✅-задачи имеют доказательство; протухшие 🔄 подсвечены.
import {readFileSync,existsSync} from 'fs';
import {join} from 'path';

const DAY=864e5;
const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
export const rows=md=>md.split('\n').filter(l=>/^\|\s*[ITRDLQ]-\d+/.test(l));

// Доказательство у ✅-задачи: хеш коммита, упоминание теста/e2e или файла
const EVIDENCE=/\b[0-9a-f]{7,40}\b|тест|test|e2e|flutter analyze|\.dart\b|\.mjs\b|коммит/i;

export function analyzeCoverage(ideasMd,tasksMd,{now=Date.now(),staleDays=14}={}){
  const warnings=[];
  const taskRows=rows(tasksMd);
  const linkedIds=new Set();
  for(const t of taskRows)
    for(const m of cell(t,9).matchAll(/[ITRDLQ]-\d+/g))linkedIds.add(m[0]);

  // 1. принятые P1/P2-идеи без связанной задачи
  for(const l of rows(ideasMd)){
    const id=cell(l,1),status=cell(l,7),prio=cell(l,8),links=cell(l,9);
    if(!status.startsWith('📅'))continue;
    if(!/^P[12]$/.test(prio))continue;
    if(/T-\d+/.test(links)||linkedIds.has(id))continue;
    warnings.push(`coverage: идея ${id} принята (${prio}) но без задачи T-ID — «${cell(l,3).slice(0,50)}»`);
  }
  // 2. ✅-задачи без доказательства
  for(const l of taskRows){
    if(!cell(l,7).startsWith('✅'))continue;
    if(EVIDENCE.test(l))continue;
    warnings.push(`coverage: задача ${cell(l,1)} ✅ без доказательства (коммит/тест/файл) — «${cell(l,3).slice(0,50)}»`);
  }
  // 3. протухшие 🔄 (в работе дольше staleDays)
  for(const l of taskRows){
    if(!cell(l,7).startsWith('🔄'))continue;
    const age=now-Date.parse(cell(l,5).split('.').reverse().join('-'));
    if(age>staleDays*DAY)
      warnings.push(`coverage: задача ${cell(l,1)} 🔄 протухла — в работе ${Math.round(age/DAY)} дн. (порог ${staleDays})`);
  }
  return warnings;
}

export function loadConfig(root='.'){
  const p=join(root,'_ai_workspace','brain.config.json');
  if(!existsSync(p))return {};
  try{return JSON.parse(readFileSync(p,'utf8'))}catch{return {}}
}

if(process.argv[1]&&process.argv[1].endsWith('check-coverage.mjs')){
  const EX='_ai_workspace/_extracted';
  const cfg=loadConfig().coverage||{};
  const warnings=analyzeCoverage(
    readFileSync(`${EX}/ideas.md`,'utf8'),
    readFileSync(`${EX}/tasks.md`,'utf8'),
    {staleDays:cfg.staleWipDays||14});
  if(!warnings.length)console.log('✅ check-coverage: покрытие полное — принятые идеи имеют задачи, ✅ с доказательствами, 🔄 свежие');
  else{console.log(`⚠️ check-coverage: ${warnings.length} предупреждений (не блокирует):`);warnings.forEach(w=>console.log('   ⚠️ '+w))}
}
