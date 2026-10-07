/** 配色（对应 Kotlin 版 ui/Theme.kt 的 ExtraColors + ColorScheme） */
export class Palette {
  bg: string = '#F4F4F6';
  card: string = '#FFFFFF';
  chip: string = '#F1F2F4';
  subtle: string = '#8A8F98';
  good: string = '#3FA36B';
  warn: string = '#DB9A1F';
  bad: string = '#E05050';
  up: string = '#7C5CFF';
  down: string = '#16A6E8';
  text: string = '#1D2025';
  primary: string = '#2B3036';
  onPrimary: string = '#FFFFFF';
  outline: string = '#D5D8DD';
  outlineVariant: string = '#E8EAED';
  sheet: string = '#F4F4F6';
  info: string = '#38BDF8';
  /** 主题色（按钮、选中项、开关、图表等） */
  accent: string = '#0A59F7';
  /** 主题色上的文字/图标颜色 */
  onAccent: string = '#FFFFFF';
  /** 主题色的浅色底（选中背景、高亮 chip） */
  accentSoft: string = '#240A59F7';
  dark: boolean = false;
}

/** 预置主题色 */
export class AccentDef {
  key: string;
  name: string;
  light: string;
  dark: string;

  constructor(key: string, name: string, light: string, dark: string) {
    this.key = key;
    this.name = name;
    this.light = light;
    this.dark = dark;
  }
}

export const ACCENTS: AccentDef[] = [
  new AccentDef('blue', '星河蓝', '#0A59F7', '#3F7CFF'),
  new AccentDef('orange', '橘黄黄', '#F39A2B', '#F7AE52'),
  new AccentDef('cat', '猫咪蓝', '#3F5683', '#7088B8'),
  new AccentDef('red', '华为红', '#CF0A2C', '#EE4A61'),
  new AccentDef('purple', '优雅紫', '#8A5CD1', '#A47FE0'),
  new AccentDef('pink', '哔哩粉', '#FB7299', '#FC8DAE'),
  new AccentDef('green', '小草绿', '#7BC23E', '#93D15E')
];

export function findAccent(key: string): AccentDef {
  for (const a of ACCENTS) {
    if (a.key === key) {
      return a;
    }
  }
  return ACCENTS[0];
}

function hex2(n: number): string {
  const v = Math.max(0, Math.min(255, Math.round(n)));
  const h = v.toString(16).toUpperCase();
  return h.length < 2 ? '0' + h : h;
}

/** 两个 '#RRGGBB' 颜色按比例 t(0..1) 混合 */
export function mixColor(a: string, b: string, t: number): string {
  const pa = a.length === 9 ? a.substring(3) : a.substring(1);
  const pb = b.length === 9 ? b.substring(3) : b.substring(1);
  let out = '#';
  for (let i = 0; i < 3; i++) {
    const x = parseInt(pa.substring(i * 2, i * 2 + 2), 16);
    const y = parseInt(pb.substring(i * 2, i * 2 + 2), 16);
    out += hex2(x + (y - x) * t);
  }
  return out;
}

/** 把主题色应用到配色上 */
export function applyAccent(p: Palette, a: AccentDef): Palette {
  const c = p.dark ? a.dark : a.light;
  p.accent = c;
  p.onAccent = '#FFFFFF';
  p.accentSoft = withAlpha(c, p.dark ? 0.24 : 0.14);
  p.primary = c;
  p.onPrimary = '#FFFFFF';
  // 流量图：下载用主题色，上传用主题色的浅色调，保证两条线可区分且统一风格
  p.down = c;
  p.up = p.dark ? mixColor(c, '#FFFFFF', 0.45) : mixColor(c, '#FFFFFF', 0.5);
  return p;
}

export function lightPalette(): Palette {
  return new Palette();
}

export function darkPalette(): Palette {
  const p = new Palette();
  p.bg = '#111316';
  p.card = '#1C1F24';
  p.chip = '#262A31';
  p.subtle = '#8D939C';
  p.good = '#52C487';
  p.warn = '#F0B544';
  p.bad = '#F06A6A';
  p.up = '#9B85FF';
  p.down = '#40BDF5';
  p.text = '#E6E8EB';
  p.primary = '#E6E8EB';
  p.onPrimary = '#15181C';
  p.outline = '#3A3F47';
  p.outlineVariant = '#2C3037';
  p.sheet = '#111316';
  p.dark = true;
  return p;
}

/** '#RRGGBB' + alpha(0..1) -> '#AARRGGBB' */
export function withAlpha(hex: string, alpha: number): string {
  const a = Math.round(Math.max(0, Math.min(1, alpha)) * 255);
  const h = a.toString(16).toUpperCase();
  const aa = h.length < 2 ? '0' + h : h;
  const rgb = hex.length === 9 ? hex.substring(3) : hex.substring(1);
  return '#' + aa + rgb;
}
