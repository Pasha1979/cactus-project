// T-201 (I-189): brain:impact — критерий «возвращает маппинг модули/роли»
import {describe,it,expect} from 'vitest';
import {impactOf} from './impact.mjs';

const MD=[
'| I-10 | идея про вызывные | Вызывной лист | источник | 01.11.2026 | вызывные | 📅 | P1 | I-67 |',
'| I-20 | идея про грим | Образы грима | источник | 01.11.2026 | грим | 💭 | P3 | — |'].join('\n');

describe('brain:impact',()=>{
  it('возвращает маппинг: модуль + затронутые роли',()=>{
    const r=impactOf(MD,'I-10');
    expect(r.module).toBe('вызывные');
    expect(r.roles).toContain('2-й режиссёр');
    expect(r.roles).toContain('Режиссёр');
    expect(r.roles).not.toContain('Костюмер');
  });
  it('узкий модуль → меньше ролей',()=>{
    const r=impactOf(MD,'I-20');
    expect(r.roles).toContain('Гримёр');
    expect(r.roles).not.toContain('Продюсер');
  });
  it('неизвестный ID → null',()=>{
    expect(impactOf(MD,'I-999')).toBeNull();
  });
});
