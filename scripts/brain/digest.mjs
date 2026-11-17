// brain:digest (T-203, I-191, D-68) — недельная сводка под роль: сделано / далее / вопросы / дедлайны.
// Роль из профиля (brain.config.json): секция «далее» фильтруется по модулям роли; суперадмин видит всё.
import {readFileSync} from 'fs';
import {execSync} from 'child_process';
import {getRole,roleLabel,moduleMatches} from './lib/role.mjs';

const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
const rows=(md,rx)=>md.split('\n').filter(l=>rx.test(l));
const DAY=864e5;
const ruDate=d=>{const[x,y,z]=d.split('.');return Date.parse(`${z}-${y}-${x}`)};

export function buildDigest({tasksMd,questionsMd,commits,role='superadmin',now=Date.now(),days=7}){
  const tasks=rows(tasksMd,/^\|\s*T-\d+/).map(l=>({id:cell(l,1),name:cell(l,2),title:cell(l,3),status:cell(l,7),prio:cell(l,8),mod:cell(l,6)}));
  const done=tasks.filter(t=>t.status.startsWith('✅'));
  const doneWeek=done.filter(t=>{const m=t.status.match(/(\d{2}\.\d{2}\.\d{4})/);return m&&now-ruDate(m[1])<days*DAY});
  const planned=tasks.filter(t=>t.status.startsWith('📅')||t.status.startsWith('🔄'));
  const next=planned.filter(t=>moduleMatches(t.mod,role))
    .sort((a,b)=>(a.prio||'9').localeCompare(b.prio||'9')).slice(0,5);
  const questions=rows(questionsMd,/^\|\s*Q-\d+/).filter(l=>!cell(l,7).startsWith('✅'))
    .map(l=>({id:cell(l,1),essence:cell(l,3)}));
  const deadlines=tasks.filter(t=>/дедлайн/i.test(t.name+t.title)&&!t.status.startsWith('✅'));
  return {role,doneWeek,doneTotal:done.length,next,plannedCount:planned.length,questions,deadlines,commits};
}

if(process.argv[1]&&process.argv[1].endsWith('digest.mjs')){
  const EX='_ai_workspace/_extracted';
  const sh=c=>{try{return execSync(c,{encoding:'utf8'}).trim()}catch{return''}};
  const d=buildDigest({
    tasksMd:readFileSync(`${EX}/tasks.md`,'utf8'),
    questionsMd:readFileSync(`${EX}/questions.md`,'utf8'),
    commits:sh('git log --since=7.days --oneline').split('\n').filter(Boolean),
    role:getRole(),
  });
  console.log(`📰 НЕДЕЛЬНЫЙ ДАЙДЖЕСТ — роль: ${roleLabel(d.role)}${d.role==='superadmin'?' (всё)':''}\n`);
  console.log(`✅ Сделано за неделю: ${d.doneWeek.length} задач (коммитов: ${d.commits.length}) · всего закрыто ${d.doneTotal}`);
  d.doneWeek.slice(0,5).forEach(t=>console.log(`   · ${t.id} ${t.title.slice(0,70)}`));
  console.log(`\n⏭️ Далее (фокус роли, всего в очереди ${d.plannedCount}):`);
  d.next.forEach(t=>console.log(`   · ${t.id} [${t.prio||'—'}] ${t.title.slice(0,70)}`));
  console.log(`\n❓ Вопросы (${d.questions.length}): ${d.questions.map(q=>q.id).join(', ')||'нет'}`);
  d.questions.slice(0,3).forEach(q=>console.log(`   · ${q.id}: ${q.essence.slice(0,70)}`));
  console.log(`\n⏰ Дедлайны (${d.deadlines.length}):`);
  if(!d.deadlines.length)console.log('   нет задач с дедлайнами');
  else d.deadlines.forEach(t=>console.log(`   · ${t.id} ${t.title.slice(0,70)}`));
}
