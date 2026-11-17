// T-205 (I-193): brain:lint — критерий «тест ловит дубль идеи»
import {describe,it,expect} from 'vitest';
import {lintRegistries} from './brain-lint.mjs';

const NOW=Date.parse('2026-11-16');
const idea=(id,text,title,status='💭',date='01.10.2026',links='—')=>`| ${id} | ${text} | ${title} | s | ${date} | m | ${status} | — | ${links} |`;
const task=(id,status,date,links='—')=>`| ${id} | x | y | s | ${date} | m | ${status} | P1 | ${links} |`;

describe('brain:lint',()=>{
  it('ловит fuzzy-дубль идеи',()=>{
    const md=[
      idea('I-1','экспорт расписания в Excel файл для отчётов','Экспорт Excel'),
      idea('I-2','экспорт расписания в Excel файл для отчётов','Excel-экспорт'),
      idea('I-3','совершенно другая идея про грим','Грим')].join('\n');
    const r=lintRegistries(md,'',{now:NOW});
    expect(r.dups.some(d=>d.a==='I-1'&&d.b==='I-2')).toBe(true);
    expect(r.dups.some(d=>d.b==='I-3')).toBe(false);
  });
  it('не предлагает слияние для помеченных дублей',()=>{
    const md=[
      idea('I-4','экспорт расписания в Excel файл','Экспорт'),
      idea('I-5','экспорт расписания в Excel файл','Экспорт2','💭','01.10.2026','дубль I-4')].join('\n');
    expect(lintRegistries(md,'',{now:NOW}).dups).toHaveLength(0);
  });
  it('ловит сироту: задача → несуществующая идея',()=>{
    const r=lintRegistries('',task('T-1','📅','16.11.2026','I-777'),{now:NOW});
    expect(r.orphans.some(o=>o.includes('I-777'))).toBe(true);
  });
  it('ловит сироту: идея → несуществующая задача',()=>{
    const r=lintRegistries(idea('I-6','x','y','📅','16.11.2026','T-777'),'',{now:NOW});
    expect(r.orphans.some(o=>o.includes('T-777'))).toBe(true);
  });
  it('ловит протухшие статусы',()=>{
    const r=lintRegistries(
      idea('I-7','x','y','💭','01.08.2026'),
      task('T-2','🔄','01.10.2026'),{now:NOW});
    expect(r.stale.some(s=>s.includes('T-2'))).toBe(true);
    expect(r.stale.some(s=>s.includes('I-7'))).toBe(true);
  });
});
