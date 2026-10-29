/**
 * Nav bar immersive light sense (1.3.0, ported from MimiSSH 1.5.6/1.5.7 common/LightSense.ets).
 *
 * Capability (worked out once, at first use):
 * - API >= 26 and uiMaterial.isImmersiveMaterialSupported() (and the material state not DISABLE) -> the bar takes
 *   ArkUI's systemMaterial(new uiMaterial.ImmersiveMaterial(...)). The material replaces backgroundColor / border /
 *   shadow, so in that case none of the fallback attributes are set.
 * - Otherwise: heavy backdrop blur with the same neutral tint (API 20-25 or no system material).
 * Every newer API is only called behind deviceInfo.sdkApiVersion + canIUse and inside try/catch, and applied through
 * AttributeModifiers, so systemMaterial is never called on systems below API 26 (compatibleSdkVersion 6.0.0(20)).
 *
 * The floating capsule, hairline rim and refraction highlight come from GlassRimMod overlays on every device.
 * While the switch is on the bar never folds (see Store.navScroll / Index.collapsed). Switch off = the pre-1.3.0
 * bar (Store.glass('bar')) exactly.
 */
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { hdsMaterial } from '@kit.UIDesignKit';
import { withAlpha } from './Theme';

export const LEVEL_EXQUISITE: number = 0;
export const LEVEL_GENTLE: number = 1;
export const LEVEL_SMOOTH: number = 2;

export class NavLightSense {
  private static done: boolean = false;
  private static mat: boolean = false;
  private static lvl: number = LEVEL_SMOOTH;

  private static init(): void {
    if (NavLightSense.done) {
      return;
    }
    NavLightSense.done = true;
    const api = deviceInfo.sdkApiVersion;
    let hds = false;
    try {
      hds = canIUse('SystemCapability.UIDesign.HDSComponent.Core');
    } catch (e) {
      hds = false;
    }
    let hdsImmersive = false;
    if (api >= 23 && hds) {
      try {
        const types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
        hdsImmersive = types.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
      } catch (e) {
        hdsImmersive = false;
      }
    }
    NavLightSense.lvl = hdsImmersive ? LEVEL_EXQUISITE : LEVEL_SMOOTH;
    if (api >= 26) {
      try {
        NavLightSense.lvl = uiMaterial.getGlobalMaterialLevel();
        const info = uiMaterial.getMaterialInfo();
        NavLightSense.mat = uiMaterial.isImmersiveMaterialSupported() &&
          info.state !== uiMaterial.MaterialState.DISABLE;
      } catch (e) {
        NavLightSense.mat = false;
      }
    }
  }

  /** ArkUI ImmersiveMaterial renders on this device (API >= 26) */
  static material(): boolean {
    NavLightSense.init();
    return NavLightSense.mat;
  }

  /** 0 EXQUISITE / 1 GENTLE / 2 SMOOTH */
  static level(): number {
    NavLightSense.init();
    return NavLightSense.lvl;
  }
}

/** Everything the bar surface needs from Store/palette (plain values, so the modifier never reads @Trace state). */
export class BarLook {
  /** Nav bar immersive light switch */
  on: boolean = false;
  dark: boolean = false;
  /** Bar color for the off look (may already be translucent with glass / wallpaper) */
  bar: string = '#FFFFFF';
  divider: string = '#14000000';
  /** Blur in px used when frosted glass is on (0 when off) */
  blurPx: number = 0;
  /** Blur in px for the light-sense fallback */
  fallbackBlurPx: number = 60;
  /** Collapsed round button: slightly stronger shadow */
  round: boolean = false;
}

/** 1.5.7 glass tints from MimiSSH (checked there by check-contrast.py): dark / light, material alpha, fallback alpha */
export const GLASS_TINT_DARK: string = '#0E1216';
export const GLASS_TINT_LIGHT: string = '#FFFFFF';
export const GLASS_ALPHA_DARK: number = 0.34;
export const GLASS_ALPHA_LIGHT: number = 0.46;
export const GLASS_FB_ALPHA_DARK: number = 0.5;
export const GLASS_FB_ALPHA_LIGHT: number = 0.6;
/** Labels on the glass: white in the dark theme (the light theme keeps the palette text colour) */
export const GLASS_LABEL_DARK: string = '#FFFFFF';

