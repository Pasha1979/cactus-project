// auto-checkpoint (T-197, I-185): авто-CONTEXT_CHECKPOINT по бюджету контекста.
// Прокси-счётчик: коммиты + изменённые файлы с последнего checkpoint > порога → регенерация + уведомление.
// Порог настраиваем в _ai_workspace/brain.config.json → autoCheckpoint (R-90). Вызывается из post-commit hook.
import {statsSince} from './lib/git-stats.mjs';
import {loadConfig} from './check-coverage.mjs';
import {execSync} from 'child_process';

const CKPT='_ai_workspace/v4/CONTEXT_CHECKPOINT.md';

export function evaluate(stats,{commits=5,changedFiles=15}={}){
  const reasons=[];
  if(stats.commits===null||stats.changedFiles===null)reasons.push('нет маркера в checkpoint');
  else{
    if(stats.commits>=commits)reasons.push(`${stats.commits} коммитов ≥ ${commits}`);
    if(stats.changedFiles>=changedFiles)reasons.push(`${stats.changedFiles} файлов ≥ ${changedFiles}`);
  }
  return {trigger:reasons.length>0,reasons,stats};
}

if(process.argv[1]&&process.argv[1].endsWith('auto-checkpoint.mjs')){
  const cfg=loadConfig().autoCheckpoint||{};
  if(cfg.enabled===false)process.exit(0);
  const stats=statsSince(CKPT);
  const r=evaluate(stats,cfg);
  if(!r.trigger){if(process.argv.includes('--verbose'))console.log(`auto-checkpoint: в пределах порога (${stats.commits} комм., ${stats.changedFiles} файлов)`)}
  else{
    console.log(`🧷 auto-checkpoint: порог превышен (${r.reasons.join('; ')}) → регенерация CONTEXT_CHECKPOINT`);
    try{execSync('node scripts/brain/gen-checkpoint.mjs',{stdio:'inherit'})}catch(e){console.log('⚠️ auto-checkpoint: регенерация не удалась — '+e.message)}
  }
}
