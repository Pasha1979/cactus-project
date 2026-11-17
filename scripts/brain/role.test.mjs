// T-204 (I-192, D-68): ролевая модель мозга — критерий «смена роли меняет поведение»
import {describe,it,expect} from 'vitest';
import {mkdtempSync,mkdirSync,writeFileSync} from 'fs';
import {join} from 'path';
import {tmpdir} from 'os';
import {getRole,moduleMatches,rolesForModule,roleLabel} from './lib/role.mjs';

describe('brain:role-auto',()=>{
  it('суперадмин видит всё',()=>{
    expect(moduleMatches('вызывные','superadmin')).toBe(true);
    expect(moduleMatches('костюмы','superadmin')).toBe(true);
    expect(moduleMatches('мозг/автоматизация','superadmin')).toBe(true);
  });
  it('смена роли меняет поведение: сценарист ≠ 2-й режиссёр',()=>{
    expect(moduleMatches('сценарий/текст','scenarist')).toBe(true);
    expect(moduleMatches('вызывные','scenarist')).toBe(false);
    expect(moduleMatches('вызывные','second_ad')).toBe(true);
    expect(moduleMatches('сценарий/текст','second_ad')).toBe(false);
  });
  it('роль читается из профиля (brain.config.json)',()=>{
    const dir=mkdtempSync(join(tmpdir(),'brainrole-'));
    mkdirSync(join(dir,'_ai_workspace'),{recursive:true});
    writeFileSync(join(dir,'_ai_workspace','brain.config.json'),'{"role":"scenarist"}');
    expect(getRole(dir)).toBe('scenarist');
    writeFileSync(join(dir,'_ai_workspace','brain.config.json'),'{"role":"producer"}');
    expect(getRole(dir)).toBe('producer');
  });
  it('без профиля → superadmin',()=>{
    expect(getRole(mkdtempSync(join(tmpdir(),'brainrole-')))).toBe('superadmin');
  });
  it('rolesForModule: модуль → затронутые роли',()=>{
    const r=rolesForModule('вызывные');
    expect(r).toContain('second_ad');
    expect(r).toContain('director');
    expect(r).not.toContain('costumer');
    expect(roleLabel('second_ad')).toBe('2-й режиссёр');
  });
});
