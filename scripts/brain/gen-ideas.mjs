#!/usr/bin/env node
// gen-ideas: 05_ИДЕИ.md — автоген-индекс из _extracted/ideas.md (группировка по модулям)
// полные цитаты и метаданные — в _extracted/ideas.md; здесь дайджест: ID + суть + статус + источник
import {readFileSync,writeFileSync} from 'fs';
const EX='_ai_workspace/_extracted';
const rows=readFileSync(`${EX}/ideas.md`,'utf8').split('\n').filter(l=>/^\|\s*I-\d+/.test(l));
const cell=(l,i)=>(l.split('|').map(s=>s.trim())[i]||'');
const groups=new Map();
for(const l of rows){
 const mod=cell(l,6)||'прочее';
 if(!groups.has(mod))groups.set(mod,[]);
 groups.get(mod).push(l);
}
// порядок групп: ядро продукта → модули → прочее; внутри — по номеру ID
const order=['продукт','уход','здоровье','фазы','планировщик','уведомления','локации','каталог','дашборд','аналитика','таксономия','размножение','карточка','профиль','датчики','фото','qr','данные','синхронизация','настройки','экспорт','архитектура','платформы','windows','код','процесс','дизайн','мозг'];
const keys=[...groups.keys()].sort((a,b)=>{
 const ia=order.indexOf(a),ib=order.indexOf(b);
 return (ia<0?99:ia)-(ib<0?99:ib)||a.localeCompare(b,'ru');
});
const num=l=>+cell(l,1).replace(/\D/g,'');
const date=new Date().toISOString().slice(0,10);
let md=`# 05 · ИДЕИ — индекс (автогенерируемый — НЕ редактировать руками)
> Сгенерировано scripts/brain/gen-ideas.mjs · ${date} · ${rows.length} идей · Полные цитаты/источники/дубли: _extracted/ideas.md
> Обновить: npm run brain:ideas

`;
for(const k of keys){
 md+=`## ${k[0].toUpperCase()+k.slice(1)} (${groups.get(k).length})\n`;
 for(const l of groups.get(k).sort((a,b)=>num(a)-num(b)))
  md+=`| ${cell(l,1)} | ${cell(l,3)} | ${cell(l,7)} | ${cell(l,4).slice(0,45)} |\n`;
 md+='\n';
}
writeFileSync('_ai_workspace/v4/05_ИДЕИ.md',md);
console.log(`✅ 05_ИДЕИ: ${rows.length} идей · ${keys.length} модулей · ${md.length} символов`);
