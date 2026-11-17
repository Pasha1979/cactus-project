#!/usr/bin/env node
// check-handoff: индикатор протухания SESSION_HANDOFF.md
// В handoff записан HEAD на момент генерации; если он отстаёт от текущего —
// handoff не отражает реальное состояние. Отставание на 1 коммит — норма
// (сам коммит обновлённого handoff сдвигает HEAD).
import {execSync} from 'child_process';
import {readFileSync,existsSync} from 'fs';
const sh=c=>{try{return execSync(c,{encoding:'utf8'}).trim()}catch{return''}};
const file='_ai_workspace/v4/SESSION_HANDOFF.md';
if(!existsSync(file)){console.log('⚠️ check-handoff: SESSION_HANDOFF.md отсутствует — запусти npm run brain:handoff');process.exit(0)}
const firstLine=readFileSync(file,'utf8').split('\n')[0]||'';
const m=firstLine.match(/\b[0-9a-f]{7,}\b/);
if(!m){console.log('⚠️ check-handoff: в handoff не найден хеш коммита — запусти npm run brain:handoff');process.exit(0)}
const recorded=m[0], head=sh('git rev-parse --short HEAD');
if(recorded===head){console.log(`✅ check-handoff: актуален (HEAD ${head})`);process.exit(0)}
const behind=parseInt(sh(`git rev-list --count ${recorded}..HEAD`)||'0',10);
if(behind<=1){
  console.log(`✅ check-handoff: почти актуален — записан ${recorded}, HEAD ${head} (отставание ${behind} — норма после коммита handoff)`);
}else{
  console.log(`⚠️ check-handoff: УСТАРЕЛ на ${behind} коммитов — записан ${recorded}, HEAD ${head}. Запусти npm run brain:handoff перед концом сессии`);
}
