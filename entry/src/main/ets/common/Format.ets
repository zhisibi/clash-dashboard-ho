/** 格式化工具（对应 Kotlin 版 ui/Common.kt 顶部函数） */

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
    return s + '秒';
  }
  if (s < 3600) {
    return Math.floor(s / 60) + '分' + (s % 60) + '秒';
  }
  if (s < 86400) {
    return Math.floor(s / 3600) + '时' + Math.floor((s % 3600) / 60) + '分';
  }
  return Math.floor(s / 86400) + '天' + Math.floor((s % 86400) / 3600) + '时';
}

export function fmtAgo(ms: number): string {
  if (ms <= 0) {
    return '-';
  }
  const d = Date.now() - ms;
  if (d < 60000) {
    return '刚刚';
  }
  if (d < 3600000) {
    return Math.floor(d / 60000) + ' 分钟前';
  }
  if (d < 86400000) {
    return Math.floor(d / 3600000) + ' 小时前';
  }
  return Math.floor(d / 86400000) + ' 天前';
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

/** yyyyMMdd-HHmmss，用于文件名 */
export function fmtStamp(ms: number): string {
  const d = new Date(ms);
  return d.getFullYear() + pad2(d.getMonth() + 1) + pad2(d.getDate()) + '-' +
    pad2(d.getHours()) + pad2(d.getMinutes()) + pad2(d.getSeconds());
}

export function modeName(m: string): string {
  if (m === 'rule') {
    return '规则';
  }
  if (m === 'global') {
    return '全局';
  }
  if (m === 'direct') {
    return '直连';
  }
  return m;
}

/** 安全构造正则：非法表达式返回 null，调用方回退为普通包含匹配 */
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
