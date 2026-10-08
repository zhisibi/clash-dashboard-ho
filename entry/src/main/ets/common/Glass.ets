import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { withAlpha } from './Theme';

/**
 * Component styles for frosted glass + immersive light.
 *
 * - Frosted glass: Custom uses backgroundEffect (blur + saturation, API 11); Thin/Regular/Thick use backgroundBlurStyle(COMPONENT_*),
 *   both stable APIs available on API 20.
 * - Immersive light: the system ArkUI immersive material (uiMaterial.ImmersiveMaterial + systemMaterial) needs API 26
 *   and a supporting device, so it is guarded by a runtime check + try/catch; other devices get a self-drawn effect:
 *   edge highlights by light direction (per-side border brightness), a diagonal soft-light gradient and an accent glow shadow.
 */

const TRANSPARENT: string = '#00000000';

/** Kind: card = normal card; row = long-list item; plain = keep border (cards/inputs with their own selection border); top = header; bar = floating bar */
export type GlassKind = 'card' | 'row' | 'plain' | 'top' | 'bar';

export class GlassCfg {
  dark: boolean = false;
  /** Card color with opacity already applied, '#AARRGGBB' */
  card: string = '#FFFFFFFF';
  accent: string = '#0A59F7';
  glassOn: boolean = false;
  /** custom | thin | regular | thick | system */
  glassStyle: string = 'custom';
  /** 0..100 */
  glassBlur: number = 40;
  glassRows: boolean = false;
  lightOn: boolean = false;
  /** 0..1 */
  lightIntensity: number = 0.6;
  lightGlow: boolean = true;
  /** Light direction: degrees clockwise from the top of the screen; light comes from there */
  lightDeg: number = 330;
  /** Whether the system immersive material is available (API 26+ and device support) */
  sysMaterial: boolean = false;

  key(kind: GlassKind): string {
    return kind + '|' + this.dark + '|' + this.card + '|' + this.accent + '|' + this.glassOn + '|' + this.glassStyle +
      '|' + this.glassBlur + '|' + this.glassRows + '|' + this.lightOn + '|' + this.lightIntensity + '|' +
      this.lightGlow + '|' + this.lightDeg + '|' + this.sysMaterial;
  }
}

/** Alpha (0..1) of '#AARRGGBB'; other formats count as opaque */
function cardAlphaOf(c: string): number {
  if (c.length === 9 && c.charAt(0) === '#') {
    const a = parseInt(c.substring(1, 3), 16);
    if (!isNaN(a)) {
      return a / 255;
    }
  }
  return 1;
}

function clamp01(v: number): number {
  return Math.max(0, Math.min(1, v));
}

function presetStyle(s: string): BlurStyle {
  if (s === 'thin') {
    return BlurStyle.COMPONENT_THIN;
  }
  if (s === 'thick') {
    return BlurStyle.COMPONENT_THICK;
  }
  return BlurStyle.COMPONENT_REGULAR;
}

/** Blur style for dialogs and sheets */
export function sheetBlurStyle(cfg: GlassCfg): BlurStyle {
  if (!cfg.glassOn) {
    return BlurStyle.NONE;
  }
  if (cfg.glassStyle === 'thin') {
    return BlurStyle.COMPONENT_REGULAR;
  }
  if (cfg.glassStyle === 'thick') {
    return BlurStyle.COMPONENT_ULTRA_THICK;
  }
  return BlurStyle.COMPONENT_THICK;
}

/** System immersive material available: API 26+ and device support (otherwise false, new APIs untouched) */
export function detectSysMaterial(): boolean {
  try {
    if (deviceInfo.sdkApiVersion >= 26) {
      return uiMaterial.isImmersiveMaterialSupported();
    }
  } catch (e) {
    // ignore
  }
  return false;
}

