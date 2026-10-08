/** Palette (Kotlin ui/Theme.kt ExtraColors + ColorScheme) */
export class Palette {
  bg: string = '#F4F4F6';
  card: string = '#FFFFFF';
  chip: string = '#F1F2F4';
  // 1.2.1: secondary/status colors darkened so text reaches WCAG 4.5:1 on cards, chips and translucent glass cards
  subtle: string = '#5A5E66';
  good: string = '#296945';
  warn: string = '#7C5712';
  bad: string = '#B62020';
  up: string = '#7C5CFF';
  down: string = '#16A6E8';
  text: string = '#1D2025';
  primary: string = '#2B3036';
  onPrimary: string = '#FFFFFF';
  outline: string = '#D5D8DD';
  outlineVariant: string = '#E8EAED';
  sheet: string = '#F4F4F6';
  info: string = '#05648E';
  /** Accent for TEXT on cards/pages (links, selected labels, tags): >= 4.5:1 */
  accent: string = '#0646C8';
  /** Accent for ICONS and controls (switches, radios, progress, nav icon, checkmarks): >= 3:1 */
  accentUi: string = '#0A59F7';
  /** Original vivid accent for pure decoration (backdrop gradient, glow, swatches); never for text */
  accentFill: string = '#0A59F7';
  /** Text/icon color on the accent fill (= onPrimary) */
  onAccent: string = '#FFFFFF';
  /** Soft accent background (selection, highlighted chips) */
  accentSoft: string = '#240A59F7';
  /** Upload / download colors for text (>= 4.5:1); up/down above are for icons and charts */
  upText: string = '#7C5CFF';
  downText: string = '#16A6E8';
  dark: boolean = false;
}

/** One mode's accent tokens (checked by scripts/check-contrast.py) */
export class AccentTone {
  /** Icons/controls, >= 3:1 on every surface */
  ui: string;
  /** Text, >= 4.5:1 on every surface */
  text: string;
  /** Button fill */
  fill: string;
  /** Text on the button fill, >= 4.5:1 */
  on: string;

  constructor(ui: string, text: string, fill: string, on: string) {
    this.ui = ui;
    this.text = text;
    this.fill = fill;
    this.on = on;
  }
}

/** Preset accent colors (nameKey is an i18n key). light/dark are the original brand colors (swatches, decoration). */
export class AccentDef {
  key: string;
  nameKey: string;
  light: string;
  dark: string;
  lt: AccentTone;
  dk: AccentTone;

  constructor(key: string, nameKey: string, light: string, dark: string, lt: AccentTone, dk: AccentTone) {
    this.key = key;
    this.nameKey = nameKey;
    this.light = light;
    this.dark = dark;
    this.lt = lt;
    this.dk = dk;
  }
}

// 1.2.1 (AppGallery contrast check): light presets that can't carry white text (orange / pink / green) keep their
// vivid fill with dark text; text/icon accents are darkened (light) or lightened (dark) just enough for WCAG.
export const ACCENTS: AccentDef[] = [
  new AccentDef('blue', 'accent_blue', '#0A59F7', '#3F7CFF',
    new AccentTone('#0A59F7', '#0646C8', '#0A59F7', '#FFFFFF'), new AccentTone('#588DFF', '#8EB2FF', '#246AFF', '#FFFFFF')),
  new AccentDef('orange', 'accent_orange', '#F39A2B', '#F7AE52',
    new AccentTone('#B86B0A', '#915408', '#F39A2B', '#1D2025'), new AccentTone('#F7AE52', '#FACB8E', '#F7AE52', '#15181C')),
  new AccentDef('cat', 'accent_cat', '#3F5683', '#7088B8',
    new AccentTone('#3F5683', '#3F5683', '#3F5683', '#FFFFFF'), new AccentTone('#7D93BE', '#A6B5D3', '#5975AD', '#FFFFFF')),
  new AccentDef('red', 'accent_red', '#CF0A2C', '#EE4A61',
    new AccentTone('#CF0A2C', '#A20723', '#CF0A2C', '#FFFFFF'), new AccentTone('#F05B70', '#F593A0', '#E81633', '#FFFFFF')),
  new AccentDef('purple', 'accent_purple', '#8A5CD1', '#A47FE0',
    new AccentTone('#8A5CD1', '#6C37BF', '#8A5CD1', '#FFFFFF'), new AccentTone('#A885E1', '#C5AEEB', '#8B5CD7', '#FFFFFF')),
  new AccentDef('pink', 'accent_pink', '#FB7299', '#FC8DAE',
    new AccentTone('#EC0748', '#B90538', '#FB7299', '#1D2025'), new AccentTone('#FC8DAE', '#FDBACE', '#FC8DAE', '#15181C')),
  new AccentDef('green', 'accent_green', '#7BC23E', '#93D15E',
    new AccentTone('#598C2C', '#456D22', '#7BC23E', '#1D2025'), new AccentTone('#93D15E', '#AFDD87', '#93D15E', '#15181C'))
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
  const tone = p.dark ? a.dk : a.lt;
  p.accentFill = p.dark ? a.dark : a.light;
  p.accent = tone.text;
  p.accentUi = tone.ui;
  p.accentSoft = withAlpha(tone.ui, p.dark ? 0.20 : 0.11);
  p.primary = tone.fill;
  p.onPrimary = tone.on;
  p.onAccent = tone.on;
  // Traffic: download uses the accent, upload a shade of it (lighter on dark, deeper on light so it stays readable)
  p.down = tone.ui;
  p.up = p.dark ? mixColor(tone.ui, '#FFFFFF', 0.45) : mixColor(tone.ui, p.text, 0.45);
  p.downText = tone.text;
  p.upText = p.dark ? mixColor(tone.text, '#FFFFFF', 0.45) : mixColor(tone.text, p.text, 0.45);
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
  p.subtle = '#A6ABB2';
  p.good = '#52C487';
  p.warn = '#F0B544';
  p.bad = '#F48E8E';
  p.info = '#38BDF8';
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
