import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { withAlpha } from './Theme';

/**
 * 毛玻璃 + 沉浸光感 的组件样式。
 *
 * - 毛玻璃：自定义样式走 backgroundEffect（模糊 + 饱和度，API 11），薄/常规/厚走 backgroundBlurStyle(COMPONENT_*)，
 *   都是 API 20 可用的稳定接口。
 * - 沉浸光感：系统级的 ArkUI 组件沉浸材质（uiMaterial.ImmersiveMaterial + systemMaterial）从 API 26 才开放，
 *   且只在支持的设备上生效，所以这里以运行时判断 + try/catch 守护；其他设备使用自绘光感：
 *   按光源方向计算的边缘高光（四边不同亮度的描边）、斜向柔光渐变、主题色光晕阴影。
 */

const TRANSPARENT: string = '#00000000';

/** 组件类型：card 普通卡片；row 长列表项；plain 不改描边（自带选中边框的卡片/输入框）；top 顶栏；bar 悬浮底栏 */
export type GlassKind = 'card' | 'row' | 'plain' | 'top' | 'bar';

export class GlassCfg {
  dark: boolean = false;
  /** 已经按透明度处理过的卡片底色 '#AARRGGBB' */
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
  /** 光源方向：从屏幕“正上方”顺时针的角度（度），光从这个方向照过来 */
  lightDeg: number = 330;
  /** 当前设备是否可用系统沉浸材质（API 26+ 且设备支持） */
  sysMaterial: boolean = false;

  key(kind: GlassKind): string {
    return kind + '|' + this.dark + '|' + this.card + '|' + this.accent + '|' + this.glassOn + '|' + this.glassStyle +
      '|' + this.glassBlur + '|' + this.glassRows + '|' + this.lightOn + '|' + this.lightIntensity + '|' +
      this.lightGlow + '|' + this.lightDeg + '|' + this.sysMaterial;
  }
}

/** '#AARRGGBB' 的 alpha（0..1），其他格式视为不透明 */
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

/** 弹窗/半模态使用的模糊样式 */
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

/** 系统沉浸材质是否可用：API 26+ 且设备支持（其他情况一律 false，不触碰新接口） */
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

/** 生成系统沉浸材质对象（仅在 sysMaterial 为 true 时调用） */
function makeSysMaterial(cfg: GlassCfg, kind: GlassKind): uiMaterial.Material | undefined {
  try {
    if (deviceInfo.sdkApiVersion >= 26) {
      let st: uiMaterial.ImmersiveStyle = uiMaterial.ImmersiveStyle.REGULAR;
      if (kind === 'bar' || kind === 'top') {
        // 顶栏/底栏下方会有文字滚过，始终使用厚材质，避免透出的文字与标签打架
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
        // 1.1.6：关闭底栏材质的“交互形变”，避免它在部分设备上参与底栏页签的触摸竞争
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

    // ---------- 系统沉浸材质（API 26+ 支持的设备） ----------
    if (this.mat !== undefined) {
      instance.backgroundColor(TRANSPARENT);
      instance.backgroundEffect({ radius: 0 });
      instance.backgroundBlurStyle(BlurStyle.NONE);
      instance.linearGradient({ angle: 0, colors: [[TRANSPARENT, 0], [TRANSPARENT, 1]] });
      this.applySystemMaterial(instance, this.mat);
      return;
    }
    this.applySystemMaterial(instance, undefined);

    // ---------- 底色 ----------
    let bg = c.card;
    const chrome = this.kind === 'bar' || this.kind === 'top';
    if (chrome) {
      // 顶栏 / 悬浮底栏：内容会从下方滚过。开毛玻璃时用强模糊 + 足够的底色；关闭时用接近不透明的底色
      const base = c.dark ? '#1C1F24' : '#FFFFFF';
      if (c.glassOn) {
        const minA = this.kind === 'bar' ? (c.dark ? 0.62 : 0.66) : (c.dark ? 0.55 : 0.58);
        bg = withAlpha(base, Math.max(minA, Math.min(0.9, cardAlphaOf(c.card) * 0.9)));
      } else {
        bg = withAlpha(base, this.kind === 'bar' ? 0.97 : 0.96);
      }
    }
    instance.backgroundColor(bg);

    // ---------- 模糊 ----------
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
        // 毛玻璃关闭：仍做一次轻度模糊，让 4% 的透出也看不清字
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

    // ---------- 光感 ----------
    // 光源方向向量（屏幕坐标，y 向下），指向光源
    const rad = c.lightDeg * Math.PI / 180;
    const lx = Math.sin(rad);
    const ly = -Math.cos(rad);

    if (light) {
      // 柔光：从光源一侧斜向扫入的白色渐变
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
        // 边缘高光：朝向光源的边更亮，背光边带一点暗边，形成玻璃厚度感
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

    // ---------- 阴影 / 光晕 ----------
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
