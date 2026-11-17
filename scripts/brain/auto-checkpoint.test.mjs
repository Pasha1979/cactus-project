// T-197 (I-185): тесты auto-checkpoint — критерий «симуляция порога триггерит checkpoint»
import {describe,it,expect} from 'vitest';
import {evaluate} from './auto-checkpoint.mjs';

const cfg={commits:5,changedFiles:15};

describe('brain:auto-checkpoint',()=>{
  it('триггерит при превышении порога коммитов',()=>{
    const r=evaluate({commits:6,changedFiles:3},cfg);
    expect(r.trigger).toBe(true);
    expect(r.reasons.join()).toContain('коммитов');
  });
  it('триггерит при превышении порога файлов',()=>{
    const r=evaluate({commits:1,changedFiles:20},cfg);
    expect(r.trigger).toBe(true);
    expect(r.reasons.join()).toContain('файлов');
  });
  it('триггерит при отсутствии маркера (первый запуск)',()=>{
    expect(evaluate({commits:null,changedFiles:null},cfg).trigger).toBe(true);
  });
  it('не триггерит в пределах порога',()=>{
    expect(evaluate({commits:4,changedFiles:14},cfg).trigger).toBe(false);
  });
  it('порог настраиваем (R-90): другой конфиг — другое поведение',()=>{
    expect(evaluate({commits:2,changedFiles:1},{commits:2,changedFiles:15}).trigger).toBe(true);
  });
});
