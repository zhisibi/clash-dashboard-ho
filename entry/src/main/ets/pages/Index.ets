import { Store } from '../common/Store';
import { Backend } from '../common/Models';
import { CrashLog } from '../common/CrashLog';
import { BackendForm } from '../components/BackendForm';
import { OverviewView } from '../views/OverviewView';
import { ProxiesView } from '../views/ProxiesView';
import { ConnectionsView } from '../views/ConnectionsView';
import { LogsView } from '../views/LogsView';
import { HonkOverviewView } from '../views/HonkOverviewView';
import { HonkPolicyView } from '../views/HonkPolicyView';
import { RulesView } from '../views/RulesView';
import { SettingsView, CrashDetail } from '../views/SettingsView';
import { withAlpha } from '../common/Theme';
import { LegalView } from '../components/LegalView';
import { GlassGradient, PageBackdrop } from '../components/PageBackdrop';
import { I18N, t } from '../common/I18n';
import { Motion } from '../common/Motion';
import { MOTION_TAB } from '../common/MotionLogic';
import { BarBackdropMod, BarGlassMod, GLASS_LABEL_DARK, GLASS_LABEL_SHADOW_DARK, GLASS_LABEL_SHADOW_LIGHT,
  GlassRimMod, NavLightSense } from '../common/NavLight';
import { ReviewPrompt } from '../common/ReviewPrompt';
import { ReviewCard } from '../components/ReviewCard';

class TabDef {
  /** i18n key of the tab label */
  title: string = '';
  icon: Resource;

  constructor(title: string, icon: Resource) {
    this.title = title;
    this.icon = icon;
  }
}

const TABS: TabDef[] = [
  new TabDef('tab_overview', $r('sys.symbol.house')),
  new TabDef('tab_proxies', $r('sys.symbol.paperplane')),
  new TabDef('tab_conns', $r('sys.symbol.arrow_left_arrow_right')),
  new TabDef('tab_logs', $r('sys.symbol.doc_text')),
  new TabDef('tab_rules', $r('sys.symbol.list_bullet')),
  new TabDef('tab_settings', $r('sys.symbol.gearshape'))
];

/** Height of the expanded bottom bar */
const BAR_H: number = 64;
/** Diameter of the collapsed round button */
const DOT: number = 56;

@Entry
@ComponentV2
struct Index {
  private store: Store = Store.get();
  private review: ReviewPrompt = ReviewPrompt.get();
  @Local showCrash: boolean = false;
  @Local crashName: string = '';
  /** Light sweep position: -1 off the left edge, 1 off the right edge */
  @Local sweepPos: number = -1;
  @Local sweepShow: boolean = false;
  @Local barWidth: number = 360;
  /** Root width, for the bar <-> round button width animation */
  @Local rootW: number = 0;
  /** Target page of a running page animation (-1 = none), so the bar highlight follows right away */
  @Local navTarget: number = -1;
  private tabsCtl: TabsController = new TabsController();

  aboutToAppear(): void {
    // 1.3.0: gentle review prompt - evaluate once the main UI has settled (consent / no-backend states are
    // excluded inside consider(); a running connection attempt counts as busy and blocks the prompt)
    setTimeout(() => {
      this.review.consider(this.store.connState === 'connecting');
    }, 2500);
    if (this.store.crashPrompt) {
      setTimeout(() => {
        this.promptCrash();
      }, 600);
    }
  }

  /** Bar distance from the bottom edge: close to the gesture indicator with ~8 vp gap */
  navBottom(): number {
    const b = this.store.safeBottom;
    return b > 0 ? Math.max(8, b - 6) : 10;
  }

  /** Bottom padding of page i's content so the last item can scroll above the bar */
  bottomPad(i: number): number {
    return this.navBottom() + BAR_H + 16 + (this.store.connState === 'failed' && i !== 5 ? 52 : 0);
  }

  /**
   * 1.5.9: Store.tab always holds a page id (0 overview, 1 proxies/policy, 2 connections,
   * 3 logs, 4 rules, 5 settings), but bar/Tabs positions are per backend kind: honk backends
   * have no page at slot 3 (their tools page was removed; slot 3 is the clash logs page),
   * so honk shows five tabs. Positions translate through this list.
   */
  visPages(): number[] {
    return this.store.activeIsHonk() ? [0, 1, 2, 4, 5] : [0, 1, 2, 3, 4, 5];
  }

