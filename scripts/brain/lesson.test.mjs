// T-200 (I-188): brain:lesson — критерий «возвращает matching L-…»
import {describe,it,expect} from 'vitest';
import {readFileSync} from 'fs';
import {findLessons} from './lesson.mjs';

const MD=[
'| L-1 | Автонумерация переписывала номера | Не модифицировать ввод | LESSONS | 30.05 | редактор | — |',
'| L-10 | Zustand persist без await → потеря | Ждать flush | LESSONS | 01.06 | стор/персист | — |',
'| L-20 | Tailwind reset убил отступы | Проверять reset | LESSONS | 10.06 | дизайн | — |'].join('\n');

describe('brain:lesson',()=>{
  it('находит уроки по теме модуля',()=>{
    const hits=findLessons(MD,'редактор');
    expect(hits.map(h=>h.id)).toContain('L-1');
  });
  it('находит по тексту урока, не только по теме',()=>{
    const hits=findLessons(MD,'persist');
    expect(hits.map(h=>h.id)).toContain('L-10');
  });
  it('нерелевантный модуль → пусто',()=>{
    expect(findLessons(MD,'космос')).toHaveLength(0);
  });
  it('реальный реестр: «редактор» возвращает L-…',()=>{
    const md=readFileSync('_ai_workspace/_extracted/lessons.md','utf8');
    expect(findLessons(md,'редактор').length).toBeGreaterThan(0);
  });
});
