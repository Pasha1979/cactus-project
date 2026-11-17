// role (T-204, I-192, D-68): ролевая модель мозга — роль из профиля (brain.config.json → role).
// Суперадмин видит всё; остальные роли — фокус на своих модулях. Используется next/digest/boot.
import {readFileSync,existsSync} from 'fs';
import {join} from 'path';

// Роли cactus-project. modules: null = полный доступ (суперадмин)
export const ROLES = {
  superadmin: {label:'Суперадмин',modules:null},
  architect: {label:'Архитектор',modules:['архитектура','данные','миграция','hive','di','репозитор','провайдер','навигация','процесс','мозг']},
  gardener: {label:'Продукт/уход',modules:['уход','здоровье','фазы','планировщик','профиль','датчики','локации','каталог','дашборд','аналитика','уведомления','продукт','таксономия','размножение','карточка']},
  platforms: {label:'Платформы/синк',modules:['платформы','windows','android','синхронизация','qr','фото','экспорт','настройки','код']},
};

export function getRole(root='.'){
  const p=join(root,'_ai_workspace','brain.config.json');
  if(!existsSync(p))return 'superadmin';
  try{const r=(JSON.parse(readFileSync(p,'utf8')).role||'superadmin');return ROLES[r]?r:'superadmin'}catch{return 'superadmin'}
}

export const roleLabel=r=>(ROLES[r]||ROLES.superadmin).label;

// Совпадает ли ячейка «Модуль» записи с фокусом роли
export function moduleMatches(moduleCell,role){
  const info=ROLES[role];
  if(!info||info.modules===null)return true; // суперадмин / неизвестная — всё
  const m=moduleCell.toLowerCase();
  return info.modules.some(k=>m.includes(k));
}

// Роли, чьи модули пересекаются с ячейкой (для brain:impact)
export function rolesForModule(moduleCell){
  return Object.keys(ROLES).filter(r=>ROLES[r].modules!==null&&moduleMatches(moduleCell,r));
}
