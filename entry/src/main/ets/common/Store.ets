import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { fileUri } from '@kit.CoreFileKit';
import { ApiError, CoreApi, VersionInfo, WsStream, errMsg } from './CoreApi';
import {
  Backend, ConnItem, CoreConfig, JObj, LogEntry, ProxyItem, ProxyProvider, RuleItem, RuleProvider, Traffic,
  asObj, jArr, jNum, jStr, parseConnection, parseJsonObj
} from './Models';
import { Prefs } from './Prefs';
import { AccentDef, Palette, applyAccent, darkPalette, findAccent, lightPalette, withAlpha } from './Theme';
import { FileUtil } from './FileUtil';
import { CrashLog } from './CrashLog';
import { PRIVACY_VERSION } from './Legal';
import { sensor } from '@kit.SensorServiceKit';
import { GlassCfg, GlassKind, GlassModifier, detectSysMaterial, sheetBlurStyle } from './Glass';
import { I18N, initLang, setLangPref, t } from './I18n';

export const HISTORY_LEN: number = 60;

/** A one-shot async action; failures surface as a toast */
type Task = () => Promise<void>;

function emptyTraffic(): Traffic[] {
  const a: Traffic[] = [];
  for (let i = 0; i < HISTORY_LEN; i++) {
    a.push(new Traffic(0, 0));
  }
  return a;
}

function emptyNums(): number[] {
  const a: number[] = [];
  for (let i = 0; i < HISTORY_LEN; i++) {
    a.push(0);
  }
  return a;
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(() => {
      resolve();
    }, ms);
  });
}

/**
 * Global state and logic (Kotlin MainViewModel).
 * Uses ArkUI state management V2 (@ObservedV2 + @Trace); @ComponentV2 UIs re-render on read.
 */
@ObservedV2
export class Store {
  private static inst: Store | null = null;

  static get(): Store {
    if (Store.inst === null) {
      Store.inst = new Store();
    }
    return Store.inst as Store;
  }

  // non-reactive members
  ctx: common.UIAbilityContext | null = null;
  uiCtx: UIContext | null = null;
  win: window.Window | null = null;
  prefs: Prefs | null = null;
  private api: CoreApi | null = null;
  private streams: WsStream[] = [];
  private logStream: WsStream | null = null;
  private prevConns: Map<string, ConnItem> = new Map<string, ConnItem>();
  private logSeq: number = 0;
  private logBuf: LogEntry[] = [];
  private logTimer: number = -1;
  private inited: boolean = false;
  private glassCache: Map<string, GlassModifier> = new Map<string, GlassModifier>();
  private tiltOn: boolean = false;
  private tiltSmooth: number = 330;
  private foreground: boolean = true;
  /** Auto-hide nav bar: scroll distance accumulated in one direction */
  private navAcc: number = 0;
  /** Ignore reverse scrolling from the end-of-list bounce until this time */
  private navLockUntil: number = 0;
  private navTab: number = -1;
  /** Whether the device supports the system immersive material (API 26+); detected once at startup */
  sysMaterialSupported: boolean = false;

  // ----- backend -----
  @Trace backends: Backend[] = [];
  @Trace active: Backend | null = null;
  @Trace connState: string = 'idle'; // idle | connecting | connected | failed
  @Trace connError: string = '';
  @Trace version: string = '';
  @Trace isMeta: boolean = false;
  @Trace config: CoreConfig = new CoreConfig();

  // ----- settings -----
  @Trace theme: string = 'system';
  /** Accent color key, see ACCENTS in Theme.ets */
  @Trace accent: string = 'blue';
  @Trace systemDark: boolean = false;
  @Trace testUrl: string = 'https://www.gstatic.com/generate_204';
  @Trace testTimeout: number = 5000;
  @Trace lowLatency: number = 400;
  @Trace mediumLatency: number = 800;
  @Trace groupTestUrlFirst: boolean = true;
  @Trace hideUnavailable: boolean = false;
  @Trace sortProxies: string = 'default';
  @Trace proxyCols: number = 2;
  @Trace showGlobal: boolean = true;
  @Trace showHiddenGroups: boolean = false;
  @Trace logMax: number = 1000;
  @Trace closedConnMax: number = 500;
  @Trace showRuleHits: boolean = true;
  @Trace cardAlpha: number = 0.82;
  @Trace wallpaperBlur: number = 0;
  @Trace wallpaperDim: number = 0.1;
  @Trace wallpaperPath: string = '';
  // ----- frosted glass -----
  @Trace glassOn: boolean = false;
  /** custom | thin | regular | thick | system */
  @Trace glassStyle: string = 'custom';
  /** Blur strength 0..100 */
  @Trace glassBlur: number = 45;
  /** Glass card opacity 0.1..0.95 */
  @Trace glassAlpha: number = 0.55;
  /** Blur every long-list item too (costs more) */
  @Trace glassRows: boolean = false;
  // ----- immersive light -----
  @Trace lightOn: boolean = false;
  /** Light intensity 0..1 */
  @Trace lightIntensity: number = 0.6;
  @Trace lightTilt: boolean = false;
  @Trace lightGlow: boolean = true;
  @Trace lightSweep: boolean = true;
  /** Light direction (degrees clockwise from top), quantized to 6°, driven by the sensor when following tilt */
  @Trace lightDeg: number = 330;
  @Trace connSort: string = 'start';
  @Trace connSortDesc: boolean = true;
  // ----- nav bar / immersive window -----
  /** Auto-hide the bottom nav bar while scrolling */
  @Trace autoHideNav: boolean = true;
  /** Whether the bottom bar is collapsed into the round button at the bottom left */
  @Trace navCollapsed: boolean = false;
  /** Status bar height (vp); content must avoid it in the full-screen layout */
  @Trace safeTop: number = 0;
  /** Height of the gesture indicator area at the bottom (vp) */
  @Trace safeBottom: number = 0;

