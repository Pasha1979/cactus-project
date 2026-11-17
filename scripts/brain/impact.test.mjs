// brain:impact — критерий «возвращает маппинг модули/роли» (cactus)
import {describe,it,expect} from 'vitest';
import {impactOf} from './impact.mjs';

const MD=[
'| I-10 | идея про синк | Синхронизация фото | источник | 01.11.2026 | синхронизация | 📅 | P1 | I-67 |',
'| I-20 | идея про здоровье | Журнал здоровья | источник | 01.11.2026 | здоровье | 💭 | P3 | — |'].join('\n');

describe('brain:impact',()=>{
  it('возвращает маппинг: модуль + затронутые роли',()=>{
    const r=impactOf(MD,'I-10');
    expect(r.module).toBe('синхронизация');
    expect(r.roles).toContain('Платформы/синк');
    expect(r.roles).not.toContain('Продукт/уход');
  });
  it('узкий модуль → меньше ролей',()=>{
    const r=impactOf(MD,'I-20');
    expect(r.roles).toContain('Продукт/уход');
    expect(r.roles).not.toContain('Архитектор');
  });
  it('неизвестный ID → null',()=>{
    expect(impactOf(MD,'I-999')).toBeNull();
  });
});
