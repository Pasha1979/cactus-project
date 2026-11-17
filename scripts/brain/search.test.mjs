// T-196 (I-184): тесты brain:search — критерий «находит «iCal» в архиве»
import {describe,it,expect} from 'vitest';
import {mkdtempSync,writeFileSync,mkdirSync} from 'fs';
import {join} from 'path';
import {tmpdir} from 'os';
import {search} from './search.mjs';

describe('brain:search',()=>{
  it('находит запрос в файлах и возвращает ID+фрагмент',()=>{
    const dir=mkdtempSync(join(tmpdir(),'brainsearch-'));
    mkdirSync(join(dir,'sub'),{recursive:true});
    writeFileSync(join(dir,'sub','plan.md'),'| I-42 | идея |\nЭкспорт: PDF, Excel, iCal\n');
    const hits=search('iCal',{root:dir});
    expect(hits).toHaveLength(1);
    expect(hits[0].file).toContain('plan.md');
    expect(hits[0].line).toBe(2);
    expect(hits[0].snippet).toContain('iCal');
  });
  it('извлекает ID из найденной строки',()=>{
    const dir=mkdtempSync(join(tmpdir(),'brainsearch-'));
    writeFileSync(join(dir,'ideas.md'),'| I-85 | TTS чтение вслух | ⏸️ |');
    const hits=search('TTS',{root:dir});
    expect(hits[0].ids).toContain('I-85');
  });
  it('реальный архив: находит «iCal» в ПЛАН_РАБОТ',()=>{
    const hits=search('iCal',{root:'_ai_workspace/_archive'});
    expect(hits.length).toBeGreaterThan(0);
    expect(hits.some(h=>h.file.includes('ПЛАН_РАБОТ'))).toBe(true);
  });
});