  // ----- proxies -----
  @Trace proxies: Map<string, ProxyItem> = new Map<string, ProxyItem>();
  @Trace providers: ProxyProvider[] = [];
  /** 1.2.7: About > Version update check in flight */
  @Trace updateChecking: boolean = false;
  @Trace testing: Map<string, boolean> = new Map<string, boolean>();
  @Trace nodeTesting: Map<string, boolean> = new Map<string, boolean>();
  @Trace manualDelay: Map<string, number> = new Map<string, number>();
  @Trace proxiesLoading: boolean = false;

  // ----- rules -----
  @Trace rules: RuleItem[] = [];
  @Trace ruleProviders: RuleProvider[] = [];
  @Trace updatingRuleProviders: Map<string, boolean> = new Map<string, boolean>();
  @Trace rulesDisableSupported: boolean = true;
  /** Ops this backend rejected with 404/405/501 (some clients restrict the external controller) */
  @Trace unsupported: Map<string, number> = new Map<string, number>();

  // ----- connections -----
  @Trace activeConns: ConnItem[] = [];
  @Trace closedConns: ConnItem[] = [];
  @Trace connsPaused: boolean = false;
  @Trace connTotalUp: number = 0;
  @Trace connTotalDown: number = 0;

  // ----- logs -----
  @Trace logs: LogEntry[] = [];
  @Trace logsPaused: boolean = false;
  @Trace logLevel: string = 'info';

  // ----- overview -----
  @Trace traffic: Traffic = new Traffic(0, 0);
  @Trace trafficHistory: Traffic[] = emptyTraffic();
  @Trace memory: number = 0;
  @Trace memoryHistory: number[] = emptyNums();

  // ----- crash -----
  @Trace crashPrompt: boolean = false;

  // ----- privacy -----
  /** Whether the current privacy policy & agreement were accepted; no network requests before that */
  @Trace privacyAgreed: boolean = false;
  /** Legal document being viewed: '' | 'privacy' | 'agreement' */
  @Trace legalDoc: string = '';
  /** Backend held back until consent is given */
  private pendingBackend: Backend | null = null;

  // ----- navigation -----
  @Trace tab: number = 0;
  /** Open settings sub-page: '' | lang | backend | panel | proxy | conn | crash | about */
  @Trace settingsPage: string = '';

  // ================= init =================
  init(ctx: common.UIAbilityContext): void {
    this.ctx = ctx;
    if (this.inited) {
      return;
    }
    this.inited = true;
    const p = new Prefs(ctx);
    this.prefs = p;
    this.backends = p.getBackends();
    const activeId = p.str('active_backend', '');
    let act: Backend | null = null;
    for (const b of this.backends) {
      if (b.id === activeId) {
        act = b;
      }
    }
    if (act === null && this.backends.length > 0) {
      act = this.backends[0];
    }
    initLang(p.str('lang', 'system'));
    this.theme = p.str('theme', 'system');
    this.accent = findAccent(p.str('accent', 'blue')).key;
    this.testUrl = p.str('test_url', 'https://www.gstatic.com/generate_204');
    this.testTimeout = p.num('test_timeout', 5000);
    this.lowLatency = p.num('low_latency', 400);
    this.mediumLatency = p.num('medium_latency', 800);
    this.groupTestUrlFirst = p.bool('group_test_url', true);
    this.hideUnavailable = p.bool('hide_unavailable', false);
    this.sortProxies = p.str('sort_proxies', 'default');
    this.proxyCols = p.num('proxy_cols', 2);
    this.showGlobal = p.bool('show_global', true);
    this.showHiddenGroups = p.bool('show_hidden', false);
    this.logLevel = p.str('log_level', 'info');
    this.logMax = p.num('log_max', 1000);
    this.closedConnMax = p.num('closed_max', 500);
    this.connSort = p.str('conn_sort', 'start');
    this.connSortDesc = p.bool('conn_sort_desc', true);
    this.showRuleHits = p.bool('rule_hits', true);
    this.cardAlpha = p.num('card_alpha', 0.82);
    this.wallpaperBlur = p.num('wp_blur', 0);
    this.wallpaperDim = p.num('wp_dim', 0.1);
    const wp = p.str('wallpaper', '');
    this.wallpaperPath = (wp.length > 0 && FileUtil.exists(wp)) ? wp : '';
    this.glassOn = p.bool('glass_on', false);
    this.glassStyle = p.str('glass_style', 'custom');
    this.glassBlur = p.num('glass_blur', 45);
    this.glassAlpha = p.num('glass_alpha', 0.55);
    this.glassRows = p.bool('glass_rows', false);
    this.lightOn = p.bool('light_on', false);
    this.lightIntensity = p.num('light_intensity', 0.6);
    this.lightTilt = p.bool('light_tilt', false);
    this.lightGlow = p.bool('light_glow', true);
    this.lightSweep = p.bool('light_sweep', true);
    this.autoHideNav = p.bool('auto_hide_nav', true);
    this.sysMaterialSupported = detectSysMaterial();
    if (this.glassStyle === 'system' && !this.sysMaterialSupported) {
      this.glassStyle = 'custom';
    }
    this.updateTilt();
    this.crashPrompt = CrashLog.hasUnseen();
    this.privacyAgreed = p.num('privacy_agreed', 0) >= PRIVACY_VERSION;
    if (act !== null) {
      if (this.privacyAgreed) {
        this.connect(act);
      } else {
        this.pendingBackend = act;
      }
    }
  }

  /** First-launch consent: record the accepted version, then start connecting */
  agreePrivacy(): void {
    this.prefs?.put('privacy_agreed', PRIVACY_VERSION);
    this.privacyAgreed = true;
    const b = this.pendingBackend;
    this.pendingBackend = null;
    if (b !== null && this.active === null) {
      this.connect(b);
    }
  }

