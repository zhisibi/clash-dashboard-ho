/**
 * App-wide motion (1.3.0, ported from MimiSSH 1.5.10). Every transition in the UI comes from here so
 * durations and curves stay consistent: short (150-300 ms), decelerating (FastOutSlowIn / Friction),
 * no bounce. Pure rules live in MotionLogic.ets.
 *
 * - Motion.on(): Settings > Panel > Appearance > Transition animations (Store.motion, default on) AND
 *   the system animation scales are not 0 (developer options; read once at startup and on foreground -
 *   the settings keys are deprecated since API 21, so failures are ignored and count as "on"). ArkUI
 *   applies the system scale to its own animations by itself.
 * - Effects (fade / reveal / rise / pop) carry their own .animation(), so a plain `if` swap animates
 *   without wrapping the state change in animateTo. When motion is off they are TransitionEffect.IDENTITY.
 * - Durations that were hardcoded before (Tabs page switch, nav bar collapse) go through Motion.ms().
 */
import { settings } from '@kit.BasicServicesKit';
import { MOTION_BASE, MOTION_FAST, animateListChange, motionMs, motionOn } from './MotionLogic';

export class Motion {
  /** Settings > Panel > Appearance > Transition animations (mirrors Store.motion) */
  static user: boolean = true;
  /** false when the system animation / transition scale is 0 */
  static system: boolean = true;

  static on(): boolean {
    return Motion.user && Motion.system;
  }

  /** Re-reads the system animation scales (EntryAbility onCreate / onForeground). Never throws. */
  static readSystem(ctx: Context): void {
    try {
      const a = settings.getValueSync(ctx, settings.display.ANIMATOR_DURATION_SCALE, '1');
      const t = settings.getValueSync(ctx, settings.display.TRANSITION_ANIMATION_SCALE, '1');
      Motion.system = motionOn(true, a, t);
    } catch (e) {
      Motion.system = true;
    }
  }

  static ms(base: number): number {
    return motionMs(base, Motion.on());
  }

  /** Animation parameters for animateTo / .animation() */
  static anim(ms?: number, curve?: Curve | ICurve): AnimateParam {
    return {
      duration: Motion.ms(ms !== undefined ? ms : MOTION_BASE),
      curve: curve !== undefined ? curve : Curve.FastOutSlowIn
    };
  }

  /**
   * Runs a state change animated (layout + transitions of what it adds/removes), or instantly when
   * motion is off or there is no UI context yet.
   */
  static run(ui: UIContext | null | undefined, fn: () => void, ms?: number): void {
    if (ui === null || ui === undefined || !Motion.on()) {
      fn();
      return;
    }
    ui.animateTo(Motion.anim(ms), fn);
  }

  /** Same as run(), but only for small changes on short lists (whole reloads of long lists swap instantly). */
  static runList(ui: UIContext | null | undefined, before: number, after: number, fn: () => void): void {
    if (animateListChange(before, after, Motion.on())) {
      Motion.run(ui, fn);
    } else {
      fn();
    }
  }

  /** Plain crossfade (content swaps: empty <-> list, loading <-> content, settings sub-pages) */
  static fade(ms?: number): TransitionEffect {
    if (!Motion.on()) {
      return TransitionEffect.IDENTITY;
    }
    return TransitionEffect.OPACITY.animation(Motion.anim(ms));
  }

  /** Content appearing below a control (cards floating in over the bottom bar, expanded sections) */
  static reveal(): TransitionEffect {
    if (!Motion.on()) {
      return TransitionEffect.IDENTITY;
    }
    return TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -6 })).animation(Motion.anim());
  }

  /** State views (empty / loading / error): fade + rise */
  static rise(): TransitionEffect {
    if (!Motion.on()) {
      return TransitionEffect.IDENTITY;
    }
    return TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 10 })).animation(Motion.anim());
  }

  /** Small floating things (banners, badges, buttons that come and go): fade + scale from 0.9 */
  static pop(): TransitionEffect {
    if (!Motion.on()) {
      return TransitionEffect.IDENTITY;
    }
    return TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
      .animation(Motion.anim(MOTION_FAST + 30));
  }
}
