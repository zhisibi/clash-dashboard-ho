/**
 * Pure motion rules behind common/Motion.ets (1.3.0, ported from MimiSSH 1.5.10; Node-tested in
 * scripts/test-logic.mjs). No ArkUI imports.
 *
 * One place for every duration, so the whole app moves the same way: short (150-300 ms), decelerating
 * curves, no bounce. The Settings > Panel > Appearance "Transition animations" switch (default on) and
 * the system's animation scales (developer options, 0 = off) turn everything into instant changes.
 */

/** Colour / selection changes (chips, segmented control, tab highlight) */
export const MOTION_FAST: number = 150;
/** Reveal / collapse, content swaps (empty <-> list, loading), dialogs */
export const MOTION_BASE: number = 220;
/** Bottom-tab page switch (Tabs animationDuration); the panel used 300 ms before the motion module */
export const MOTION_TAB: number = 300;
/** Auto-hide nav bar collapse / expand */
export const MOTION_NAV: number = 380;

/**
 * Reads a system animation scale ("0", "0.5", "1", "1.0", "" when unset). Unset / unreadable counts as 1.
 */
export function parseScale(v: string | null | undefined): number {
  if (v === null || v === undefined) {
    return 1;
  }
  const s = v.trim();
  if (s.length === 0) {
    return 1;
  }
  const n = Number(s);
  if (isNaN(n) || n < 0) {
    return 1;
  }
  return n;
}

/**
 * Whether animations run: the app switch is on and neither system scale is 0.
 * Durations are NOT multiplied by the scale: ArkUI already applies the system animator scale to its
 * own animations, multiplying here would scale twice.
 */
export function motionOn(user: boolean, animatorScale: string | null | undefined,
  transitionScale: string | null | undefined): boolean {
  if (!user) {
    return false;
  }
  return parseScale(animatorScale) > 0 && parseScale(transitionScale) > 0;
}

/** Duration to use: the base value, or 0 when motion is off. */
export function motionMs(base: number, on: boolean): number {
  return on ? Math.max(0, Math.round(base)) : 0;
}

/**
 * Whether a list change should animate: only small changes on short lists (a single insert / delete /
 * move), never a reload of a long list.
 */
export const LIST_ANIM_MAX_ITEMS: number = 200;
export const LIST_ANIM_MAX_CHANGED: number = 3;

export function animateListChange(before: number, after: number, on: boolean): boolean {
  if (!on) {
    return false;
  }
  if (Math.max(before, after) > LIST_ANIM_MAX_ITEMS) {
    return false;
  }
  return Math.abs(after - before) <= LIST_ANIM_MAX_CHANGED;
}
