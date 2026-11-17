// git-stats: общие утилиты «прогресс с момента X» для brain-скриптов (T-197, T-198)
import {execSync} from 'child_process';
import {readFileSync,existsSync} from 'fs';

export const sh=c=>{try{return execSync(c,{encoding:'utf8',stdio:['pipe','pipe','pipe']}).trim()}catch{return''}};

// Хеш коммита, записанный в первой строке файла (handoff/checkpoint хранят HEAD так)
export function recordedCommit(file){
  if(!existsSync(file))return null;
  const m=(readFileSync(file,'utf8').split('\n')[0]||'').match(/\b[0-9a-f]{7,40}\b/);
  return m?m[0]:null;
}

export function commitsSince(ref){
  if(!ref)return null;
  if(!sh(`git cat-file -t ${ref}`))return null;
  const n=parseInt(sh(`git rev-list --count ${ref}..HEAD`),10);
  return Number.isNaN(n)?null:n;
}

export function changedFilesSince(ref){
  if(!ref||!sh(`git cat-file -t ${ref}`))return null;
  const out=sh(`git diff --name-only ${ref}..HEAD`);
  return out?out.split('\n').filter(Boolean).length:0;
}

export function statsSince(file){
  const ref=recordedCommit(file);
  return {ref,commits:commitsSince(ref),changedFiles:changedFilesSince(ref)};
}