  /** Decline / withdraw: clear consent, disconnect and exit */
  declinePrivacy(): void {
    this.prefs?.remove('privacy_agreed');
    this.privacyAgreed = false;
    this.stopStreams();
    this.api = null;
    try {
      this.ctx?.terminateSelf().catch(() => {
      });
    } catch (e) {
      // ignore
    }
  }

  savePrefs(): void {
    const p = this.prefs;
    if (p === null) {
      return;
    }
    p.put('theme', this.theme);
    p.put('accent', this.accent);
    p.put('test_url', this.testUrl);
    p.put('test_timeout', this.testTimeout);
    p.put('low_latency', this.lowLatency);
    p.put('medium_latency', this.mediumLatency);
    p.put('group_test_url', this.groupTestUrlFirst);
    p.put('hide_unavailable', this.hideUnavailable);
    p.put('sort_proxies', this.sortProxies);
    p.put('proxy_cols', this.proxyCols);
    p.put('show_global', this.showGlobal);
    p.put('show_hidden', this.showHiddenGroups);
    p.put('log_max', this.logMax);
    p.put('closed_max', this.closedConnMax);
    p.put('rule_hits', this.showRuleHits);
    p.put('card_alpha', this.cardAlpha);
    p.put('wp_blur', this.wallpaperBlur);
    p.put('wp_dim', this.wallpaperDim);
    p.put('conn_sort', this.connSort);
    p.put('conn_sort_desc', this.connSortDesc);
    p.put('glass_on', this.glassOn);
    p.put('glass_style', this.glassStyle);
    p.put('glass_blur', this.glassBlur);
    p.put('glass_alpha', this.glassAlpha);
    p.put('glass_rows', this.glassRows);
    p.put('light_on', this.lightOn);
    p.put('light_intensity', this.lightIntensity);
    p.put('light_tilt', this.lightTilt);
    p.put('light_glow', this.lightGlow);
    p.put('light_sweep', this.lightSweep);
    p.put('auto_hide_nav', this.autoHideNav);
  }

  // ================= theme =================
  isDark(): boolean {
    if (this.theme === 'dark') {
      return true;
    }
    if (this.theme === 'light') {
      return false;
    }
    return this.systemDark;
  }

  palette(): Palette {
    const base = applyAccent(this.isDark() ? darkPalette() : lightPalette(), findAccent(this.accent));
    if (this.glassOn) {
      // Glass: Index draws the page background (wallpaper or soft gradient); cards are translucent
      base.bg = '#00000000';
      base.card = withAlpha(base.card, this.glassAlpha);
      base.chip = withAlpha(base.chip, Math.min(1, this.glassAlpha + 0.15));
      // 1.2.3: sheets/popups sit over another page; keep them nearly opaque (over the system blur) so text never mixes
      base.sheet = withAlpha(base.sheet, Math.max(0.88, Math.min(0.94, this.glassAlpha + 0.3)));
    } else if (this.wallpaperPath.length > 0) {
      base.bg = '#00000000';
      base.card = withAlpha(base.card, this.cardAlpha);
      base.chip = withAlpha(base.chip, Math.min(1, this.cardAlpha + 0.1));
    }
    return base;
  }

  /** 1.2.3: opaque page color (palette().bg turns transparent with glass/wallpaper); base layer of every overlay page */
  solidBg(): string {
    return this.isDark() ? darkPalette().bg : lightPalette().bg;
  }

  // ================= frosted glass / immersive light =================
  glassCfg(): GlassCfg {
    const c = new GlassCfg();
    const p = this.palette();
    c.dark = p.dark;
    c.card = p.card;
    c.accent = p.accentFill;
    c.glassOn = this.glassOn;
    c.glassStyle = this.glassStyle;
    c.glassBlur = Math.round(this.glassBlur);
    c.glassRows = this.glassRows;
    c.lightOn = this.lightOn;
    c.lightIntensity = Math.round(this.lightIntensity * 100) / 100;
    c.lightGlow = this.lightGlow;
    c.lightDeg = this.lightDeg;
    c.sysMaterial = this.sysMaterialSupported;
    return c;
  }

  /** Style modifier for cards/header/bar; the same object is reused while the config is unchanged */
  glass(kind: GlassKind): GlassModifier {
    const c = this.glassCfg();
    const k = c.key(kind);
    const hit = this.glassCache.get(k);
    if (hit !== undefined) {
      return hit;
    }
    if (this.glassCache.size > 60) {
      this.glassCache.clear();
    }
    const m = new GlassModifier(c, kind);
    this.glassCache.set(k, m);
    return m;
  }

  /** Background blur style for sheets and dialogs */
  sheetBlur(): BlurStyle {
    return sheetBlurStyle(this.glassCfg());
  }

  setGlass(on: boolean): void {
    this.glassOn = on;
    this.savePrefs();
  }

  setLight(on: boolean): void {
    this.lightOn = on;
    if (!on) {
      this.lightDeg = 330;
    }
    this.savePrefs();
    this.updateTilt();
  }

  setLightTilt(on: boolean): void {
    this.lightTilt = on;
    this.savePrefs();
    this.updateTilt();
    if (!on) {
      this.lightDeg = 330;
    }
  }

  setForeground(fg: boolean): void {
    this.foreground = fg;
    this.updateTilt();
  }

  /** Gravity sensor: subscribed at a low 100 ms rate only when light + tilt are on and in foreground; UI updates per 6° */
  updateTilt(): void {
    const want = this.lightOn && this.lightTilt && this.foreground;
    if (want === this.tiltOn) {
      return;
    }
    try {
      if (want) {
        this.tiltSmooth = this.lightDeg;
        sensor.on(sensor.SensorId.GRAVITY, (d: sensor.GravityResponse) => {
          this.onGravity(d.x, d.y);
        }, { interval: 100000000 });
        this.tiltOn = true;
      } else {
        sensor.off(sensor.SensorId.GRAVITY);
        this.tiltOn = false;
      }
    } catch (e) {
      this.tiltOn = false;
    }
  }

