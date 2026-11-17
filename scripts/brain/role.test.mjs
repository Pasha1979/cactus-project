// ролевая модель мозга (cactus) — критерий «смена роли меняет поведение»
import {describe,it,expect} from 'vitest';
import {mkdtempSync,mkdirSync,writeFileSync} from 'fs';
import {join} from 'path';
import {tmpdir} from 'os';
import {getRole,moduleMatches,rolesForModule,roleLabel} from './lib/role.mjs';

describe('brain:role-auto',()=>{
  it('суперадмин видит всё',()=>{
    expect(moduleMatches('уход','superadmin')).toBe(true);
    expect(moduleMatches('windows','superadmin')).toBe(true);
    expect(moduleMatches('мозг/автоматизация','superadmin')).toBe(true);
  });
  it('смена роли меняет поведение: продукт/уход ≠ платформы',()=>{
    expect(moduleMatches('уход/здоровье','gardener')).toBe(true);
    expect(moduleMatches('windows','gardener')).toBe(false);
    expect(moduleMatches('windows','platforms')).toBe(true);
    expect(moduleMatches('уход/здоровье','platforms')).toBe(false);
  });
  it('роль читается из профиля (brain.config.json)',()=>{
    const dir=mkdtempSync(join(tmpdir(),'brainrole-'));
    mkdirSync(join(dir,'_ai_workspace'),{recursive:true});
    writeFileSync(join(dir,'_ai_workspace','brain.config.json'),'{"role":"architect"}');
    expect(getRole(dir)).toBe('architect');
    writeFileSync(join(dir,'_ai_workspace','brain.config.json'),'{"role":"platforms"}');
    expect(getRole(dir)).toBe('platforms');
  });
  it('без профиля → superadmin',()=>{
    expect(getRole(mkdtempSync(join(tmpdir(),'brainrole-')))).toBe('superadmin');
  });
  it('rolesForModule: модуль → затронутые роли',()=>{
    const r=rolesForModule('синхронизация');
    expect(r).toContain('platforms');
    expect(r).not.toContain('gardener');
    expect(roleLabel('platforms')).toBe('Платформы/синк');
  });
});
