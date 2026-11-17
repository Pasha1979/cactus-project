// brain:lesson — критерий «возвращает matching L-…» (cactus)
import {describe,it,expect} from 'vitest';
import {readFileSync} from 'fs';
import {findLessons} from './lesson.mjs';

const MD=[
'| L-1 | Автонумерация переписывала номера | Не модифицировать ввод | LESSONS | 30.05 | данные | — |',
'| L-10 | SharedPreferences без await → потеря | Ждать flush | LESSONS | 01.06 | persistence | — |',
'| L-20 | Тема reset убила отступы | Проверять reset | LESSONS | 10.06 | дизайн | — |'].join('\n');

describe('brain:lesson',()=>{
  it('находит уроки по теме модуля',()=>{
    const hits=findLessons(MD,'данные');
    expect(hits.map(h=>h.id)).toContain('L-1');
  });
  it('находит по тексту урока, не только по теме',()=>{
    const hits=findLessons(MD,'SharedPreferences');
    expect(hits.map(h=>h.id)).toContain('L-10');
  });
  it('нерелевантный модуль → пусто',()=>{
    expect(findLessons(MD,'космос')).toHaveLength(0);
  });
  it('реальный реестр: «миграция» возвращает L-…',()=>{
    const md=readFileSync('_ai_workspace/_extracted/lessons.md','utf8');
    expect(findLessons(md,'миграция').length).toBeGreaterThan(0);
  });
});