  private onGravity(gx: number, gy: number): void {
    // "World up" within the screen plane; lying flat (tiny projection) falls back to the default top-left light
    let target = 330;
    if (Math.sqrt(gx * gx + gy * gy) > 1.5) {
      target = Math.atan2(gx, gy) * 180 / Math.PI - 30;
    }
    // Smooth the angle (handles 360° wrap-around)
    const diff = ((target - this.tiltSmooth) % 360 + 540) % 360 - 180;
    this.tiltSmooth = (this.tiltSmooth + diff * 0.35 + 360) % 360;
    const q = (Math.round(this.tiltSmooth / 6) * 6) % 360;
    if (q !== this.lightDeg) {
      this.lightDeg = q;
    }
  }

  accentDef(): AccentDef {
    return findAccent(this.accent);
  }

  setAccent(key: string): void {
    this.accent = findAccent(key).key;
    this.savePrefs();
  }

  /** In-app language: 'system' | 'zh' | 'en'. Applies immediately (see I18n.ets); persisted in Preferences key `lang`. */
  setLanguage(pref: string): void {
    this.prefs?.put('lang', pref);
    setLangPref(pref);
  }

  langPref(): string {
    return I18N.pref;
  }

  setTheme(th: string): void {
    this.theme = th;
    this.savePrefs();
    this.applySystemBar();
  }

  // ================= immersive window =================
  /** Full-screen layout: background/wallpaper extends under the status bar and gesture area; content pads by the avoid areas */
  setupImmersive(win: window.Window): void {
    try {
      win.setWindowLayoutFullScreen(true).catch(() => {
      });
    } catch (e) {
      // ignore
    }
    this.updateAvoidArea(win);
    try {
      win.on('avoidAreaChange', (d: window.AvoidAreaOptions) => {
        if (d.type === window.AvoidAreaType.TYPE_SYSTEM || d.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          this.updateAvoidArea(win);
        }
      });
    } catch (e) {
      // ignore
    }
  }

  private px2vp(px: number): number {
    const ui = this.uiCtx;
    if (ui !== null) {
      try {
        return ui.px2vp(px);
      } catch (e) {
        // ignore
      }
    }
    return px / 3;
  }

  updateAvoidArea(win: window.Window): void {
    try {
      const sys = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const top = Math.round(this.px2vp(sys.topRect.height));
      if (top !== this.safeTop) {
        this.safeTop = top;
      }
    } catch (e) {
      // ignore
    }
    try {
      const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const bottom = Math.round(this.px2vp(nav.bottomRect.height));
      if (bottom !== this.safeBottom) {
        this.safeBottom = bottom;
      }
    } catch (e) {
      // ignore
    }
  }

  // ================= auto-hide bottom nav bar =================
  setAutoHideNav(on: boolean): void {
    this.autoHideNav = on;
    this.savePrefs();
    if (!on) {
      this.expandNav();
    }
  }

  private animNav(collapsed: boolean): void {
    if (this.navCollapsed === collapsed) {
      return;
    }
    const ui = this.uiCtx;
    if (ui === null) {
      this.navCollapsed = collapsed;
      return;
    }
    ui.animateTo({ duration: 380, curve: Curve.Friction }, () => {
      this.navCollapsed = collapsed;
    });
  }

  expandNav(): void {
    this.navAcc = 0;
    this.animNav(false);
  }

  collapseNav(): void {
    this.navAcc = 0;
    this.animNav(true);
  }

  /**
   * Every page's scroll container calls this from onDidScroll.
   * delta > 0: content moves up (scrolling down) -> collapse; delta < 0: content moves down (scrolling back) -> expand.
   * Only finger drags / fling count (programmatic scrolls are Idle and ignored); always expanded at the top;
   * the reverse movement of the end-of-list bounce is briefly ignored to avoid flicker.
   */
  navScroll(sc: Scroller, delta: number, state: ScrollState): void {
    if (this.navTab !== this.tab) {
      this.navTab = this.tab;
      this.navAcc = 0;
    }
    if (!this.autoHideNav || state === ScrollState.Idle || delta === 0) {
      return;
    }
    let y = 0;
    let atEnd = false;
    try {
      y = sc.currentOffset().yOffset;
      atEnd = sc.isAtEnd();
    } catch (e) {
      return;
    }
    if (y <= 8) {
      this.expandNav();
      return;
    }
    const now = Date.now();
    if (atEnd) {
      this.navLockUntil = now + 450;
      if (delta < 0) {
        return;
      }
    }
    if (now < this.navLockUntil && delta < 0) {
      return;
    }
    if ((this.navAcc > 0 && delta < 0) || (this.navAcc < 0 && delta > 0)) {
      this.navAcc = 0;
    }
    this.navAcc += delta;
    if (this.navAcc > 24) {
      this.collapseNav();
    } else if (this.navAcc < -18) {
      this.expandNav();
    }
  }

  applySystemBar(): void {
    const w = this.win;
    if (w === null) {
      return;
    }
    const dark = this.isDark();
    try {
      const props: window.SystemBarProperties = {
        statusBarContentColor: dark ? '#FFFFFF' : '#000000',
        navigationBarContentColor: dark ? '#FFFFFF' : '#000000'
      };
      w.setWindowSystemBarProperties(props).catch(() => {
      });
    } catch (e) {
      // ignore
    }
  }