  /** Bar/Tabs position of a page id (0 when the page is not visible in this mode) */
  visPos(page: number): number {
    const v = this.visPages();
    const i = v.indexOf(page);
    return i >= 0 ? i : 0;
  }

  /** Page id at a bar/Tabs position (clamped into range) */
  pageAt(pos: number): number {
    const v = this.visPages();
    if (pos < 0) {
      return v[0];
    }
    if (pos >= v.length) {
      return v[v.length - 1];
    }
    return v[pos];
  }

  /** Highlighted bar position: the target position while a page animation runs */
  selPos(): number {
    return this.navTarget >= 0 ? this.navTarget : this.visPos(this.store.tab);
  }

  /** Page the bar currently points at (collapsed-bar icon) */
  selPage(): number {
    return this.navTarget >= 0 ? this.pageAt(this.navTarget) : this.store.tab;
  }

  /** Tab label for a page: 1.5.9 honk renames the proxies tab via honk_routing (clash keeps tab_proxies) */
  tabLabel(page: number): string {
    if (page === 1 && this.store.activeIsHonk()) {
      return t('honk_routing');
    }
    return t(TABS[page].title);
  }

  /** Tab tapped (bar position): animate to that page (position and Store.tab are synced back through Tabs.onChange) */
  selectTab(pos: number): void {
    if (pos < 0 || pos >= this.visPages().length) {
      return;
    }
    if (this.pageAt(pos) === this.store.tab && this.navTarget < 0) {
      return;
    }
    this.navTarget = pos;
    try {
      this.tabsCtl.changeIndex(pos);
    } catch (e) {
      // ignore
    }
    // Fallback: if onChange never fires (e.g. controller not bound yet), write Store.tab; the Tabs index follows
    setTimeout(() => {
      if (this.store.tab !== this.pageAt(pos) && this.navTarget === pos) {
        this.store.tab = this.pageAt(pos);
        this.navTarget = -1;
      }
    }, 650);
  }

  /** Tabs page changed (tap or swipe); i is a bar position, Store.tab stores the page id */
  onPageChanged(i: number): void {
    this.navTarget = -1;
    const page = this.pageAt(i);
    if (this.store.tab !== page) {
      this.store.tab = page;
      this.sweep();
    }
    // Swiping to another page expands an auto-hidden bar again
    this.store.expandNav();
  }

  collapsed(): boolean {
    // 1.3.0: with the nav bar immersive light sense on, the bar never collapses (MimiSSH rule)
    return !this.store.navLight && this.store.autoHideNav && this.store.navCollapsed;
  }

  onBackPress(): boolean | void {
    if (this.store.legalDoc.length > 0) {
      this.store.legalDoc = '';
      return true;
    }
    if (this.collapsed()) {
      this.store.expandNav();
    }
    if (this.store.tab === 5 && this.store.settingsPage.length > 0) {
      this.store.settingsPage = '';
      return true;
    }
    return false;
  }

  /** One light sweep across the bar (one-shot; the layer is removed afterwards) */
  sweep(): void {
    if (!this.store.lightOn || !this.store.lightSweep) {
      return;
    }
    this.sweepShow = true;
    this.sweepPos = -1;
    this.getUIContext().animateTo({
      duration: 900,
      curve: Curve.EaseInOut,
      onFinish: () => {
        this.sweepShow = false;
        this.sweepPos = -1;
      }
    }, () => {
      this.sweepPos = 1;
    });
  }

  /** With glass on and no wallpaper, draw a soft accent gradient so the blur and light are visible */
  @Builder
  glassBackdrop() {
    GlassGradient()
  }

  promptCrash(): void {
    this.getUIContext().showAlertDialog({
      title: t('crash_prompt_title'),
      message: t('crash_prompt_msg'),
      autoCancel: true,
      primaryButton: {
        value: t('ignore'),
        action: () => {
          CrashLog.markSeen();
          this.store.crashPrompt = false;
        }
      },
      secondaryButton: {
        value: t('view_log'),
        action: () => {
          CrashLog.markSeen();
          this.store.crashPrompt = false;
          const l = CrashLog.list();
          if (l.length > 0) {
            this.crashName = l[0];
            this.showCrash = true;
          }
        }
      },
      cancel: () => {
        CrashLog.markSeen();
        this.store.crashPrompt = false;
      }
    });
  }

