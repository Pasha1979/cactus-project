// brain:digest — критерий «дайджест генерируется», роль фильтрует «далее» (cactus)
import {describe,it,expect} from 'vitest';
import {buildDigest} from './digest.mjs';

const NOW=Date.parse('2026-11-16');
const TASKS=[
'| T-1 | сделано на этой неделе | Задача А | s | 01.11.2026 | уход | ✅ 15.11.2026 | P1 | — |',
'| T-2 | сделано давно | Задача Б | s | 01.10.2026 | уход | ✅ 01.10.2026 | P1 | — |',
'| T-3 | след. по уходу | Задача В | s | 01.11.2026 | уход | 📅 | P1 | — |',
'| T-4 | след. windows | Задача Г | s | 01.11.2026 | windows | 📅 | P1 | — |',
'| T-5 | с дедлайном | Дедлайн релиза | s | 01.11.2026 | процесс | 📅 | P2 | — |'].join('\n');
const QUESTIONS='| Q-1 | вопрос? | Суть вопроса | s | 01.11.2026 | m | 💭 | — | — |';
const base={tasksMd:TASKS,questionsMd:QUESTIONS,commits:['abc123 x','def456 y'],now:NOW,days:7};

describe('brain:digest',()=>{
  it('генерирует сводку: сделано/далее/вопросы/дедлайны',()=>{
    const d=buildDigest({...base,role:'superadmin'});
    expect(d.doneWeek.map(t=>t.id)).toEqual(['T-1']);
    expect(d.commits).toHaveLength(2);
    expect(d.questions.map(q=>q.id)).toEqual(['Q-1']);
    expect(d.deadlines.map(t=>t.id)).toEqual(['T-5']);
    expect(d.next.length).toBe(3);
  });
  it('роль фильтрует «далее»: продукт/уход не видит windows',()=>{
    const d=buildDigest({...base,role:'gardener'});
    expect(d.next.map(t=>t.id)).toContain('T-3');
    expect(d.next.map(t=>t.id)).not.toContain('T-4');
    const s=buildDigest({...base,role:'superadmin'});
    expect(s.next.map(t=>t.id)).toContain('T-4');
  });
});