  // ================= toast =================
  toast(msg: string): void {
    const ui = this.uiCtx;
    if (ui === null) {
      console.info('toast: ' + msg);
      return;
    }
    try {
      ui.getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (e) {
      console.info('toast: ' + msg);
    }
  }

  isUnsupported(key: string): boolean {
    return this.unsupported.has(key);
  }

  /** Kotlin launchSafe: catch and toast errors; 404/405/501 are recorded as "not supported by backend" */
  async run(label: string, key: string, task: Task): Promise<boolean> {
    try {
      await task();
      return true;
    } catch (e) {
      if (e instanceof ApiError) {
        const ae = e as ApiError;
        if ((ae.code === 404 || ae.code === 405 || ae.code === 501) && key.length > 0) {
          this.unsupported.set(key, ae.code);
          this.toast(t('op_failed_unsupported', label.length > 0 ? label : key, ae.code));
          return false;
        }
      }
      this.toast(label.length > 0 ? t('op_failed', label, errMsg(e as Object)) : errMsg(e as Object));
      return false;
    }
  }

  // ================= backend management =================
  newBackendId(): string {
    return util.generateRandomUUID(false);
  }

  saveBackend(b: Backend, activate: boolean): void {
    const list = this.backends.slice();
    let found = false;
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === b.id) {
        list[i] = b;
        found = true;
      }
    }
    if (!found) {
      list.push(b);
    }
    this.backends = list;
    this.prefs?.setBackends(list);
    const a = this.active;
    if (activate || (a !== null && a.id === b.id)) {
      this.connect(b);
    }
  }

  deleteBackend(b: Backend): void {
    const list = this.backends.filter((x: Backend) => x.id !== b.id);
    this.backends = list;
    this.prefs?.setBackends(list);
    const a = this.active;
    if (a !== null && a.id === b.id) {
      if (list.length > 0) {
        this.connect(list[0]);
      } else {
        this.disconnect();
      }
    }
  }

  disconnect(): void {
    this.stopStreams();
    this.api = null;
    this.active = null;
    this.prefs?.put('active_backend', '');
    this.connState = 'idle';
    this.proxies = new Map<string, ProxyItem>();
    this.rules = [];
    this.activeConns = [];
    this.logs = [];
  }

  connect(b: Backend): void {
    this.stopStreams();
    this.active = b;
    this.prefs?.put('active_backend', b.id);
    const a = new CoreApi(b);
    this.api = a;
    this.connState = 'connecting';
    this.connError = '';
    this.unsupported = new Map<string, number>();
    this.rulesDisableSupported = true;
    this.proxies = new Map<string, ProxyItem>();
    this.providers = [];
    this.rules = [];
    this.ruleProviders = [];
    this.activeConns = [];
    this.closedConns = [];
    this.logs = [];
    this.prevConns = new Map<string, ConnItem>();
    this.trafficHistory = emptyTraffic();
    this.memoryHistory = emptyNums();
    this.traffic = new Traffic(0, 0);
    this.memory = 0;
    this.version = '';
    a.version().then((v: VersionInfo) => {
      if (this.api !== a) {
        return;
      }
      this.version = v.version;
      const lv = v.version.toLowerCase();
      this.isMeta = v.meta || lv.indexOf('meta') >= 0 || lv.startsWith('v1.1') || lv.startsWith('alpha');
      this.connState = 'connected';
      this.startStreams(a);
      this.refreshAll();
    }).catch((e: Object) => {
      if (this.api !== a) {
        return;
      }
      this.connState = 'failed';
      this.connError = errMsg(e);
    });
  }

  /** Tests a backend without switching to it */
  async probe(b: Backend): Promise<string> {
    const v = await new CoreApi(b).version();
    return v.version.length > 0 ? v.version : t('no_version');
  }

  retry(): void {
    const a = this.active;
    if (a !== null) {
      this.connect(a);
    }
  }

  refreshAll(): void {
    this.refreshConfig();
    this.refreshProxies();
    this.refreshRules();
  }

  // ================= streams =================
  private stopStreams(): void {
    for (const s of this.streams) {
      s.stop();
    }
    this.streams = [];
    if (this.logStream !== null) {
      this.logStream.stop();
      this.logStream = null;
    }
    if (this.logTimer >= 0) {
      clearTimeout(this.logTimer);
      this.logTimer = -1;
    }
    this.logBuf = [];
  }

  private startStreams(a: CoreApi): void {
    this.streams.push(a.openStream('/traffic', (t: string) => {
      if (this.api !== a) {
        return;
      }
      const o = parseJsonObj(t);
      const tr = new Traffic(jNum(o, 'up'), jNum(o, 'down'));
      this.traffic = tr;
      const h = this.trafficHistory.slice(this.trafficHistory.length >= HISTORY_LEN ? 1 : 0);
      h.push(tr);
      this.trafficHistory = h;
    }));
    this.streams.push(a.openStream('/memory', (t: string) => {
      if (this.api !== a) {
        return;
      }
      const m = jNum(parseJsonObj(t), 'inuse');
      this.memory = m;
      const h = this.memoryHistory.slice(this.memoryHistory.length >= HISTORY_LEN ? 1 : 0);
      h.push(m);
      this.memoryHistory = h;
    }));
    this.streams.push(a.openStream('/connections?interval=1000', (t: string) => {
      if (this.api !== a) {
        return;
      }
      this.onConnections(parseJsonObj(t));
    }));
    this.restartLogs(a);
  }

  private restartLogs(a: CoreApi): void {
    if (this.logStream !== null) {
      this.logStream.stop();
      this.logStream = null;
    }
    this.logStream = a.openStream('/logs?level=' + this.logLevel, (t: string) => {
      if (this.api !== a || this.logsPaused) {
        return;
      }
      const o = parseJsonObj(t);
      this.logSeq++;
      this.logBuf.push(new LogEntry(this.logSeq, jStr(o, 'type'), jStr(o, 'payload'), Date.now()));
      if (this.logTimer < 0) {
        // Batch logs within 250 ms to avoid re-rendering too often
        this.logTimer = setTimeout(() => {
          this.logTimer = -1;
          this.flushLogs();
        }, 250);
      }
    });
  }

  private flushLogs(): void {
    if (this.logBuf.length === 0) {
      return;
    }
    const merged = this.logs.concat(this.logBuf);
    this.logBuf = [];
    const max = Math.max(50, this.logMax);
    this.logs = merged.length > max ? merged.slice(merged.length - max) : merged;
  }

  private onConnections(o: JObj): void {
    this.connTotalUp = jNum(o, 'uploadTotal');
    this.connTotalDown = jNum(o, 'downloadTotal');
    const arr = jArr(o, 'connections');
    const list: ConnItem[] = [];
    if (arr !== undefined) {
      for (const e of arr) {
        const co = asObj(e);
        if (co !== undefined) {
          list.push(parseConnection(co));
        }
      }
    }
    const prev = this.prevConns;
    const now = Date.now();
    const next = new Map<string, ConnItem>();
    for (const c of list) {
      const p = prev.get(c.id);
      if (p !== undefined) {
        c.uploadSpeed = Math.max(0, c.upload - p.upload);
        c.downloadSpeed = Math.max(0, c.download - p.download);
      }
      next.set(c.id, c);
    }
    const closedNow: ConnItem[] = [];
    prev.forEach((c: ConnItem, id: string) => {
      if (!next.has(id)) {
        const cc = c.copy();
        cc.uploadSpeed = 0;
        cc.downloadSpeed = 0;
        cc.closedAt = now;
        closedNow.push(cc);
      }
    });
    this.prevConns = next;
    if (closedNow.length > 0) {
      const merged = closedNow.concat(this.closedConns);
      this.closedConns = merged.length > this.closedConnMax ? merged.slice(0, this.closedConnMax) : merged;
    }
    if (!this.connsPaused) {
      this.activeConns = list;
    }
  }

  // ================= config =================
  refreshConfig(label: string = ''): Promise<boolean> {
    const a = this.api;
    if (a === null) {
      return Promise.resolve(false);
    }
    return this.run(label, '', async () => {
      const c = await a.configs();
      if (this.api === a) {
        this.config = c;
      }
    });
  }

  setMode(mode: string): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.run(t('act_mode'), 'patch', async () => {
      const b: JObj = { 'mode': mode };
      await a.patchConfigs(b);
      const c = this.config.copy();
      c.mode = mode;
      this.config = c;
      this.refreshProxies();
    });
  }

  private patchConfig(label: string, body: JObj, local: (c: CoreConfig) => void): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.run(label, 'patch', async () => {
      await a.patchConfigs(body);
      const c = this.config.copy();
      local(c);
      this.config = c;
      await sleep(300);
      const fresh = await a.configs();
      if (this.api === a) {
        this.config = fresh;
      }
    });
  }

  setTun(enable: boolean): void {
    const tun: JObj = { 'enable': enable };
    const b: JObj = { 'tun': tun };
    this.patchConfig('TUN', b, (c: CoreConfig) => {
      c.tunEnable = enable;
    });
  }

  setAllowLan(v: boolean): void {
    const b: JObj = { 'allow-lan': v };
    this.patchConfig(t('act_lan'), b, (c: CoreConfig) => {
      c.allowLan = v;
    });
  }

  setIpv6(v: boolean): void {
    const b: JObj = { 'ipv6': v };
    this.patchConfig('IPv6', b, (c: CoreConfig) => {
      c.ipv6 = v;
    });
  }

  setCoreLogLevel(v: string): void {
    const b: JObj = { 'log-level': v };
    this.patchConfig(t('act_loglevel'), b, (c: CoreConfig) => {
      c.logLevel = v;
    });
  }

  setPort(key: string, v: number): void {
    const b: JObj = {};
    b[key] = v;
    this.patchConfig(t('act_port'), b, (c: CoreConfig) => {
    });
  }

  /** Core maintenance op. key (reload | geo | fakeip | dns | upgrade | restart) also marks "unsupported"; label is t('op_' + key) */
  coreAction(key: string, fn: (a: CoreApi) => Promise<void>): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    const label = t('op_' + key);
    this.run(label, key, async () => {
      await fn(a);
      this.toast(t('act_ok', label));
      if (key !== 'restart') {
        await sleep(500);
        this.refreshAll();
      } else {
        await sleep(2500);
        this.retry();
      }
    });
  }

  // ================= pull to refresh (1.1.9) =================
  /**
   * Pull to refresh: the indicator stays until the requests finish (success or failure); run() toasts failures.
   * No network requests before the privacy policy is accepted.
   */
  async pullRefresh(page: string): Promise<void> {
    if (!this.privacyAgreed) {
      return;
    }
    const a = this.api;
    if (a === null) {
      this.toast(this.active === null ? t('not_connected_yet') : t('backend_not_connected'));
      return;
    }
    if (this.connState !== 'connected') {
      // Failed or still connecting: reconnect once and wait for the version probe
      const b = this.active;
      if (b !== null) {
        this.connect(b);
        await this.waitConnected(8000);
        if (this.connState !== 'connected') {
          this.toast(t('refresh_failed', this.connError.length > 0 ? this.connError : t('err_connect')));
        }
      }
      return;
    }
    const L = t('act_refresh');
    if (page === 'proxies') {
      await this.refreshProxies(L);
    } else if (page === 'rules') {
      await this.refreshRules(L);
    } else if (page === 'connections' || page === 'logs') {
      // Connections and logs come from live streams: probe the backend, then restart the streams
      const ok = await this.run(L, '', async () => {
        await a.version();
      });
      if (ok && this.api === a) {
        this.stopStreams();
        this.startStreams(a);
      }
    } else {
      // Overview: probe first (one toast on failure), then refresh config, proxies and rules in parallel
      const ok = await this.run(L, '', async () => {
        const v = await a.version();
        if (this.api === a) {
          this.version = v.version;
        }
      });
      if (!ok || this.api !== a) {
        return;
      }
      await Promise.all([this.refreshConfig(L), this.refreshProxies(L), this.refreshRules(L)]);
      if (this.api === a && this.streams.length === 0) {
        this.startStreams(a);
      }
    }
  }

  private waitConnected(timeoutMs: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      const t0 = Date.now();
      const tick = () => {
        if (this.connState !== 'connecting' || Date.now() - t0 > timeoutMs) {
          resolve();
          return;
        }
        setTimeout(tick, 150);
      };
      tick();
    });
  }

  // ================= proxies =================
  refreshProxies(label: string = ''): Promise<boolean> {
    const a = this.api;
    if (a === null) {
      return Promise.resolve(false);
    }
    return this.run(label, '', async () => {
      this.proxiesLoading = true;
      try {
        const pp = a.proxies();
        const pr = a.proxyProviders().catch((): ProxyProvider[] => []);
        const p = await pp;
        const providers = await pr;
        if (this.api !== a) {
          return;
        }
        this.proxies = p;
        this.providers = providers;
        this.manualDelay = new Map<string, number>();
      } finally {
        this.proxiesLoading = false;
      }
    });
  }

  groups(): ProxyItem[] {
    const all = this.proxies;
    const global = all.get('GLOBAL');
    const order: string[] = global !== undefined ? global.all : [];
    const idx = new Map<string, number>();
    for (let i = 0; i < order.length; i++) {
      idx.set(order[i], i);
    }
    const gs: ProxyItem[] = [];
    all.forEach((p: ProxyItem) => {
      if (p.isGroup() && p.name !== 'GLOBAL' && (this.showHiddenGroups || !p.hidden)) {
        gs.push(p);
      }
    });
    gs.sort((x: ProxyItem, y: ProxyItem) => {
      const ix = idx.get(x.name);
      const iy = idx.get(y.name);
      return (ix !== undefined ? ix : 1e9) - (iy !== undefined ? iy : 1e9);
    });
    if (global !== undefined && this.showGlobal) {
      return [global].concat(gs);
    }
    return gs;
  }

  groupTestUrl(g: ProxyItem): string {
    return (this.groupTestUrlFirst && g.testUrl.length > 0) ? g.testUrl : this.testUrl;
  }

  delayOf(name: string, url: string): number {
    const md = this.manualDelay.get(name);
    if (md !== undefined) {
      return md;
    }
    const p = this.proxies.get(name);
    if (p === undefined) {
      return 0;
    }
    // A group shows the delay of its current selection (resolved down to the final node)
    if (p.isGroup() && p.now.length > 0 && p.now !== name) {
      const seen = new Set<string>();
      let cur: ProxyItem | undefined = p;
      while (cur !== undefined && cur.isGroup() && cur.now.length > 0 && !seen.has(cur.name)) {
        seen.add(cur.name);
        cur = this.proxies.get(cur.now);
      }
      return cur !== undefined ? cur.delayFor(url) : 0;
    }
    return p.delayFor(url);
  }

  /** Resolves a group chain to its final node */
  resolveNow(name: string): string {
    const seen = new Set<string>();
    let cur = this.proxies.get(name);
    while (cur !== undefined && cur.isGroup() && cur.now.length > 0 && !seen.has(cur.name)) {
      seen.add(cur.name);
      const next = this.proxies.get(cur.now);
      if (next === undefined) {
        return cur.now;
      }
      cur = next;
    }
    return cur !== undefined ? cur.name : name;
  }

  nodesOf(g: ProxyItem): string[] {
    let list = g.all.slice();
    const url = this.groupTestUrl(g);
    if (this.hideUnavailable) {
      list = list.filter((n: string) => {
        const p = this.proxies.get(n);
        return p === undefined || p.isGroup() || this.delayOf(n, url) > 0 || !p.hasHistory;
      });
    }
    if (this.sortProxies === 'latency') {
      list.sort((x: string, y: string) => {
        const dx = this.delayOf(x, url);
        const dy = this.delayOf(y, url);
        return (dx <= 0 ? 1e9 : dx) - (dy <= 0 ? 1e9 : dy);
      });
    } else if (this.sortProxies === 'name') {
      list.sort((x: string, y: string) => x.localeCompare(y));
    }
    return list;
  }

  isSelectable(g: ProxyItem): boolean {
    const t = g.type.toLowerCase();
    return t === 'selector' || t === 'urltest' || t === 'fallback';
  }

  select(group: ProxyItem, name: string): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    if (!this.isSelectable(group)) {
      this.toast(t('group_not_selectable', group.type));
      return;
    }
    this.run(t('act_select'), 'select', async () => {
      await a.selectProxy(group.name, name);
      const m = new Map<string, ProxyItem>(this.proxies);
      const g2 = group.copy();
      g2.now = name;
      g2.fixed = group.type.toLowerCase() === 'selector' ? '' : name;
      m.set(group.name, g2);
      this.proxies = m;
      this.refreshProxies();
    });
  }

  private async pool(names: string[], limit: number, fn: (n: string) => Promise<void>): Promise<void> {
    let i = 0;
    const worker = async (): Promise<void> => {
      while (i < names.length) {
        const n = names[i];
        i++;
        await fn(n);
      }
    };
    const ws: Promise<void>[] = [];
    for (let k = 0; k < Math.min(limit, names.length); k++) {
      ws.push(worker());
    }
    await Promise.all(ws);
  }

  testGroup(g: ProxyItem): void {
    const a = this.api;
    if (a === null || this.testing.get(g.name) === true) {
      return;
    }
    this.run(t('act_test'), 'test', async () => {
      this.testing.set(g.name, true);
      try {
        const url = this.groupTestUrl(g);
        let ok = false;
        try {
          const res = await a.groupDelay(g.name, url, this.testTimeout);
          for (const n of g.all) {
            const d = res.get(n);
            this.manualDelay.set(n, d !== undefined ? d : 0);
          }
          ok = true;
        } catch (e) {
          // 5xx = every node timed out; 404 = core has no /group API -> test nodes one by one
          if (e instanceof ApiError && (e as ApiError).code >= 500 && (e as ApiError).code <= 599) {
            for (const n of g.all) {
              this.manualDelay.set(n, 0);
            }
            ok = true;
          }
        }
        if (!ok) {
          const nodes = g.all.filter((n: string) => {
            const p = this.proxies.get(n);
            return p === undefined || !p.isGroup();
          });
          await this.pool(nodes, 8, async (n: string) => {
            let d = 0;
            try {
              d = await a.proxyDelay(n, url, this.testTimeout);
            } catch (e) {
              d = 0;
            }
            this.manualDelay.set(n, d);
          });
        }
        const p = await a.proxies();
        if (this.api === a) {
          // keep the results just measured
          this.proxies = p;
        }
      } finally {
        this.testing.delete(g.name);
      }
    });
  }

  testNode(name: string, url: string): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.nodeTesting.set(name, true);
    a.proxyDelay(name, url, this.testTimeout).then((d: number) => {
      this.manualDelay.set(name, d);
    }).catch(() => {
      this.manualDelay.set(name, 0);
    }).finally(() => {
      this.nodeTesting.delete(name);
    });
  }

  /** 1.2.6: true while any proxy group latency test is running (drives the header test-all spinner) */
  anyGroupTesting(): boolean {
    let busy = false;
    this.testing.forEach((v: boolean, k: string) => {
      if (v && !k.startsWith('provider:')) {
        busy = true;
      }
    });
    return busy;
  }

  testAllGroups(): void {
    for (const g of this.groups()) {
      if (g.name !== 'GLOBAL') {
        this.testGroup(g);
      }
    }
  }

  unfix(g: ProxyItem): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.run(t('act_unfix'), 'unfix', async () => {
      await a.unfixProxy(g.name);
      this.refreshProxies();
    });
  }

  updateProvider(name: string): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.run(t('act_update_sub'), 'update_provider', async () => {
      await a.updateProxyProvider(name);
      this.toast(t('updated_name', name));
      this.refreshProxies();
    });
  }

  healthcheck(name: string): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    const key = 'provider:' + name;
    this.run(t('act_healthcheck'), 'healthcheck', async () => {
      this.testing.set(key, true);
      try {
        await a.healthcheckProvider(name);
        this.refreshProxies();
      } finally {
        this.testing.delete(key);
      }
    });
  }

  updateAllProviders(): void {
    for (const p of this.providers) {
      this.updateProvider(p.name);
    }
  }

  // ================= rules =================
  refreshRules(label: string = ''): Promise<boolean> {
    const a = this.api;
    if (a === null) {
      return Promise.resolve(false);
    }
    return this.run(label, '', async () => {
      const rp = a.ruleProviders().catch((): RuleProvider[] => []);
      const r = await a.rules();
      const providers = await rp;
      if (this.api !== a) {
        return;
      }
      this.rules = r;
      this.ruleProviders = providers;
    });
  }

  toggleRule(r: RuleItem): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.run(t('act_toggle_rule'), 'toggle_rule', async () => {
      try {
        await a.setRuleDisabled(r.index, !r.disabled);
        this.rules = this.rules.map((x: RuleItem) => {
          if (x.index === r.index) {
            const y = x.copy();
            y.disabled = !r.disabled;
            return y;
          }
          return x;
        });
      } catch (e) {
        if (e instanceof ApiError && ((e as ApiError).code === 404 || (e as ApiError).code === 405)) {
          this.rulesDisableSupported = false;
          this.toast(t('rule_disable_unsupported'));
          return;
        }
        throw e as Error;
      }
    });
  }

  updateRuleProvider(name: string): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.run(t('act_update_ruleset'), 'update_ruleset', async () => {
      this.updatingRuleProviders.set(name, true);
      try {
        await a.updateRuleProvider(name);
        this.refreshRules();
      } finally {
        this.updatingRuleProviders.delete(name);
      }
    });
  }

  updateAllRuleProviders(): void {
    for (const p of this.ruleProviders) {
      this.updateRuleProvider(p.name);
    }
  }

  // ================= connections =================
  closeConn(id: string): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.run(t('act_close_conn'), 'close_conn', async () => {
      await a.closeConnection(id);
    });
  }

  closeConns(ids: string[]): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.run(t('act_close_conn'), 'close_conn', async () => {
      for (const id of ids) {
        try {
          await a.closeConnection(id);
        } catch (e) {
          // ignore single failure
        }
      }
    });
  }

  closeAll(): void {
    const a = this.api;
    if (a === null) {
      return;
    }
    this.run(t('act_close_all'), 'close_all', async () => {
      await a.closeAllConnections();
    });
  }

  clearClosed(): void {
    this.closedConns = [];
  }

  setConnSort(s: string, desc: boolean): void {
    this.connSort = s;
    this.connSortDesc = desc;
    this.savePrefs();
  }

  // ================= logs =================
  setLevel(l: string): void {
    this.logLevel = l;
    this.prefs?.put('log_level', l);
    const a = this.api;
    if (a !== null) {
      this.restartLogs(a);
    }
  }

  clearLogs(): void {
    this.logs = [];
  }

  // ================= wallpaper =================
  setWallpaperFromUri(uri: string): void {
    const ctx = this.ctx;
    if (ctx === null) {
      return;
    }
    try {
      const dest = ctx.filesDir + '/wallpaper-' + Date.now() + '.img';
      FileUtil.copyUriTo(uri, dest);
      const old = this.wallpaperPath;
      this.wallpaperPath = dest;
      this.prefs?.put('wallpaper', dest);
      if (old.length > 0 && old !== dest) {
        FileUtil.remove(old);
      }
      this.toast(t('wallpaper_updated'));
    } catch (e) {
      this.toast(t('wallpaper_read_failed'));
    }
  }

  clearWallpaper(): void {
    const old = this.wallpaperPath;
    this.wallpaperPath = '';
    this.prefs?.put('wallpaper', '');
    if (old.length > 0) {
      FileUtil.remove(old);
    }
  }

  wallpaperSrc(): string {
    return this.wallpaperPath.length > 0 ? fileUri.getUriFromPath(this.wallpaperPath) : '';
  }

  shutdown(): void {
    this.foreground = false;
    this.updateTilt();
    this.stopStreams();
  }
}
