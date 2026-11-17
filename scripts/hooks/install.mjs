#!/usr/bin/env node
// install (T-194, I-182): идемпотентная установка git-hooks из scripts/hooks → .git/hooks.
// Запускается автоматически через npm lifecycle "prepare" при npm install на свежем клоне.
import {readFileSync,writeFileSync,readdirSync,existsSync,mkdirSync,chmodSync} from 'fs';
import {join} from 'path';

const SRC='scripts/hooks',DST='.git/hooks';
if(!existsSync('.git')){console.log('ℹ️ hooks-install: .git нет (не клон?) — пропуск');process.exit(0)}
mkdirSync(DST,{recursive:true});
let installed=0,skipped=0;
for(const name of readdirSync(SRC).filter(f=>!f.endsWith('.mjs'))){
  const src=readFileSync(join(SRC,name));
  const dst=join(DST,name);
  if(existsSync(dst)&&readFileSync(dst).equals(src)){skipped++;continue}
  writeFileSync(dst,src);
  try{chmodSync(dst,0o755)}catch{}
  installed++;
}
console.log(`✅ hooks-install: ${installed} установлено, ${skipped} актуальных пропущено (идемпотентно)`);