  @Builder
  crashSheet() {
    CrashDetail({
      name: this.crashName, onClose: () => {
        this.showCrash = false;
      }
    })
  }

  /** First launch: no network requests before consent; declining exits the app */
  @Builder
  consentScreen() {
    // 1.2.3: own opaque backdrop. After a withdrawn consent the backends (and a wallpaper) remain, and the root then
    // only drew black under the transparent page color
    Stack() {
      PageBackdrop()
    Column() {
      Scroll() {
        Column() {
          Image($r('app.media.layered_image')).width(72).height(72).borderRadius(18)
          Text(t('consent_welcome'))
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.store.palette().text)
            .margin({ top: 16 })
          Text(t('consent_intro'))
            .fontSize(14)
            .lineHeight(22)
            .fontColor(this.store.palette().subtle)
            .margin({ top: 10 })
          // 1.4.17 (on-market risk control): first-run statement of what the app is and is not,
          // shown prominently at the top of the consent screen, before the policy links and the
          // Agree button. Same text also closes section 1 of the user agreement.
          Column() {
            Text(t('consent_decl_1'))
              .fontSize(14).lineHeight(22).fontWeight(FontWeight.Medium)
              .fontColor(this.store.palette().text)
            Text(t('consent_decl_2'))
              .fontSize(14).lineHeight(22).fontWeight(FontWeight.Medium)
              .fontColor(this.store.palette().text)
              .margin({ top: 4 })
            Text(t('consent_decl_3'))
              .fontSize(14).lineHeight(22).fontWeight(FontWeight.Medium)
              .fontColor(this.store.palette().text)
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 16 })
          .padding(16)
          .borderRadius(16)
          .backgroundColor(this.store.palette().chip)
          .border({ width: 1, color: this.store.palette().warn })
          Column() {
            this.consentPoint(t('consent_p1'))
            this.consentPoint(t('consent_p2'))
            this.consentPoint(t('consent_p3'))
            this.consentPoint(t('consent_p4'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 16 })
          .padding(16)
          .borderRadius(16)
          .backgroundColor(this.store.palette().chip)

          Text() {
            Span(t('consent_read'))
            Span(t('privacy_policy_q'))
              .fontColor(this.store.palette().accent)
              .onClick(() => {
                this.store.legalDoc = 'privacy';
              })
            Span(t('consent_and'))
            Span(t('user_agreement_q'))
              .fontColor(this.store.palette().accent)
              .onClick(() => {
                this.store.legalDoc = 'agreement';
              })
            Span(t('consent_tail'))
          }
          .fontSize(14)
          .lineHeight(22)
          .fontColor(this.store.palette().text)
          .margin({ top: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 24, right: 24, top: this.store.safeTop + 40, bottom: 16 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })

      Row() {
        Button(t('disagree'), { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontColor(this.store.palette().text)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            this.store.declinePrivacy();
          })
        Blank().width(12)
        Button(t('agree'), { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontColor(this.store.palette().onPrimary)
          .backgroundColor(this.store.palette().primary)
          .onClick(() => {
            this.store.agreePrivacy();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 8, bottom: this.store.safeBottom + 16 })
    }
    .width('100%')
    .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  consentPoint(t: string) {
    Row() {
      Text('•').fontSize(14).fontColor(this.store.palette().accentUi).width(14)
      Text(t).fontSize(14).lineHeight(22).fontColor(this.store.palette().text).layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ top: 2, bottom: 2 })
  }

  @Builder
  setupScreen() {
    Scroll() {
      Column() {
        Blank().height(40)
        SymbolGlyph($r('sys.symbol.paperplane')).fontSize(56).fontColor([this.store.palette().accentUi])
        Text(t('setup_title'))
          .fontSize(26)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().text)
          .margin({ top: 16 })
        Text(t('setup_desc'))
          .fontSize(14)
          .fontColor(this.store.palette().subtle)
          .margin({ top: 6, bottom: 24 })
        Column() {
          BackendForm({ initial: new Backend(this.store.newBackendId()) })
        }
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .attributeModifier(Store.get().glass('card'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: this.store.safeTop + 20, bottom: this.store.safeBottom + 20 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .backgroundColor(this.store.palette().bg)
  }

  /**
   * Tab row shared by both bar looks. 1.3.0 light-sense look (MimiSSH 1.5.7): no pill behind the selected
   * tab - it only takes the accent colour; idle labels are white on the glass in the dark theme.
   */
  /** 1.3.6: soft halo behind the glass-bar icons / labels so they stay legible over bright content behind the glass */
  labelHalo(): ShadowOptions {
    const d = this.store.isDark();
    return { radius: d ? 6 : 5, color: d ? GLASS_LABEL_SHADOW_DARK : GLASS_LABEL_SHADOW_LIGHT, offsetX: 0, offsetY: d ? 1 : 0 };
  }

  /** Halo for the bar labels, or a zero shadow for the plain bar (method call: @Builder bodies take no statements) */
  barHalo(lightOn: boolean): ShadowOptions {
    if (!lightOn) {
      return { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 };
    }
    return this.labelHalo();
  }

  @Builder
  barTabs(lightOn: boolean) {
    Row() {
      ForEach(this.visPages(), (page: number) => {
        Column() {
          SymbolGlyph(TABS[page].icon).fontSize(22)
            .fontColor([this.visPos(page) === this.selPos() ? this.store.palette().accentUi :
              (lightOn && this.store.isDark() ? GLASS_LABEL_DARK : this.store.palette().text)])
            .symbolShadow(this.barHalo(lightOn))
          Text(this.tabLabel(page))
            .fontSize(11)
            .maxFontSize(11)
            .minFontSize(8)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.visPos(page) === this.selPos() ? this.store.palette().accent :
              (lightOn && this.store.isDark() ? GLASS_LABEL_DARK : this.store.palette().text))
            .fontWeight(this.visPos(page) === this.selPos() ? FontWeight.Bold : FontWeight.Normal)
            .textShadow(this.barHalo(lightOn))
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .borderRadius(34)
        .backgroundColor(this.visPos(page) === this.selPos() && !lightOn ? this.store.palette().accentSoft : Color.Transparent)
        .onClick(() => {
          this.selectTab(this.visPos(page));
        })
      }, (page: number) => 'tab-' + page)
    }
    .width(this.rootW > 0 ? this.rootW - 28 : '100%')
    .height('100%')
    .padding(6)
    .transition(Motion.fade())
  }

  /**
   * Floating bottom bar.
   * 1.1.6 fix for "bar buttons don't respond":
   *  - The bar's outer container is a full-width HitTestMode.Transparent Column over the full-screen page; Transparent lets
   *    touches also hit the page below (List/Scroll drags, card onClick, ...), so tab taps competed with them
   *    and were often swallowed on real devices. The bar now uses HitTestMode.BLOCK_HIERARCHY: touches on it go only to it.
   *  - Removed the outer Stack onClick that competed with the tabs (the round button handles its own tap).
   *  - The sweep layer is no longer an .overlay(); it is the bar's top child with HitTestMode.None.
   * 1.3.0: keyed by the nav bar immersive light switch so toggling it rebuilds the bar (a system material set by a
   * modifier is not reset when the modifier stops setting it - same trick as MimiSSH).
   */
  @Builder
  bottomBar() {
    ForEach([this.store.navLight], (lightOn: boolean) => {
      if (lightOn) {
        this.barLightBody()
      } else {
        this.barPlainBody()
      }
    }, (lightOn: boolean) => 'barlight-' + lightOn)
  }

  /** 1.3.0 light-sense bar: system immersive material / heavy blur surface + refraction rim + hairline rim + tabs */
  @Builder
  barLightBody() {
    Stack({ alignContent: Alignment.Center }) {
      if (NavLightSense.material()) {
        Row()
          .width('100%')
          .height('100%')
          .borderRadius(40)
          .attributeModifier(new BarBackdropMod(this.store.isDark(), this.store.navBarLook(false).fallbackBlurPx))
          .hitTestBehavior(HitTestMode.None)
      }
      Row()
        .width('100%')
        .height('100%')
        .borderRadius(40)
        .attributeModifier(new BarGlassMod(this.store.navBarLook(false)))
      Column() {
        Row()
          .width('100%')
          .height('100%')
          .borderRadius(38.5)
          .attributeModifier(new GlassRimMod(this.store.isDark(), 1))
      }
      .width('100%')
      .height('100%')
      .padding(1.5)
      .hitTestBehavior(HitTestMode.None)
      Row()
        .width('100%')
        .height('100%')
        .borderRadius(40)
        .attributeModifier(new GlassRimMod(this.store.isDark(), 0))
        .hitTestBehavior(HitTestMode.None)
      this.barTabs(true)
      if (this.sweepShow) {
        this.sweepLayer()
      }
    }
    .width(this.rootW > 0 ? this.rootW - 28 : '100%')
    .height(BAR_H)
    .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
    .transition(Motion.fade())
    .onAreaChange((o: Area, n: Area) => {
      this.barWidth = Number(n.width);
    })
  }

  /** Pre-1.3.0 bar (light sense off): Store.glass('bar') surface, collapses into the round button */
  @Builder
  barPlainBody() {
    Stack() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.collapsed()) {
          // Collapsed: round glass button at the bottom left with the current page icon; tap to expand
          Stack() {
            SymbolGlyph(TABS[this.selPage()].icon)
              .fontSize(24)
              .fontColor([this.store.palette().accentUi])
          }
          .width(DOT)
          .height(DOT)
          .onClick(() => {
            this.store.expandNav();
          })
          .transition(Motion.on() ?
            TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.6, y: 0.6 })).animation(Motion.anim()) :
            TransitionEffect.IDENTITY)
        } else {
          this.barTabs(false)
        }

        if (this.sweepShow) {
          this.sweepLayer()
        }
      }
      .width('100%')
      .height('100%')
      .borderRadius(this.collapsed() ? DOT / 2 : 40)
      .clip(true)
    }
    .width(this.collapsed() ? DOT : (this.rootW > 0 ? this.rootW - 28 : '100%'))
    .height(this.collapsed() ? DOT : BAR_H)
    .borderRadius(this.collapsed() ? DOT / 2 : 40)
    .attributeModifier(this.store.glass('bar'))
    .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
    .onAreaChange((o: Area, n: Area) => {
      this.barWidth = Number(n.width);
    })
  }

  /** Backend connection failure banner (floats above the bar) */
  @Builder
  failBanner() {
    Row() {
      SymbolGlyph($r('sys.symbol.exclamationmark')).fontSize(18).fontColor([this.store.palette().bad])
      Text(t('backend_failed_banner', this.store.connError))
        .fontSize(13)
        .fontColor(this.store.palette().bad)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 8 })
      Text(t('retry'))
        .fontSize(14)
        .maxLines(1)
        .fontColor(this.store.palette().text)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .onClick(() => {
          this.store.retry();
        })
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 8 })
    .borderRadius(22)
    .backgroundColor(withAlpha(this.store.isDark() ? '#3A1F22' : '#FDECEC', 0.94))
    .backgroundEffect({ radius: 40 })
    .margin({ bottom: 8 })
    .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
    .transition(Motion.pop())
    .onClick(() => {
      this.store.tab = 5;
      this.store.settingsPage = 'backend';
      this.store.expandNav();
    })
  }

  /** Sweep layer: decoration only, no hit testing */
  @Builder
  sweepLayer() {
    if (this.sweepShow) {
      Stack() {
        Row()
          .width('45%')
          .height('100%')
          .linearGradient({
            angle: 100,
            colors: [['#00FFFFFF', 0],
              [withAlpha('#FFFFFF', (this.store.isDark() ? 0.22 : 0.55) * this.store.lightIntensity), 0.5],
              ['#00FFFFFF', 1]]
          })
          .translate({ x: this.sweepPos * this.barWidth * 0.75 })
      }
      .width('100%')
      .height('100%')
      .borderRadius(40)
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
    }
  }

  /** Everything on screen. Re-created when the UI language changes so every string switches at once. */
  @Builder
  rootContent() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.store.isBlack() ? '#000000' :
          (this.store.wallpaperPath.length > 0 && this.store.backends.length > 0 ? '#000000' :
            (this.store.isDark() ? '#111316' : '#F4F4F6')))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      if (this.store.glassOn && !this.store.isBlack() && (this.store.wallpaperPath.length === 0 || this.store.backends.length === 0)) {
        this.glassBackdrop()
      }
      if (!this.store.privacyAgreed) {
        this.consentScreen()
      } else if (this.store.backends.length === 0) {
        this.setupScreen()
      } else {
        if (this.store.wallpaperPath.length > 0 && !this.store.isBlack()) {
          Image(this.store.wallpaperSrc())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .blur(this.store.wallpaperBlur)
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          if (this.store.wallpaperDim > 0) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0,0,0,' + this.store.wallpaperDim + ')')
              .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          }
        }

        // 1.1.6: Tabs (own tab bar hidden) hold the pages and support swiping; pages keep their state.
        // 1.5.9: the Tabs index is a bar position, Store.tab the page id (see visPages): tapping the
        // bar -> changeIndex animation; swiping -> onChange translates the position back to a page id.
        // Horizontal scrolls (e.g. crash log), sliders etc. inside a page win over the Tabs swipe.
        Tabs({ index: this.visPos(this.store.tab), controller: this.tabsCtl }) {
          TabContent() {
            if (this.store.activeIsHonk()) {
              HonkOverviewView({ bottomPad: this.bottomPad(0) })
            } else {
              OverviewView({ bottomPad: this.bottomPad(0) })
            }
          }

          TabContent() {
            if (this.store.activeIsHonk()) {
              HonkPolicyView({ bottomPad: this.bottomPad(1) })
            } else {
              ProxiesView({ bottomPad: this.bottomPad(1) })
            }
          }

          TabContent() {
            ConnectionsView({ bottomPad: this.bottomPad(2) })
          }

          // 1.5.9: slot 3 exists for clash backends only — honk has no page there any more
          // (its tools page was removed), so the honk bar/Tabs run with five pages
          if (!this.store.activeIsHonk()) {
            TabContent() {
              LogsView({ bottomPad: this.bottomPad(3) })
            }
          }

          TabContent() {
            RulesView({ bottomPad: this.bottomPad(4) })
          }

          TabContent() {
            SettingsView({ bottomPad: this.bottomPad(5) })
          }
        }
        .width('100%')
        .height('100%')
        .barHeight(0)
        .barMode(BarMode.Fixed)
        .scrollable(true)
        .animationDuration(Motion.ms(MOTION_TAB))
        // 1.2.2 (AppGallery self-check): bounce when swiping past the first (Overview) or last (Settings) page
        .edgeEffect(EdgeEffect.Spring)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onAnimationStart((index: number, targetIndex: number, event: TabsAnimationEvent) => {
          if (targetIndex !== index) {
            this.navTarget = targetIndex;
          }
        })
        .onAnimationEnd((index: number, event: TabsAnimationEvent) => {
          if (this.navTarget >= 0 && (this.navTarget !== index || this.store.tab === this.pageAt(index))) {
            this.navTarget = -1;
          }
        })
        .onChange((i: number) => {
          this.onPageChanged(i);
        })

        Column() {
          // 1.3.0: gentle review prompt soft card floats above the bar (non-blocking, see ReviewCard)
          if (this.review.showCard) {
            ReviewCard()
          }
          if (this.store.connState === 'failed' && this.store.tab !== 5) {
            this.failBanner()
          }
          this.bottomBar()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 14, right: 14, bottom: this.navBottom() })
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.store.legalDoc.length > 0) {
        LegalView({
          doc: this.store.legalDoc,
          onClose: () => {
            this.store.legalDoc = '';
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1.2.0: keyed by the UI language; switching language rebuilds the tree (tab/sub-page live in Store and are kept)
      ForEach([I18N.lang], (lang: string) => {
        this.rootContent()
      }, (lang: string) => 'lang_' + lang)
    }
    .width('100%')
    .height('100%')
    // Full-screen immersive: the root fills the whole window (incl. status bar and gesture area); pages pad by the avoid areas
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((o: Area, n: Area) => {
      this.rootW = Number(n.width);
    })
    .bindSheet(this.showCrash, this.crashSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      backgroundColor: this.store.palette().sheet,
      blurStyle: this.store.sheetBlur(),
      onDisappear: () => {
        this.showCrash = false;
      }
    })
  }
}
