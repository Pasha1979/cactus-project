// brain:lint (T-205, I-193) — чистота реестров: fuzzy-дубли идей, сироты-ID, протухшие статусы.
// Только ПРЕДЛАГАЕТ слияния — данные сам не меняет. Запуск по запросу (может быть шумным).
import {readFileSync} from 'fs';

const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
const rows=(md,rx)=>md.split('\n').filter(l=>rx.test(l));
const DAY=864e5;
const STOP=new Set(['и','в','на','с','по','для','из','к','о','a','the','to','of','—','-','+']);
const words=s=>new Set(s.toLowerCase().replace(/[^\p{L}\p{N} ]/gu,' ').split(/\s+/).filter(w=>w.length>2&&!STOP.has(w)));
const jaccard=(a,b)=>{const i=[...a].filter(x=>b.has(x)).length,u=new Set([...a,...b]).size;return u?i/u:0};

export function lintRegistries(ideasMd,tasksMd,{now=Date.now(),dupThreshold=0.55,staleWipDays=14,staleIdeaDays=60}={}){
  const ideas=rows(ideasMd,/^\|\s*I-\d+/).map(l=>({id:cell(l,1),text:cell(l,2)+' '+cell(l,3),status:cell(l,7),date:cell(l,5),links:cell(l,9),line:l}));
  const tasks=rows(tasksMd,/^\|\s*T-\d+/).map(l=>({id:cell(l,1),text:cell(l,3),status:cell(l,7),date:cell(l,5),links:cell(l,9),line:l}));
  const ideaIds=new Set(ideas.map(x=>x.id)),taskIds=new Set(tasks.map(x=>x.id));
  const out={dups:[],orphans:[],stale:[]};

  // Fuzzy-дубли идей (пары с высокой похожестью текста) — пропускаем записи с явной пометкой «дубль»/«слита»/🔀
  const merged=x=>/дубль|слита|🔀/i.test(x.links+x.status);
  const bags=ideas.map(x=>({...x,bag:words(x.text)}));
  for(let i=0;i<bags.length;i++)for(let j=i+1;j<bags.length;j++){
    const a=bags[i],b=bags[j];
    if(merged(a)||merged(b))continue;
    const s=jaccard(a.bag,b.bag);
    if(s>=dupThreshold)out.dups.push({a:a.id,b:b.id,score:+s.toFixed(2)});
  }
  // Сироты-ID: задача ссылается на несуществующую идею, идея — на несуществующую задачу
  for(const t of tasks)
    for(const m of t.links.matchAll(/I-\d+/g))
      if(!ideaIds.has(m[0]))out.orphans.push(`${t.id} → несуществующая ${m[0]}`);
  for(const x of ideas)
    for(const m of x.links.matchAll(/T-\d+/g))
      if(!taskIds.has(m[0]))out.orphans.push(`${x.id} → несуществующая ${m[0]}`);
  // Протухшие статусы: 🔄 старше staleWipDays, 💭 старше staleIdeaDays
  const age=d=>{const[x,y,z]=String(d).split('.');const p=Date.parse(`${z}-${y}-${x}`);return Number.isNaN(p)?0:now-p};
  for(const t of tasks)if(t.status.startsWith('🔄')&&age(t.date)>staleWipDays*DAY)
    out.stale.push(`${t.id} 🔄 ${Math.round(age(t.date)/DAY)} дн.`);
  for(const x of ideas)if(x.status.startsWith('💭')&&age(x.date)>staleIdeaDays*DAY)
    out.stale.push(`${x.id} 💭 ${Math.round(age(x.date)/DAY)} дн. — проверить актуальность`);
  return out;
}

if(process.argv[1]&&process.argv[1].endsWith('brain-lint.mjs')){
  const EX='_ai_workspace/_extracted';
  const r=lintRegistries(readFileSync(`${EX}/ideas.md`,'utf8'),readFileSync(`${EX}/tasks.md`,'utf8'));
  console.log('🧹 brain:lint — чистота реестров (предложения, данные не меняются)\n');
  console.log(`Дубли идей (${r.dups.length}):`);
  r.dups.slice(0,15).forEach(d=>console.log(`   · ${d.a} ↔ ${d.b} похожи ${Math.round(d.score*100)}% — рассмотреть слияние`));
  console.log(`\nСироты-ID (${r.orphans.length}):`);
  r.orphans.slice(0,15).forEach(o=>console.log(`   · ${o}`));
  console.log(`\nПротухшие статусы (${r.stale.length}):`);
  r.stale.slice(0,15).forEach(s=>console.log(`   · ${s}`));
}