/** Creates the system immersive material (only call when sysMaterial is true) */
function makeSysMaterial(cfg: GlassCfg, kind: GlassKind): uiMaterial.Material | undefined {
  try {
    if (deviceInfo.sdkApiVersion >= 26) {
      let st: uiMaterial.ImmersiveStyle = uiMaterial.ImmersiveStyle.REGULAR;
      if (kind === 'bar' || kind === 'top') {
        // Text scrolls under the header/bar, so always use the thick material to keep labels readable
        st = uiMaterial.ImmersiveStyle.THICK;
      } else if (cfg.glassBlur < 34) {
        st = uiMaterial.ImmersiveStyle.THIN;
      } else if (cfg.glassBlur > 70) {
        st = uiMaterial.ImmersiveStyle.THICK;
      }
      const tint = kind === 'bar' ? 0.50 : (kind === 'top' ? 0.42 : 0.12);
      const opts: uiMaterial.ImmersiveOptions = {
        style: st,
        materialColor: withAlpha(cfg.dark ? '#1C1F24' : '#FFFFFF', tint),
        applyShadow: kind === 'bar' || kind === 'card',
        // 1.1.6: turn off the bar material's interactive deformation so it doesn't compete with tab taps on some devices
        interactive: false,
        lightEffect: cfg.lightOn ? { color: '#FFFFFF' } as uiMaterial.LightEffectOptions : null
      };
      return new uiMaterial.ImmersiveMaterial(opts);
    }
  } catch (e) {
    // ignore
  }
  return undefined;
}

export class GlassModifier implements AttributeModifier<CommonAttribute> {
  private cfg: GlassCfg;
  private kind: GlassKind;
  private mat: uiMaterial.Material | undefined = undefined;

  constructor(cfg: GlassCfg, kind: GlassKind) {
    this.cfg = cfg;
    this.kind = kind;
    if (cfg.glassOn && cfg.glassStyle === 'system' && cfg.sysMaterial && kind !== 'row' && kind !== 'plain') {
      this.mat = makeSysMaterial(cfg, kind);
    }
  }

  private ownsBorder(): boolean {
    return this.kind === 'card' || this.kind === 'row' || this.kind === 'bar';
  }

  private blurEnabled(): boolean {
    if (!this.cfg.glassOn) {
      return false;
    }
    if (this.kind === 'row' || this.kind === 'plain') {
      return this.cfg.glassRows;
    }
    return true;
  }

