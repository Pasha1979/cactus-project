// context-guard (T-198, I-186): страж свежести контекста — warning в brain:check (не блокирует).
// Предупреждает, если handoff/checkpoint давно не обновлялись при заметном объёме изменений.
import {statsSince} from './lib/git-stats.mjs';
import {loadConfig} from './check-coverage.mjs';

const HANDOFF='_ai_workspace/v4/SESSION_HANDOFF.md';
const CKPT='_ai_workspace/v4/CONTEXT_CHECKPOINT.md';

export function analyze(handoff,ckpt,{handoffCommits=3,checkpointCommits=5,checkpointChangedFiles=20}={}){
  const warnings=[];
  if(handoff.commits===null)warnings.push('guard: SESSION_HANDOFF без маркера коммита — запусти npm run brain:handoff');
  else if(handoff.commits>handoffCommits)warnings.push(`guard: SESSION_HANDOFF отстаёт на ${handoff.commits} коммитов (порог ${handoffCommits}) — npm run brain:handoff`);
  if(ckpt.commits===null)warnings.push('guard: CONTEXT_CHECKPOINT без маркера — npm run brain:checkpoint');
  else{
    if(ckpt.commits>checkpointCommits)warnings.push(`guard: CONTEXT_CHECKPOINT отстаёт на ${ckpt.commits} коммитов (порог ${checkpointCommits}) — npm run brain:checkpoint`);
    if(ckpt.changedFiles>checkpointChangedFiles)warnings.push(`guard: с checkpoint изменено ${ckpt.changedFiles} файлов (порог ${checkpointChangedFiles}) — контекст под риском`);
  }
  return warnings;
}

if(process.argv[1]&&process.argv[1].endsWith('check-context-guard.mjs')){
  const warnings=analyze(statsSince(HANDOFF),statsSince(CKPT),loadConfig().contextGuard||{});
  if(!warnings.length)console.log('✅ context-guard: handoff и checkpoint свежие относительно объёма изменений');
  else{console.log(`⚠️ context-guard: ${warnings.length} предупреждений (не блокирует):`);warnings.forEach(w=>console.log('   ⚠️ '+w))}
}
