/**
 * Pure rate-limit logic behind the gentle AppGallery review prompt (1.3.0, same spec as MimiFTP 1.3.0 /
 * MimiSSH 1.5.11; Node-tested in scripts/test-logic.mjs). No imports on purpose.
 *
 * Rules:
 * - Trigger: installed >= 3 days + >= 5 launches + >= 3 successful backend connections, all three; never on the
 *   first launch, never while a connection attempt is running (see ReviewPrompt.consider's busy parameter);
 *   failed connections do not count (only the transition to "connected" in Store.connect counts, once per
 *   connect() call - reconnects through retry() are new connect() calls and count, stream drops do not).
 * - Rate limit: >= 90 days between prompts, at most 3 prompts in the app's lifetime; "Later" snoozes 60 days;
 *   "Rate" or "Don't remind me" turn automatic prompts off for good (the permanent entry in
 *   Settings > About is not affected).
 * This file only decides and mutates the plain data object; storage / UI live in ReviewPrompt.ets.
 */

/** Minimum install age before the first prompt: 3 days */
export const REVIEW_MIN_AGE_MS: number = 3 * 24 * 60 * 60 * 1000;
/** Minimum cumulative launches before the first prompt */
export const REVIEW_MIN_LAUNCHES: number = 5;
/** Minimum successful backend connections before the first prompt */
export const REVIEW_MIN_SUCCESSES: number = 3;
/** Minimum interval between two automatic prompts: 90 days */
export const REVIEW_INTERVAL_MS: number = 90 * 24 * 60 * 60 * 1000;
/** Snooze after "Later": 60 days (the 90-day interval still applies, so the next prompt is >= 90 days out) */
export const REVIEW_SNOOZE_MS: number = 60 * 24 * 60 * 60 * 1000;
/** Maximum automatic prompts in the app's lifetime */
export const REVIEW_MAX_SHOWS: number = 3;

/** Prompt lifecycle: pending may still prompt; rated = chose "Rate"; never = chose "Don't remind me" */
export type ReviewLife = 'pending' | 'rated' | 'never';

export class ReviewData {
  /** First launch timestamp (ms) recorded by this feature; 0 = not recorded yet */
  firstSeen: number = 0;
  /** Cumulative launches (counted in EntryAbility onCreate) */
  launches: number = 0;
  /** Cumulative successful backend connections */
  successes: number = 0;
  /** Automatic prompts shown so far */
  shown: number = 0;
  /** Last prompt timestamp (ms); 0 = never shown */
  lastShown: number = 0;
  /** Snooze expiry timestamp (ms); 0 = no snooze */
  snoozeUntil: number = 0;
  life: ReviewLife = 'pending';
}

/**
 * Why an automatic prompt cannot show right now: every unmet condition as a short code (for logs);
 * an empty array means it can show.
 * Codes: life-done / life-never / busy / age / launches / successes / max-shows / interval / snooze
 */
export function reviewBlockers(d: ReviewData, now: number, busy: boolean): string[] {
  const out: string[] = [];
  if (d.life === 'rated') {
    out.push('life-done');
  }
  if (d.life === 'never') {
    out.push('life-never');
  }
  if (busy) {
    out.push('busy');
  }
  if (d.firstSeen <= 0 || now - d.firstSeen < REVIEW_MIN_AGE_MS) {
    out.push('age');
  }
  if (d.launches < REVIEW_MIN_LAUNCHES) {
    out.push('launches');
  }
  if (d.successes < REVIEW_MIN_SUCCESSES) {
    out.push('successes');
  }
  if (d.shown >= REVIEW_MAX_SHOWS) {
    out.push('max-shows');
  }
  if (d.lastShown > 0 && now - d.lastShown < REVIEW_INTERVAL_MS) {
    out.push('interval');
  }
  if (d.snoozeUntil > now) {
    out.push('snooze');
  }
  return out;
}

/** Whether an automatic prompt may show right now (all conditions met) */
export function reviewShouldShow(d: ReviewData, now: number, busy: boolean): boolean {
  return reviewBlockers(d, now, busy).length === 0;
}

/** Records a launch: stamps firstSeen on the first one, then only counts. Returns true for the first launch. */
export function reviewRecordLaunch(d: ReviewData, now: number): boolean {
  const first = d.firstSeen <= 0;
  if (first) {
    d.firstSeen = now;
  }
  d.launches++;
  return first;
}

/** Records a successful backend connection. */
export function reviewRecordSuccess(d: ReviewData): void {
  d.successes++;
}

/** A prompt was shown: count it and stamp the time (rate limiting starts at display, not at the tap). */
export function reviewRecordShown(d: ReviewData, now: number): void {
  d.shown++;
  d.lastShown = now;
}

/** "Rate": automatic prompts off for good. */
export function reviewChooseRate(d: ReviewData): void {
  d.life = 'rated';
  d.snoozeUntil = 0;
}

/** "Later" (also the feedback entry and the close button): snooze 60 days, lifecycle unchanged. */
export function reviewChooseLater(d: ReviewData, now: number): void {
  d.snoozeUntil = now + REVIEW_SNOOZE_MS;
}

/** "Don't remind me": automatic prompts off for good. */
export function reviewChooseNever(d: ReviewData): void {
  d.life = 'never';
  d.snoozeUntil = 0;
}
