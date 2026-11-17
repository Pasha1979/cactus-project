// brain:search (T-196, I-184): полнотекст по реестрам + архивам + плану.
// Выдаёт файл:строка — фрагмент + найденные ID в строке. Анти-«ускользнуло»: старые записи находятся командой.
import {readFileSync,readdirSync,statSync} from 'fs';
import {join,relative} from 'path';

export function* walk(dir){
  for(const e of readdirSync(dir,{withFileTypes:true})){
    const p=join(dir,e.name);
    if(e.isDirectory())yield* walk(p);
    else if(/\.(md|json|txt)$/i.test(e.name))yield p;
  }
}

export function search(query,{root='_ai_workspace',limit=40}={}){
  // запрос с заглавными — точный (case-sensitive): «iCal» не ловит «critical»
  const cs=/[A-ZА-ЯЁ]/.test(query),q=cs?query:query.toLowerCase(),hits=[];
  for(const file of walk(root)){
    const lines=readFileSync(file,'utf8').split('\n');
    lines.forEach((line,i)=>{
      if(hits.length>=limit)return;
      if(!(cs?line.includes(q):line.toLowerCase().includes(q)))return;
      const ids=[...line.matchAll(/\b[ITRDLQ]-\d+\b/g)].map(m=>m[0]);
      hits.push({file:relative(root,file),line:i+1,ids,snippet:line.trim().slice(0,140)});
    });
  }
  return hits;
}

if(process.argv[1]&&process.argv[1].endsWith('search.mjs')){
  const query=process.argv[2];
  if(!query){console.log('Использование: npm run brain:search -- "<запрос>"');process.exit(0)}
  const hits=search(query);
  if(!hits.length)console.log(`🔍 «${query}» — совпадений нет`);
  else{
    console.log(`🔍 «${query}» — ${hits.length} совпадений:`);
    for(const h of hits)console.log(`   ${h.file}:${h.line}${h.ids.length?` [${[...new Set(h.ids)].join(', ')}]`:''}  ${h.snippet}`);
  }
}
