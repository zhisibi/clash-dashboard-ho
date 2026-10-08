import { i18n } from '@kit.LocalizationKit';
import { ZH } from './i18n/StringsZh';
import { EN } from './i18n/StringsEn';

/**
 * In-app language (1.2.0).
 *
 * Every user-visible string goes through t(key). The tables live in i18n/StringsZh.ets and i18n/StringsEn.ets.
 * I18N.lang is a @Trace property, so any build() that calls t() re-renders when the language changes; Index also
 * re-creates its page tree keyed by the language, so the switch is immediate and complete without a restart.
 *
 * pref: 'system' | 'zh' | 'en' (persisted in Preferences key `lang`); lang: the effective 'zh' | 'en'.
 */
@ObservedV2
export class I18nState {
  @Trace pref: string = 'system';
  @Trace lang: string = 'zh';
}

export const I18N: I18nState = new I18nState();

export const LANG_KEYS: string[] = ['system', 'zh', 'en'];

/** Current system language mapped to a supported UI language: Chinese for zh-*, English for everything else. */
export function systemLang(): string {
  try {
    const l = i18n.System.getSystemLanguage().toLowerCase();
    return l.startsWith('zh') ? 'zh' : 'en';
  } catch (e) {
    return 'zh';
  }
}

function resolve(pref: string): string {
  if (pref === 'zh' || pref === 'en') {
    return pref;
  }
  return systemLang();
}

/** Keep resource lookups ($r strings, system component texts) in step with the in-app language. */
function applyAppPreferred(pref: string, atStartup: boolean): void {
  try {
    if (pref === 'zh') {
      i18n.System.setAppPreferredLanguage('zh-Hans');
    } else if (pref === 'en') {
      i18n.System.setAppPreferredLanguage('en-Latn-US');
    } else if (atStartup) {
      // 'default' = follow the system again; the system applies it from the next launch
      i18n.System.setAppPreferredLanguage('default');
    } else {
      // switching back to "follow system" at runtime: pin the current system language so it applies right away
      i18n.System.setAppPreferredLanguage(i18n.System.getSystemLanguage());
    }
  } catch (e) {
    // ignore: the in-app table does not depend on this
  }
}

/** Called once at startup with the saved preference. */
export function initLang(pref: string): void {
  const p = LANG_KEYS.indexOf(pref) >= 0 ? pref : 'system';
  I18N.pref = p;
  I18N.lang = resolve(p);
  applyAppPreferred(p, true);
}

/** User picked a language in Settings: applies immediately. Returns true when the effective language changed. */
export function setLangPref(pref: string): boolean {
  const p = LANG_KEYS.indexOf(pref) >= 0 ? pref : 'system';
  const before = I18N.lang;
  I18N.pref = p;
  applyAppPreferred(p, false);
  const next = resolve(p);
  if (next !== I18N.lang) {
    I18N.lang = next;
  }
  return before !== next;
}

/** System language changed while running (EntryAbility.onConfigurationUpdate). */
export function onSystemLangChanged(): void {
  if (I18N.pref !== 'system') {
    return;
  }
  const next = systemLang();
  if (next !== I18N.lang) {
    I18N.lang = next;
  }
}

export function isEn(): boolean {
  return I18N.lang === 'en';
}

/**
 * Look up a UI string. `{0}`, `{1}` … in the text are replaced by args.
 * Reading I18N.lang here makes every caller inside build() depend on the language.
 */
export function t(key: string, ...args: (string | number)[]): string {
  const table: Record<string, string> = I18N.lang === 'en' ? EN : ZH;
  let s: string | undefined = table[key];
  if (s === undefined) {
    s = ZH[key];
  }
  if (s === undefined) {
    return key;
  }
  let out: string = s;
  for (let i = 0; i < args.length; i++) {
    out = out.split('{' + i + '}').join(String(args[i]));
  }
  return out;
}

/** Native name of a language option, shown the same in every UI language. */
export function langOptionLabel(key: string): string {
  if (key === 'zh') {
    return ZH['lang_name_zh'];
  }
  if (key === 'en') {
    return EN['lang_name_en'];
  }
  return t('lang_system');
}

/** The text of a key in both languages (used for settings search so either language matches). */
export function bothLangs(key: string): string {
  const z: string | undefined = ZH[key];
  const e: string | undefined = EN[key];
  return (z !== undefined ? z : '') + ' ' + (e !== undefined ? e : '');
}