/**
 * Bottom-bar surface for the light-sense look. ImmersiveMaterial THIN with a light neutral tint where supported
 * (quite transparent, content visibly scrolls behind it), else heavy backdrop blur with the same tint. The hairline
 * rim / highlight layers are separate overlays (GlassRimMod) because the system material replaces border /
 * background on its own node. (The off look is Store.glass('bar'); this modifier's off branch only mirrors it.)
 */
export class BarGlassMod implements AttributeModifier<CommonAttribute> {
  look: BarLook;

  constructor(look: BarLook) {
    this.look = look;
  }

  applyNormalAttribute(ins: CommonAttribute): void {
    const l = this.look;
    const shadowColor = l.dark ? '#66000000' : (l.round ? '#22000000' : '#1F000000');
    if (!l.on) {
      ins.backgroundColor(l.bar);
      ins.backdropBlur(l.blurPx);
      ins.border({ width: 0.5, color: l.divider });
      ins.shadow({ radius: l.round ? 16 : 18, color: shadowColor, offsetY: 4 });
      return;
    }
    if (NavLightSense.material()) {
      ins.systemMaterial(new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        materialColor: withAlpha(l.dark ? GLASS_TINT_DARK : GLASS_TINT_LIGHT,
          l.dark ? GLASS_ALPHA_DARK : GLASS_ALPHA_LIGHT),
        applyShadow: true,
        interactive: false,
        lightEffect: { color: '#FFFFFF' }
      }));
    } else {
      ins.backgroundColor(withAlpha(l.dark ? GLASS_TINT_DARK : GLASS_TINT_LIGHT,
        l.dark ? GLASS_FB_ALPHA_DARK : GLASS_FB_ALPHA_LIGHT));
      ins.backdropBlur(Math.max(l.blurPx, l.fallbackBlurPx));
      ins.shadow({ radius: 24, color: l.dark ? '#73000000' : '#26000000', offsetY: 6 });
    }
  }
}

/**
 * Glass rim overlays (non-interactive, drawn above the surface, below the tabs):
 * kind 0 = 1px hairline, brightest on top, softer at the sides, dim at the bottom, plus a soft top sheen;
 * kind 1 = refraction rim: bright at both rounded ends fading to clear in the middle, with an inset 0.5px ring.
 */
export class GlassRimMod implements AttributeModifier<CommonAttribute> {
  dark: boolean = true;
  kind: number = 0;

  constructor(dark: boolean, kind: number) {
    this.dark = dark;
    this.kind = kind;
  }

  applyNormalAttribute(ins: CommonAttribute): void {
    const d = this.dark;
    if (this.kind === 0) {
      ins.border({
        width: 1,
        color: {
          top: withAlpha('#FFFFFF', d ? 0.42 : 0.95),
          left: withAlpha('#FFFFFF', d ? 0.3 : 0.85),
          right: withAlpha('#FFFFFF', d ? 0.3 : 0.85),
          bottom: withAlpha('#FFFFFF', d ? 0.14 : 0.6)
        }
      });
      ins.linearGradient({
        angle: 180,
        colors: [[withAlpha('#FFFFFF', d ? 0.1 : 0.32), 0], [withAlpha('#FFFFFF', 0), 0.45],
          [withAlpha('#FFFFFF', 0), 0.8], [withAlpha('#FFFFFF', d ? 0.04 : 0.12), 1]]
      });
    } else {
      ins.border({ width: 0.5, color: withAlpha('#FFFFFF', d ? 0.12 : 0.5) });
      ins.linearGradient({
        angle: 90,
        colors: [[withAlpha('#FFFFFF', d ? 0.16 : 0.34), 0], [withAlpha('#FFFFFF', 0), 0.07],
          [withAlpha('#FFFFFF', 0), 0.93], [withAlpha('#FFFFFF', d ? 0.16 : 0.34), 1]]
      });
    }
  }
}