  private applySystemMaterial(instance: CommonAttribute, m: uiMaterial.Material | undefined): void {
    try {
      if (deviceInfo.sdkApiVersion >= 26 && this.cfg.sysMaterial) {
        instance.systemMaterial(m);
      }
    } catch (e) {
      // ignore
    }
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    const c = this.cfg;
    const I = clamp01(c.lightIntensity);
    const light = c.lightOn && I > 0;

    // ---------- system immersive material (API 26+ devices) ----------
    if (this.mat !== undefined) {
      instance.backgroundColor(TRANSPARENT);
      instance.backgroundEffect({ radius: 0 });
      instance.backgroundBlurStyle(BlurStyle.NONE);
      instance.linearGradient({ angle: 0, colors: [[TRANSPARENT, 0], [TRANSPARENT, 1]] });
      this.applySystemMaterial(instance, this.mat);
      return;
    }
    this.applySystemMaterial(instance, undefined);

    // ---------- base color ----------
    let bg = c.card;
    const chrome = this.kind === 'bar' || this.kind === 'top';
    if (chrome) {
      // Header / floating bar: content scrolls underneath. With glass on use strong blur + enough tint; with it off use a near-opaque color
      const base = c.dark ? '#1C1F24' : '#FFFFFF';
      if (c.glassOn) {
        const minA = this.kind === 'bar' ? (c.dark ? 0.62 : 0.66) : (c.dark ? 0.55 : 0.58);
        bg = withAlpha(base, Math.max(minA, Math.min(0.9, cardAlphaOf(c.card) * 0.9)));
      } else {
        bg = withAlpha(base, this.kind === 'bar' ? 0.97 : 0.96);
      }
    }
    instance.backgroundColor(bg);

    // ---------- blur ----------
    if (chrome) {
      if (c.glassOn) {
        if (c.glassStyle === 'custom' || c.glassStyle === 'system') {
          instance.backgroundBlurStyle(BlurStyle.NONE);
          const r = Math.max(this.kind === 'bar' ? 70 : 60, Math.round(4 + c.glassBlur * 0.8));
          instance.backgroundEffect({ radius: r, saturation: c.dark ? 1.3 : 1.5, brightness: 1.0 });
        } else {
          instance.backgroundEffect({ radius: 0 });
          instance.backgroundBlurStyle(c.glassStyle === 'thick' ? BlurStyle.COMPONENT_ULTRA_THICK : BlurStyle.COMPONENT_THICK, {
            colorMode: c.dark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
            adaptiveColor: AdaptiveColor.DEFAULT,
            scale: 1
          });
        }
      } else {
        // Glass off: still blur lightly so the 4% see-through doesn't show readable text
        instance.backgroundBlurStyle(BlurStyle.NONE);
        instance.backgroundEffect({ radius: 40, saturation: 1.0, brightness: 1.0 });
      }
    } else if (this.blurEnabled()) {
      if (c.glassStyle === 'custom' || c.glassStyle === 'system') {
        instance.backgroundBlurStyle(BlurStyle.NONE);
        const r = Math.round(4 + c.glassBlur * 0.8);
        instance.backgroundEffect({ radius: r, saturation: c.dark ? 1.3 : 1.6, brightness: 1.0 });
      } else {
        instance.backgroundEffect({ radius: 0 });
        instance.backgroundBlurStyle(presetStyle(c.glassStyle), {
          colorMode: c.dark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: clamp01(0.1 + c.glassBlur / 100 * 0.9)
        });
      }
    } else {
      instance.backgroundEffect({ radius: 0 });
      instance.backgroundBlurStyle(BlurStyle.NONE);
    }

    // ---------- light ----------
    // Light direction vector (screen coordinates, y down), pointing at the light
    const rad = c.lightDeg * Math.PI / 180;
    const lx = Math.sin(rad);
    const ly = -Math.cos(rad);

    if (light) {
      // Soft light: a white gradient sweeping in diagonally from the light side
      const sheenA = (c.dark ? 0.10 : 0.30) * I * (c.glassOn ? 1 : 0.6);
      const mid = this.kind === 'top' || this.kind === 'bar' ? 0.65 : 0.5;
      instance.linearGradient({
        angle: (c.lightDeg + 180) % 360,
        colors: [[withAlpha('#FFFFFF', sheenA), 0], [withAlpha('#FFFFFF', sheenA * 0.25), mid * 0.5],
          [TRANSPARENT, mid], [TRANSPARENT, 1]]
      });
    } else {
      instance.linearGradient({ angle: 0, colors: [[TRANSPARENT, 0], [TRANSPARENT, 1]] });
    }

    if (this.ownsBorder()) {
      if (light || c.glassOn) {
        // Edge highlight: brighter edges toward the light, slightly darker away from it, for a sense of glass thickness
        const hi = light ? (c.dark ? 0.42 : 0.95) * I : 0;
        const baseA = c.glassOn ? (c.dark ? 0.10 : 0.45) : 0;
        const shade = light ? (c.dark ? 0.0 : 0.06) * I : 0;
        const edge = (nx: number, ny: number): string => {
          const d = lx * nx + ly * ny; // -1..1
          if (d >= 0) {
            return withAlpha('#FFFFFF', clamp01(baseA + hi * d));
          }
          if (shade > 0 && !c.glassOn) {
            return withAlpha('#000000', shade * -d);
          }
          return withAlpha('#FFFFFF', clamp01(baseA * (1 + d * 0.7)));
        };
        instance.borderWidth(c.glassOn || light ? 1 : 0);
        instance.borderColor({
          top: edge(0, -1),
          right: edge(1, 0),
          bottom: edge(0, 1),
          left: edge(-1, 0)
        });
      } else {
        instance.borderWidth(0);
        instance.borderColor(TRANSPARENT);
      }
    }

    // ---------- shadow / glow ----------
    if (this.kind === 'bar') {
      if (light && c.lightGlow) {
        instance.shadow({
          radius: 22 + 14 * I, color: withAlpha(c.accent, (c.dark ? 0.45 : 0.30) * I),
          offsetX: -lx * 6 * I, offsetY: 4 - ly * 6 * I
        });
      } else {
        instance.shadow({ radius: 20, color: '#40000000', offsetY: 4 });
      }
    } else if (this.kind === 'card') {
      if (light && c.lightGlow) {
        instance.shadow({
          radius: 10 + 16 * I, color: withAlpha(c.accent, (c.dark ? 0.30 : 0.16) * I),
          offsetX: -lx * 5 * I, offsetY: -ly * 5 * I
        });
      } else if (light) {
        instance.shadow({ radius: 10 + 10 * I, color: withAlpha('#000000', 0.10 * I), offsetX: -lx * 4, offsetY: -ly * 4 });
      } else if (c.glassOn) {
        instance.shadow({ radius: 14, color: c.dark ? '#33000000' : '#14000000', offsetY: 2 });
      } else {
        instance.shadow({ radius: 0, color: TRANSPARENT });
      }
    }
  }
}
