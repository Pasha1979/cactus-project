#!/usr/bin/env node
import {readdirSync,readFileSync,existsSync,statSync} from 'fs';
import {join,dirname,resolve,relative} from 'path';
const ROOT=process.cwd();
const SKIP=/node_modules|\.git|_archive|v3_snapshot|dist|build|_extracted\/CATALOG/;
const files=[];
(function walk(d){for(const f of readdirSync(d)){const p=join(d,f);if(SKIP.test(p))continue;
 if(statSync(p).isDirectory())walk(p);else if(f.endsWith('.md'))files.push(p)}})(ROOT);
const re=/\[[^\]]*\]\(([^)#\s]+)[^)]*\)/g;let bad=[];
for(const f of files){const txt=readFileSync(f,'utf8');let m;
 while((m=re.exec(txt))){const u=m[1];if(/^(https?:|mailto:|#|data:)/.test(u))continue;
  const t=resolve(dirname(f),decodeURIComponent(u));
  if(!existsSync(t))bad.push(`${relative(ROOT,f)}: → ${u}`)}}
if(bad.length){console.log(`❌ Битые ссылки (${bad.length}):`);bad.forEach(b=>console.log('  '+b));process.exit(1)}
console.log(`✅ check-links: ${files.length} md проверено, битых ссылок нет`);
