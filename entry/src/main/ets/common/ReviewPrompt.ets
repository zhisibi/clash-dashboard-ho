/**
 * Gentle AppGallery review prompt: storage + evaluation + opening the store listing
 * (the pure rate-limit logic lives in ReviewLogic.ets; same spec as MimiFTP 1.3.0 / MimiSSH 1.5.11).
 *
 * State lives only in the local Preferences (keys review.*): savePrefs() writes an explicit key list, so
 * review.* never leaves the device and restarts from zero on a fresh install.
 * Wiring: launches counted in init() (EntryAbility onCreate, after Store.init); successful connections via
 * Store.backendConnectedHook (set here, fired once per successful Store.connect); evaluation happens a few
 * seconds after a successful connection and after the main UI appears - never before privacy consent,
 * never with no backend configured, never while connecting.
 * Decisions are logged with console.info (prefix "Review:") including the blocker codes when a prompt is held
 * back, so a device log capture shows why nothing appeared.
 */
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Store } from './Store';
import {
  ReviewData, reviewBlockers, reviewChooseLater, reviewChooseNever, reviewChooseRate,
  reviewRecordLaunch, reviewRecordShown, reviewRecordSuccess, reviewShouldShow
} from './ReviewLogic';

/** AppGallery detail page of this app (bundleName com.zhisibi.mimipanel) */
export const APP_GALLERY_URL: string = 'https://appgallery.huawei.com/app/detail?id=com.zhisibi.mimipanel';

const K_FIRST: string = 'review.firstSeen';
const K_LAUNCHES: string = 'review.launches';
const K_SUCCESSES: string = 'review.successes';
const K_SHOWN: string = 'review.shown';
const K_LAST: string = 'review.lastShown';
const K_SNOOZE: string = 'review.snoozeUntil';
const K_LIFE: string = 'review.life';

function logI(msg: string): void {
  console.info('Review: ' + msg);
}

@ObservedV2
export class ReviewPrompt {
  private static inst: ReviewPrompt | null = null;

  static get(): ReviewPrompt {
    if (ReviewPrompt.inst === null) {
      ReviewPrompt.inst = new ReviewPrompt();
    }
    return ReviewPrompt.inst;
  }

  /** Whether the soft card is visible (the Index main UI subscribes to this) */
  @Trace showCard: boolean = false;

  private data: ReviewData = new ReviewData();
  private inited: boolean = false;

  /** EntryAbility.onCreate calls this (after Store.init): loads the state and counts one launch. Once per process. */
  init(): void {
    if (this.inited) {
      return;
    }
    this.inited = true;
    this.load();
    reviewRecordLaunch(this.data, Date.now());
    this.save();
    Store.get().backendConnectedHook = () => {
      this.noteBackendSuccess();
    };
    logI('init: launches=' + this.data.launches + ' successes=' + this.data.successes +
      ' shown=' + this.data.shown + ' life=' + this.data.life);
  }

  private load(): void {
    const p = Store.get().prefs;
    if (p === null) {
      return;
    }
    const d = new ReviewData();
    d.firstSeen = p.num(K_FIRST, 0);
    d.launches = p.num(K_LAUNCHES, 0);
    d.successes = p.num(K_SUCCESSES, 0);
    d.shown = p.num(K_SHOWN, 0);
    d.lastShown = p.num(K_LAST, 0);
    d.snoozeUntil = p.num(K_SNOOZE, 0);
    const life = p.str(K_LIFE, 'pending');
    d.life = life === 'rated' || life === 'never' ? life : 'pending';
    this.data = d;
  }

  private save(): void {
    const p = Store.get().prefs;
    if (p === null) {
      return;
    }
    const d = this.data;
    p.put(K_FIRST, d.firstSeen);
    p.put(K_LAUNCHES, d.launches);
    p.put(K_SUCCESSES, d.successes);
    p.put(K_SHOWN, d.shown);
    p.put(K_LAST, d.lastShown);
    p.put(K_SNOOZE, d.snoozeUntil);
    p.put(K_LIFE, d.life);
  }

  /** Store.connect reached "connected": count it, then evaluate once the UI has settled (2 s). */
  noteBackendSuccess(): void {
    if (!this.inited) {
      return;
    }
    reviewRecordSuccess(this.data);
    this.save();
    logI('backend success counted: ' + this.data.successes);
    setTimeout(() => {
      this.consider(false);
    }, 2000);
  }

  /**
   * Evaluates whether the soft card may show now. When it may, showCard is set and the display is counted
   * and saved immediately (counted at display: a killed process cannot prompt twice); when it may not, the
   * blocker codes are logged. [busy] = a connection attempt is running; never prompt then. Callers exclude
   * the pre-consent and no-backend states.
   */
  consider(busy: boolean): void {
    if (!this.inited || this.showCard) {
      return;
    }
    const st = Store.get();
    if (!st.privacyAgreed || st.backends.length === 0) {
      return;
    }
    const now = Date.now();
    if (!reviewShouldShow(this.data, now, busy)) {
      logI('consider blocked: ' + reviewBlockers(this.data, now, busy).join(','));
      return;
    }
    reviewRecordShown(this.data, now);
    this.save();
    this.showCard = true;
    logI('card shown (' + this.data.shown + '), lastShown=' + this.data.lastShown);
  }

  /** "Rate": save the state first (automatic prompts off for good), the caller then opens the listing. */
  chooseRate(): void {
    reviewChooseRate(this.data);
    this.save();
    this.showCard = false;
    logI('user chose rate');
  }

  /** "Later" (and the card's close button): snooze 60 days. */
  chooseLater(): void {
    reviewChooseLater(this.data, Date.now());
    this.save();
    this.showCard = false;
    logI('user chose later, snoozeUntil=' + this.data.snoozeUntil);
  }

  /** The feedback entry in the card body: same snooze (route complaints away first, don't ask again on the spot). */
  chooseFeedback(): void {
    reviewChooseLater(this.data, Date.now());
    this.save();
    this.showCard = false;
    logI('user chose feedback, snoozeUntil=' + this.data.snoozeUntil);
  }

  /** "Don't remind me": automatic prompts off for good. */
  chooseNever(): void {
    reviewChooseNever(this.data);
    this.save();
    this.showCard = false;
    logI('user chose never');
  }

  /**
   * Opens this app's AppGallery detail page. UIAbilityContext.openLink first (the recommended link entry),
   * startAbility(viewData) as fallback. Returns false when both fail; the caller toasts a manual search hint.
   */
  static async openListing(ctx: common.UIAbilityContext | null): Promise<boolean> {
    if (ctx === null) {
      logI('open listing: no context');
      return false;
    }
    try {
      await ctx.openLink(APP_GALLERY_URL);
      logI('openLink ok: ' + APP_GALLERY_URL);
      return true;
    } catch (e) {
      const err = e as BusinessError;
      logI('openLink failed (' + err.code + '), fallback startAbility');
    }
    try {
      await ctx.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: APP_GALLERY_URL
      });
      logI('startAbility ok');
      return true;
    } catch (e) {
      const err = e as BusinessError;
      logI('open listing failed (' + err.code + '): ' + err.message);
      return false;
    }
  }
}
