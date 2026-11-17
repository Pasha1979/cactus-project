// brain:role (T-204, I-192, D-68) — показать текущую роль мозга и её фокус-модули.
// Роль хранится в профиле: _ai_workspace/brain.config.json → "role". Суперадмин видит всё.
import {getRole,roleLabel,ROLES} from './lib/role.mjs';

const role=getRole();
console.log(`👤 Роль мозга: ${roleLabel(role)} (${role})`);
const info=ROLES[role];
if(info.modules===null)console.log('   Доступ: полный — все модули, все выводы без фильтра');
else console.log(`   Фокус-модули: ${info.modules.join(', ')}`);
console.log('\n   Смена роли: правка "role" в _ai_workspace/brain.config.json');
console.log(`   Доступные: ${Object.keys(ROLES).join(', ')}`);
