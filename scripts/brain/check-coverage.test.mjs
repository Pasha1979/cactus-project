// T-195 (I-183): тесты analyzeCoverage — критерий «тест ловит намеренно протухшую задачу»
import {describe,it,expect} from 'vitest';
import {analyzeCoverage} from './check-coverage.mjs';

const NOW=Date.parse('2026-11-16');
const idea=(id,status,prio,links='—')=>`| ${id} | текст | суть | источник | 16.11.2026 | модуль | ${status} | ${prio} | ${links} |`;
const task=(id,status,date,links='—',text='описание')=>`| ${id} | ${text} | раздел | источник | ${date} | модуль | ${status} | P1 | ${links} |`;

describe('brain:coverage',()=>{
  it('ловит принятую P1-идею без задачи',()=>{
    const w=analyzeCoverage([idea('I-900','📅','P1')].join('\n'),'');
    expect(w.some(x=>x.includes('I-900')&&x.includes('без задачи'))).toBe(true);
  });
  it('не ругается на идею, закрытую задачей (связь в задаче)',()=>{
    const w=analyzeCoverage([idea('I-901','📅','P1')].join('\n'),task('T-900','📅','16.11.2026','I-901'));
    expect(w.some(x=>x.includes('I-901'))).toBe(false);
  });
  it('не ругается на идею с T-ссылкой в своей колонке связей',()=>{
    const w=analyzeCoverage([idea('I-902','📅','P2','T-901')].join('\n'),'');
    expect(w.some(x=>x.includes('I-902'))).toBe(false);
  });
  it('ловит ✅-задачу без доказательства',()=>{
    const w=analyzeCoverage('',task('T-901','✅','16.11.2026','—','купить молоко'));
    expect(w.some(x=>x.includes('T-901')&&x.includes('без доказательства'))).toBe(true);
  });
  it('пропускает ✅-задачу с доказательством (коммит)',()=>{
    const w=analyzeCoverage('',task('T-902','✅','16.11.2026','—','коммит abc1234, тесты зелёные'));
    expect(w.some(x=>x.includes('T-902'))).toBe(false);
  });
  it('ловит протухшую 🔄-задачу (в работе > 14 дней)',()=>{
    const w=analyzeCoverage('',task('T-903','🔄','01.10.2026'),{now:NOW,staleDays:14});
    expect(w.some(x=>x.includes('T-903')&&x.includes('протухла'))).toBe(true);
  });
  it('пропускает свежую 🔄-задачу',()=>{
    const w=analyzeCoverage('',task('T-904','🔄','15.11.2026'),{now:NOW,staleDays:14});
    expect(w.some(x=>x.includes('T-904'))).toBe(false);
  });
  it('чистые реестры → ноль предупреждений',()=>{
    const w=analyzeCoverage(
      [idea('I-905','📅','P1','T-905'),idea('I-906','💭','P3')].join('\n'),
      task('T-905','✅','16.11.2026','I-905','коммит def5678'),
      {now:NOW});
    expect(w).toHaveLength(0);
  });
});
