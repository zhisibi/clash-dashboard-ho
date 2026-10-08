import { t } from './I18n';

/** Formatting helpers (Kotlin ui/Common.kt top-level functions) */

const UNITS: string[] = ['KB', 'MB', 'GB', 'TB', 'PB'];

export function fmtBytes(b: number): string {
  if (b < 1024) {
    return Math.max(0, Math.floor(b)).toString() + ' B';
  }
  let v = b / 1024;
  let i = 0;
  while (v >= 1024 && i < UNITS.length - 1) {
    v = v / 1024;
    i++;
  }
  const s = v >= 100 ? v.toFixed(0) : (v >= 10 ? v.toFixed(1) : v.toFixed(2));
  return s + ' ' + UNITS[i];
}

export function fmtSpeed(b: number): string {
  return fmtBytes(b) + '/s';
}

export function fmtDuration(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000));
  if (s < 60) {
    return t('dur_s', s);
  }
  if (s < 3600) {
    return t('dur_ms', Math.floor(s / 60), s % 60);
  }
  if (s < 86400) {
    return t('dur_hm', Math.floor(s / 3600), Math.floor((s % 3600) / 60));
  }
  return t('dur_dh', Math.floor(s / 86400), Math.floor((s % 86400) / 3600));
}

export function fmtAgo(ms: number): string {
  if (ms <= 0) {
    return '-';
  }
  const d = Date.now() - ms;
  if (d < 60000) {
    return t('ago_now');
  }
  if (d < 3600000) {
    return t('ago_min', Math.floor(d / 60000));
  }
  if (d < 86400000) {
    return t('ago_hour', Math.floor(d / 3600000));
  }
  return t('ago_day', Math.floor(d / 86400000));
}

export function pad2(n: number): string {
  return n < 10 ? '0' + n : '' + n;
}

export function fmtClock(ms: number): string {
  const d = new Date(ms);
  return pad2(d.getHours()) + ':' + pad2(d.getMinutes()) + ':' + pad2(d.getSeconds());
}

export function fmtDate(ms: number): string {
  const d = new Date(ms);
  return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}

export function fmtDateTime(ms: number): string {
  return fmtDate(ms) + ' ' + fmtClock(ms);
}

/** yyyyMMdd-HHmmss, for file names */
export function fmtStamp(ms: number): string {
  const d = new Date(ms);
  return d.getFullYear() + pad2(d.getMonth() + 1) + pad2(d.getDate()) + '-' +
    pad2(d.getHours()) + pad2(d.getMinutes()) + pad2(d.getSeconds());
}

export function modeName(m: string): string {
  if (m === 'rule') {
    return t('mode_rule');
  }
  if (m === 'global') {
    return t('mode_global');
  }
  if (m === 'direct') {
    return t('mode_direct');
  }
  return m;
}

/** Builds a RegExp safely: returns null for an invalid pattern so callers fall back to substring matching */
export function safeRegex(q: string): RegExp | null {
  if (q.trim().length === 0) {
    return null;
  }
  try {
    return new RegExp(q, 'i');
  } catch (e) {
    return null;
  }
}

export function textMatch(re: RegExp | null, q: string, s: string): boolean {
  if (q.trim().length === 0) {
    return true;
  }
  if (re !== null) {
    return re.test(s);
  }
  return s.toLowerCase().indexOf(q.toLowerCase()) >= 0;
}
