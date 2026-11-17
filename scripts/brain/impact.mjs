// brain:impact <идея> (T-201, I-189) — карта влияния: какие модули и роли (D-68) затрагивает идея.
import {readFileSync} from 'fs';
import {rolesForModule,roleLabel} from './lib/role.mjs';

const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
const rows=md=>md.split('\n').filter(l=>/^\|\s*[IT]-\d+/.test(l));

export function impactOf(ideasMd,id){
  const l=rows(ideasMd).find(x=>cell(x,1)===id);
  if(!l)return null;
  const mod=cell(l,6);
  return {
    id,
    essence:cell(l,3),
    module:mod,
    status:cell(l,7),prio:cell(l,8),links:cell(l,9),
    roles:rolesForModule(mod).map(roleLabel),
  };
}

if(process.argv[1]&&process.argv[1].endsWith('impact.mjs')){
  const id=process.argv[2];
  if(!id){console.log('Использование: npm run brain:impact -- <I-…>');process.exit(0)}
  const r=impactOf(readFileSync('_ai_workspace/_extracted/ideas.md','utf8'),id);
  if(!r){console.log(`🔍 ${id} не найден в реестре идей`);process.exit(0)}
  console.log(`🗺️ Влияние ${r.id}: ${r.essence.slice(0,80)}`);
  console.log(`   Модуль: ${r.module||'—'} · Статус: ${r.status} · Приоритет: ${r.prio||'—'}`);
  console.log(`   Затрагивает роли: ${r.roles.join(', ')||'только суперадмин'}`);
  console.log(`   Связи: ${r.links}`);
}
