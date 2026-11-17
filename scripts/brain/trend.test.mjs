// T-202 (I-190): brain:trend — критерий «снапшот добавлен, тренд показан»
import {describe,it,expect} from 'vitest';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync} from 'fs';
import {join} from 'path';
import {tmpdir} from 'os';
import {execSync} from 'child_process';
import {computeSnapshot,formatTrend} from './trend.mjs';

const IDEAS='| I-1 | x | y | s | 01.11.2026 | m | 📅 | P1 | — |\n| I-2 | x | y | s | 01.11.2026 | m | ❌ | — | — |';
const TASKS='| T-1 | x | y | s | 01.11.2026 | m | ✅ 15.11 | P1 | I-1 |\n| T-2 | x | y | s | 01.11.2026 | m | 📅 | P1 | — |\n| T-3 | заглушка | y | s | 01.11.2026 | m | 🔄 | P1 | — |';

describe('brain:trend',()=>{
  it('computeSnapshot считает метрики',()=>{
    const s=computeSnapshot(IDEAS,TASKS,{testFiles:42,date:'2026-11-16'});
    expect(s.ideas).toBe(2);
    expect(s.tasksDone).toBe(1);
    expect(s.tasksPlanned).toBe(1);
    expect(s.tasksWip).toBe(1);
    expect(s.ideasRejected).toBe(1);
    expect(s.stubs).toBe(1);
    expect(s.testFiles).toBe(42);
  });
  it('formatTrend показывает историю и стрелки',()=>{
    const snaps=[
      computeSnapshot(IDEAS,TASKS,{date:'2026-11-15'}),
      computeSnapshot(IDEAS,TASKS+'\n| T-4 | x | y | s | 16.11.2026 | m | ✅ 16.11 | P1 | — |',{date:'2026-11-16'})];
    const t=formatTrend(snaps);
    expect(t).toContain('2026-11-16');
    expect(t).toContain('↑'); // ✅ выросло
  });
  it('CLI: снапшот пишется в trend.jsonl и не дублируется в тот же день',()=>{
    const dir=mkdtempSync(join(tmpdir(),'braintrend-'));
    const ws=join(dir,'_ai_workspace','_extracted');
    mkdirSync(ws,{recursive:true});
    writeFileSync(join(ws,'ideas.md'),IDEAS);
    writeFileSync(join(ws,'tasks.md'),TASKS);
    const script=join(process.cwd(),'scripts/brain/trend.mjs');
    const run=()=>execSync(`node "${script}"`,{cwd:dir,encoding:'utf8'});
    const out1=run(),out2=run();
    expect(out1).toContain('Снапшот записан');
    expect(out2).toContain('уже есть');
    const log=readFileSync(join(dir,'_ai_workspace/metrics/trend.jsonl'),'utf8').split('\n').filter(Boolean);
    expect(log).toHaveLength(1);
  });
});
