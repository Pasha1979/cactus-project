// T-198 (I-186): тесты context-guard — критерий «предупреждает в тесте»
import {describe,it,expect} from 'vitest';
import {analyze} from './check-context-guard.mjs';

const fresh={commits:0,changedFiles:2},cfg={handoffCommits:3,checkpointCommits:5,checkpointChangedFiles:20};

describe('brain:context-guard',()=>{
  it('предупреждает при протухшем handoff',()=>{
    const w=analyze({commits:5,changedFiles:10},fresh,cfg);
    expect(w.some(x=>x.includes('SESSION_HANDOFF'))).toBe(true);
  });
  it('предупреждает при протухшем checkpoint (коммиты)',()=>{
    const w=analyze(fresh,{commits:8,changedFiles:3},cfg);
    expect(w.some(x=>x.includes('CONTEXT_CHECKPOINT'))).toBe(true);
  });
  it('предупреждает при большом объёме изменений с checkpoint',()=>{
    const w=analyze(fresh,{commits:2,changedFiles:30},cfg);
    expect(w.some(x=>x.includes('файлов'))).toBe(true);
  });
  it('предупреждает при отсутствии маркера',()=>{
    const w=analyze({commits:null,changedFiles:null},fresh,cfg);
    expect(w.some(x=>x.includes('без маркера'))).toBe(true);
  });
  it('свежие handoff+checkpoint → без предупреждений',()=>{
    expect(analyze(fresh,fresh,cfg)).toHaveLength(0);
  });
});
