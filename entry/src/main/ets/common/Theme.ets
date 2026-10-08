/** Palette (Kotlin ui/Theme.kt ExtraColors + ColorScheme) */
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
  /** Accent color (buttons, selection, switches, charts, ...) */
  accent: string = '#0A59F7';
  /** Text/icon color on the accent */
  onAccent: string = '#FFFFFF';
  /** Soft accent background (selection, highlighted chips) */
  accentSoft: string = '#240A59F7';
  dark: boolean = false;
}

/** Preset accent colors (nameKey is an i18n key) */
export class AccentDef {
  key: string;
  nameKey: string;
  light: string;
  dark: string;

  constructor(key: string, nameKey: string, light: string, dark: string) {
    this.key = key;
    this.nameKey = nameKey;
    this.light = light;
    this.dark = dark;
  }
}

export const ACCENTS: AccentDef[] = [
  new AccentDef('blue', 'accent_blue', '#0A59F7', '#3F7CFF'),
  new AccentDef('orange', 'accent_orange', '#F39A2B', '#F7AE52'),
  new AccentDef('cat', 'accent_cat', '#3F5683', '#7088B8'),
  new AccentDef('red', 'accent_red', '#CF0A2C', '#EE4A61'),
  new AccentDef('purple', 'accent_purple', '#8A5CD1', '#A47FE0'),
  new AccentDef('pink', 'accent_pink', '#FB7299', '#FC8DAE'),
  new AccentDef('green', 'accent_green', '#7BC23E', '#93D15E')
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

/** Mixes two '#RRGGBB' colors by ratio t (0..1) */
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

/** Applies an accent to a palette */
export function applyAccent(p: Palette, a: AccentDef): Palette {
  const c = p.dark ? a.dark : a.light;
  p.accent = c;
  p.onAccent = '#FFFFFF';
  p.accentSoft = withAlpha(c, p.dark ? 0.24 : 0.14);
  p.primary = c;
  p.onPrimary = '#FFFFFF';
  // Traffic chart: download uses the accent, upload a lighter tint, so both lines are distinct but consistent
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
