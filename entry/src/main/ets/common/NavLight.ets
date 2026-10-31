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
 *
 * 1.3.6: bar design aligned with MimiFTP 1.2.8 liquid glass (the user: FTP's bar looks right, this one read as
 * plain transparent). Much lighter tints (material 0.34/0.46 -> 0.10/0.22, fallback 0.50/0.60 -> 0.16/0.30);
 * a saturated backdrop underlay (BarBackdropMod) under the system material, blurred again by it -> heavier blur
 * + colour boost; the fallback path uses backgroundEffect (blur + saturation 1.7 + brightness); rim gains a
 * bottom inner shadow (glass thickness), wider refraction bands and kind 2 lens caps at both rounded ends;
 * labels get a halo shadow (GLASS_LABEL_SHADOW_*) for legibility over colourful content behind the clear glass.
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

/**
 * Glass tints: dark / light, material alpha, fallback alpha.
 * 1.3.6 (= MimiFTP 1.2.8: very clear liquid glass, heavy blur, almost no fill): material 0.34/0.46 -> 0.10/0.22,
 * fallback 0.50/0.60 -> 0.16/0.30 (the fallback has no system material fill of its own, so it keeps a bit more).
 */
export const GLASS_TINT_DARK: string = '#0E1216';
export const GLASS_TINT_LIGHT: string = '#FFFFFF';
export const GLASS_ALPHA_DARK: number = 0.1;
export const GLASS_ALPHA_LIGHT: number = 0.22;
export const GLASS_FB_ALPHA_DARK: number = 0.16;
export const GLASS_FB_ALPHA_LIGHT: number = 0.3;
/** Labels on the glass: white in the dark theme (the light theme keeps the palette text colour) */
export const GLASS_LABEL_DARK: string = '#FFFFFF';
/** 1.3.6 label halo for legibility over bright / colourful content behind the clear glass */
export const GLASS_LABEL_SHADOW_DARK: string = '#8C000000';
export const GLASS_LABEL_SHADOW_LIGHT: string = '#B3FFFFFF';
/** 1.3.6 backdrop: blur radius in vp, saturation and brightness of what is seen through the glass */
export const GLASS_BLUR_VP: number = 34;
export const GLASS_SATURATION: number = 1.7;
export const GLASS_BRIGHT_DARK: number = 0.94;
export const GLASS_BRIGHT_LIGHT: number = 1.06;

/**
 * Bottom-bar surface for the light-sense look.
 * - System material (API 26+, supported): ImmersiveMaterial THIN with a very light neutral tint. A saturated
 *   backdrop underlay (BarBackdropMod, below this node) is blurred again by the material -> heavier blur +
 *   colour boost.
 * - Fallback (API 20-25 / no material): backgroundEffect = blur + saturation + brightness + light tint.
 * The hairline rim / lens layers are separate overlays (GlassRimMod) because the system material replaces
 * border / background on its own node. (The off look is Store.glass('bar'); this modifier's off branch only
 * mirrors it.)
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
      ins.backgroundEffect({
        radius: Math.max(l.blurPx, l.fallbackBlurPx),
        saturation: GLASS_SATURATION,
        brightness: l.dark ? GLASS_BRIGHT_DARK : GLASS_BRIGHT_LIGHT,
        color: withAlpha(l.dark ? GLASS_TINT_DARK : GLASS_TINT_LIGHT, l.dark ? GLASS_FB_ALPHA_DARK : GLASS_FB_ALPHA_LIGHT)
      });
      ins.shadow({ radius: 26, color: l.dark ? '#80000000' : '#2E000000', offsetY: 8 });
    }
  }
}

/**
 * 1.3.6: saturated backdrop under the system material (only used when NavLightSense.material()): blur + colour
 * boost, no fill. The material above blurs it once more, so colours behind the bar read as soft bright blobs.
 * Not used on the fallback path (backgroundEffect already does blur + saturation there).
 */
export class BarBackdropMod implements AttributeModifier<CommonAttribute> {
  dark: boolean = true;
  radiusPx: number = 60;

  constructor(dark: boolean, radiusPx: number) {
    this.dark = dark;
    this.radiusPx = radiusPx;
  }

  applyNormalAttribute(ins: CommonAttribute): void {
    ins.backgroundEffect({
      radius: this.radiusPx * 0.6,
      saturation: GLASS_SATURATION,
      brightness: this.dark ? 1.0 : GLASS_BRIGHT_LIGHT,
      color: Color.Transparent
    });
  }
}

/**
 * Glass rim overlays (non-interactive, drawn above the surface, below the tabs). Liquid-glass lens emulation -
 * no public refraction API exists in SDK 26, so it is all gradients:
 * kind 0 = 1px hairline, brightest on top, softer at the sides, dim at the bottom; top sheen + darker inner shadow
 *          along the bottom edge (glass-slab thickness);
 * kind 1 = refraction rim (inset 1.5): bright bands at both rounded ends fading to clear, with an inset 0.5px ring;
 * kind 2 = lens cap (one per rounded end, a square the bar's height): radial ring that brightens towards the curve,
 *          like light bent through the thick glass edge.
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
          top: withAlpha('#FFFFFF', d ? 0.55 : 0.98),
          left: withAlpha('#FFFFFF', d ? 0.32 : 0.85),
          right: withAlpha('#FFFFFF', d ? 0.32 : 0.85),
          bottom: withAlpha('#FFFFFF', d ? 0.12 : 0.55)
        }
      });
      ins.linearGradient({
        angle: 180,
        colors: [[withAlpha('#FFFFFF', d ? 0.09 : 0.26), 0], [withAlpha('#FFFFFF', 0), 0.38],
          [withAlpha('#000000', 0), 0.72], [withAlpha('#000000', d ? 0.16 : 0.06), 1]]
      });
    } else if (this.kind === 1) {
      ins.border({ width: 0.5, color: withAlpha('#FFFFFF', d ? 0.16 : 0.55) });
      ins.linearGradient({
        angle: 90,
        colors: [[withAlpha('#FFFFFF', d ? 0.22 : 0.4), 0], [withAlpha('#FFFFFF', d ? 0.06 : 0.12), 0.04],
          [withAlpha('#FFFFFF', 0), 0.1], [withAlpha('#FFFFFF', 0), 0.9],
          [withAlpha('#FFFFFF', d ? 0.06 : 0.12), 0.96], [withAlpha('#FFFFFF', d ? 0.22 : 0.4), 1]]
      });
    } else {
      ins.radialGradient({
        center: ['50%', '50%'],
        radius: '50%',
        colors: [[withAlpha('#FFFFFF', 0), 0], [withAlpha('#FFFFFF', 0), 0.68],
          [withAlpha('#FFFFFF', d ? 0.1 : 0.22), 0.86], [withAlpha('#FFFFFF', d ? 0.2 : 0.36), 0.96],
          [withAlpha('#FFFFFF', 0), 1]]
      });
    }
  }
}
