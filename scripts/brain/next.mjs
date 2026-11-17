// brain:next (T-199, I-187) — «что дальше» под роль из профиля + шаг к TARGET_STATE + дрейф скоупа.
// Роль из brain.config.json (D-68): задачи роли показываются первыми; суперадмин видит всё.
// Дрейф: задача, чей модуль отсутствует в TARGET_STATE, помечается «вне TARGET» (мозг — не дрейф).
import {readFileSync,existsSync} from 'fs';
import {getRole,roleLabel,moduleMatches} from './lib/role.mjs';

const EX='_ai_workspace/_extracted';
const rows=r=>readFileSync(`${EX}/${r}.md`,'utf8').split('\n').filter(l=>/^\|\s*[A-Z]-\d+/.test(l));
const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
const pNum=p=>{const m=(p.match(/P(\d)/)||[])[1];return m?+m:9};

const role=getRole();
const target=existsSync('_ai_workspace/v4/TARGET_STATE.md')?readFileSync('_ai_workspace/v4/TARGET_STATE.md','utf8').toLowerCase():'';
const inTarget=mod=>mod.includes('мозг')||mod.split(/[/\s]+/).some(w=>w.length>3&&target.includes(w));

const ready=rows('tasks')
 .map(l=>({id:cell(l,1),name:cell(l,2),status:cell(l,7),prio:cell(l,8),mod:cell(l,6)}))
 .filter(t=>t.status.startsWith('📅')||t.status.startsWith('🔄'))
 .sort((a,b)=>pNum(a.prio)-pNum(b.prio)||a.id.localeCompare(b.id,undefined,{numeric:true}));
const mine=ready.filter(t=>moduleMatches(t.mod,role));
const drift=ready.filter(t=>!inTarget(t.mod));
const openQ=rows('questions').filter(l=>!cell(l,7).startsWith('✅'))
 .map(l=>({id:cell(l,1),essence:cell(l,3)}));

console.log(`🎯 ЧТО ДАЛЬШЕ — роль: ${roleLabel(role)}${role==='superadmin'?' (видит всё)':''}\n`);
const show=mine.length?mine:ready;
if(!show.length)console.log('  В плане пусто — всё сделано или ждёт новых задач.');
else show.slice(0,3).forEach((t,i)=>{
 const s=t.status.startsWith('🔄')?'(в работе)':'';
 const d=inTarget(t.mod)?'':' ⚠️вне-TARGET';
 console.log(`  ${i+1}. ${t.id} ${s}[${t.prio||'—'}]${d} ${t.name.slice(0,105)}${t.name.length>105?'…':''}`);
});
if(mine.length!==ready.length)console.log(`  Фокус роли: ${mine.length} из ${ready.length} задач в очереди (смена роли — brain.config.json → role)`);
else if(ready.length>3)console.log(`  … ещё ${ready.length-3} в очереди (📅/🔄 всего ${ready.length})`);
if(drift.length)console.log(`\n🧭 Дрейф скоупа: ${drift.length} задач вне TARGET_STATE — ${drift.slice(0,5).map(t=>t.id).join(', ')}${drift.length>5?'…':''}`);
console.log('\n❓ Открытые вопросы (ждут твоего решения)');
if(!openQ.length)console.log('  Вопросов нет — реестр чист.');
else openQ.forEach(q=>console.log(`  · ${q.id}: ${q.essence}`));
console.log('\nКоманда по запросу: npm run brain:next');
