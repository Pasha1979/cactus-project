#!/usr/bin/env node
import {readFileSync,existsSync} from 'fs';
const REGS=['ideas','rules','tasks','decisions','questions','lessons'];
// cactus: алиасы кратких путей источников → реальные папки архива
const ALIAS={'ПП/':'Принципы проекта/','ROAD/':'ROADMAP/','REF/':'REFACTORING_ROADMAP/','ANL/':'REFACTORING/'};
const expand=f=>{for(const[a,b]of Object.entries(ALIAS))if(f.startsWith(a))return b+f.slice(a.length);return f};
let bad=[],total=0,withSrc=0;
for(const r of REGS){
 for(const line of readFileSync(`_ai_workspace/_extracted/${r}.md`,'utf8').split('\n')){
  if(!/^\| [A-Z]-\d+ /.test(line))continue;total++;
  const f=line.split('|').map(s=>s.trim());const src=f[4]||'';
  if(src)withSrc++;
  // .md-имена могут содержать пробелы (напр. «Принцип вкладки здоровье.md»)
  for(const raw of src.match(/[^\s,+()»«][^,+()»«]*?\.md/g)||[]){
   const file=expand(raw.trim());
   const c=[file,`_ai_workspace/${file}`,`_ai_workspace/_archive/v3/${file}`,`_ai_workspace/_archive/${file}`,`./${file}`];
   if(!c.some(p=>existsSync(p)))bad.push(`${r}:${f[1]} → не найден: ${raw}`)}
 }}
console.log(`записей: ${total}, с источником: ${withSrc}`);
if(bad.length){console.log(`⚠️ нерезолвящиеся источники (${bad.length}):`);bad.slice(0,20).forEach(b=>console.log('  '+b));process.exit(1)}
console.log('✅ check-registries: все записи имеют источник');
