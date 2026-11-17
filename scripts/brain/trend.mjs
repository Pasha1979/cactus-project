// brain:trend (T-202, I-190) — снапшот прогресса в trend-лог + вывод тренда.
// Метрики: идеи, задачи, сделано/в плане/в работе/отклонено, заглушки, тест-файлы.
// Лог: _ai_workspace/metrics/trend.jsonl (по строке на снапшот). Снапшот — один раз в день.
import {readFileSync,existsSync,mkdirSync,appendFileSync,readdirSync} from 'fs';
import {join} from 'path';
import {execSync} from 'child_process';

const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
const rows=(md,rx)=>md.split('\n').filter(l=>rx.test(l));
const LOG='_ai_workspace/metrics/trend.jsonl';

export function computeSnapshot(ideasMd,tasksMd,{testFiles=0,date=new Date().toISOString().slice(0,10)}={}){
  const ideas=rows(ideasMd,/^\|\s*I-\d+/),tasks=rows(tasksMd,/^\|\s*T-\d+/);
  const byStatus=(list,mark)=>list.filter(l=>cell(l,7).startsWith(mark)).length;
  return {
    date,
    ideas:ideas.length,
    ideasRejected:byStatus(ideas,'❌'),
    tasks:tasks.length,
    tasksDone:byStatus(tasks,'✅'),
    tasksPlanned:byStatus(tasks,'📅'),
    tasksWip:byStatus(tasks,'🔄'),
    stubs:[...ideas,...tasks].filter(l=>/заглушк/i.test(l)).length,
    testFiles,
  };
}

export function formatTrend(snaps){
  if(!snaps.length)return '(лог пуст)';
  const arrow=(a,b)=>b>a?'↑':b<a?'↓':'→';
  const last=snaps[snaps.length-1],prev=snaps[snaps.length-2]||last;
  const lines=snaps.slice(-7).map(s=>`   ${s.date}  идей ${s.ideas} · задач ${s.tasks} · ✅${s.tasksDone} 📅${s.tasksPlanned} 🔄${s.tasksWip} ❌${s.ideasRejected} · заглушек ${s.stubs} · тест-файлов ${s.testFiles}`);
  return lines.join('\n')+
    `\n   Тренд: ✅ ${arrow(prev.tasksDone,last.tasksDone)} · 📅 ${arrow(prev.tasksPlanned,last.tasksPlanned)} · идей ${arrow(prev.ideas,last.ideas)}`;
}

const countTestFiles=()=>{try{return execSync('git ls-files "*.test.*"',{encoding:'utf8'}).split('\n').filter(Boolean).length}catch{return 0}};

if(process.argv[1]&&process.argv[1].endsWith('trend.mjs')){
  const EX='_ai_workspace/_extracted';
  const snap=computeSnapshot(readFileSync(`${EX}/ideas.md`,'utf8'),readFileSync(`${EX}/tasks.md`,'utf8'),{testFiles:countTestFiles()});
  mkdirSync('_ai_workspace/metrics',{recursive:true});
  const lines=existsSync(LOG)?readFileSync(LOG,'utf8').split('\n').filter(Boolean):[];
  const snaps=lines.map(l=>{try{return JSON.parse(l)}catch{return null}}).filter(Boolean);
  if(!snaps.length||snaps[snaps.length-1].date!==snap.date){appendFileSync(LOG,JSON.stringify(snap)+'\n');snaps.push(snap);console.log(`📈 Снапшот записан → ${LOG}`)}
  else console.log('📈 Снапшот за сегодня уже есть — показываю тренд');
  console.log('\n📈 TREND — динамика мозга:\n'+formatTrend(snaps));
}
