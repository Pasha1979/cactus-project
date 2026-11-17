#!/usr/bin/env node
// check-refs: целостность ID-ссылок — упомянутый в доках ID должен быть определён в _extracted
import {readdirSync,readFileSync,existsSync} from 'fs';
import {join} from 'path';
const DOCS=['.windsurfrules'];
const v4='_ai_workspace/v4';
for(const f of readdirSync(v4)){if(/^0[0134567]_.*\.md$/.test(f))DOCS.push(join(v4,f))}
for(const f of readdirSync('.windsurf/workflows')){if(f.endsWith('.md'))DOCS.push(join('.windsurf/workflows',f))}
// определённые ID из реестров _extracted
const DEF={I:new Set(),R:new Set(),T:new Set(),D:new Set(),Q:new Set(),L:new Set()};
const REGS={ideas:'I',rules:'R',tasks:'T',decisions:'D',questions:'Q',lessons:'L'};
for(const [file,pfx] of Object.entries(REGS)){
 for(const line of readFileSync(`_ai_workspace/_extracted/${file}.md`,'utf8').split('\n')){
  const m=line.match(/^\|\s*([A-Z])-(\d+)(?:\([^)]*\))?\s*\|/);if(m&&DEF[m[1]])DEF[m[1]].add(+m[2]);
 }}
// извлечь упомянутые ID: T-5, T-13..18 (диапазон), T-113/114/115 и T-105,106 (списки)
const mentioned=new Map(); // id -> where
for(const doc of DOCS){
 const t=readFileSync(doc,'utf8');
 // диапазоны вида T-13..18 и I-1..I-94
 for(const m of t.matchAll(/\b([TIDRQL])-(\d+)\s*\.\.\s*(?:[TIDRQL]-)?(\d+)/g)){
  const p=m[1],a=+m[2],b=+m[3];
  for(let n=Math.min(a,b);n<=Math.max(a,b);n++)mentioned.set(`${p}-${n}`,doc);
 }
 // ID + продолжения через , или /
 for(const m of t.matchAll(/\b([TIDRQL])-(\d+)((?:\s*[,/]\s*\d+)*)/g)){
  mentioned.set(`${m[1]}-${m[2]}`,doc);
  for(const n of (m[3].match(/\d+/g)||[]))mentioned.set(`${m[1]}-${n}`,doc);
 }
}
const dangling=[...mentioned.keys()].filter(id=>{
 const [p,n]=id.split('-');return !DEF[p].has(+n);
});
console.log(`упомянуто ID: ${mentioned.size}, определено в реестрах: ${Object.values(DEF).reduce((s,x)=>s+x.size,0)}`);
if(dangling.length){console.log(`❌ Висячие ID (${dangling.length}) — упомянуты, но не определены в _extracted:`);
 for(const id of dangling)console.log(`  ${id}  ← ${mentioned.get(id)}`);process.exit(1)}
console.log('✅ check-refs: висячих ID нет');
