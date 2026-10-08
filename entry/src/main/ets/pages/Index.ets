import { Store } from '../common/Store';
import { Backend } from '../common/Models';
import { CrashLog } from '../common/CrashLog';
import { BackendForm } from '../components/BackendForm';
import { OverviewView } from '../views/OverviewView';
import { ProxiesView } from '../views/ProxiesView';
import { ConnectionsView } from '../views/ConnectionsView';
import { LogsView } from '../views/LogsView';
import { RulesView } from '../views/RulesView';
import { SettingsView, CrashDetail } from '../views/SettingsView';
import { mixColor, withAlpha } from '../common/Theme';
import { LegalView } from '../components/LegalView';
import { I18N, t } from '../common/I18n';

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

  /** Highlighted tab: the target page while an animation runs */
  selTab(): number {
    return this.navTarget >= 0 ? this.navTarget : this.store.tab;
  }

  /** Tab tapped: animate to that page (index and Store.tab are synced back through Tabs.onChange) */
  selectTab(i: number): void {
    if (i < 0 || i >= TABS.length) {
      return;
    }
    if (i === this.store.tab && this.navTarget < 0) {
      return;
    }
    this.navTarget = i;
    try {
      this.tabsCtl.changeIndex(i);
    } catch (e) {
      // ignore
    }
    // Fallback: if onChange never fires (e.g. controller not bound yet), write Store.tab; the Tabs index follows
    setTimeout(() => {
      if (this.store.tab !== i && this.navTarget === i) {
        this.store.tab = i;
        this.navTarget = -1;
      }
    }, 650);
  }

  /** Tabs page changed (tap or swipe) */
  onPageChanged(i: number): void {
    this.navTarget = -1;
    if (this.store.tab !== i) {
      this.store.tab = i;
      this.sweep();
    }
    // Swiping to another page expands an auto-hidden bar again
    this.store.expandNav();
  }

  collapsed(): boolean {
    return this.store.autoHideNav && this.store.navCollapsed;
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
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: this.store.isDark() ?
            [['#15171C', 0], [mixColor('#111316', this.store.palette().accent, 0.18), 0.55], ['#0E1013', 1]] :
            [['#F7F8FB', 0], [mixColor('#F4F4F6', this.store.palette().accent, 0.16), 0.55], ['#EEF0F4', 1]]
        })
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [(this.store.lightOn ? 30 + Math.sin(this.store.lightDeg * Math.PI / 180) * 18 : 22) + '%', '18%'],
          radius: '75%',
          colors: [[withAlpha(this.store.palette().accent, this.store.isDark() ? 0.38 : 0.30), 0],
            [withAlpha(this.store.palette().accent, 0), 1]]
        })
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['88%', '72%'],
          radius: '70%',
          colors: [[withAlpha(this.store.palette().up, this.store.isDark() ? 0.30 : 0.26), 0],
            [withAlpha(this.store.palette().up, 0), 1]]
        })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .hitTestBehavior(HitTestMode.Transparent)
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
          .fontColor(this.store.palette().onAccent)
          .backgroundColor(this.store.palette().accent)
          .onClick(() => {
            this.store.agreePrivacy();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 8, bottom: this.store.safeBottom + 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.store.palette().bg)
  }

  @Builder
  consentPoint(t: string) {
    Row() {
      Text('•').fontSize(14).fontColor(this.store.palette().accent).width(14)
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
        SymbolGlyph($r('sys.symbol.paperplane')).fontSize(56).fontColor([this.store.palette().primary])
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
    .backgroundColor(this.store.palette().bg)
  }

  /**
   * Floating bottom bar.
   * 1.1.6 fix for "bar buttons don't respond":
   *  - The bar's outer container is a full-width HitTestMode.Transparent Column over the full-screen page; Transparent lets
   *    touches also hit the page below (List/Scroll drags, card onClick, ...), so tab taps competed with them
   *    and were often swallowed on real devices. The bar now uses HitTestMode.BLOCK_HIERARCHY: touches on it go only to it.
   *  - Removed the outer Stack onClick that competed with the tabs (the round button handles its own tap).
   *  - The sweep layer is no longer an .overlay(); it is the bar's top child with HitTestMode.None.
   */
  @Builder
  bottomBar() {
    Stack() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.collapsed()) {
          // Collapsed: round glass button at the bottom left with the current page icon; tap to expand
          Stack() {
            SymbolGlyph(TABS[Math.min(this.selTab(), TABS.length - 1)].icon)
              .fontSize(24)
              .fontColor([this.store.palette().accent])
          }
          .width(DOT)
          .height(DOT)
          .onClick(() => {
            this.store.expandNav();
          })
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.6, y: 0.6 })))
        } else {
          Row() {
            ForEach(TABS, (tab: TabDef, i: number) => {
              Column() {
                SymbolGlyph(tab.icon).fontSize(22)
                  .fontColor([i === this.selTab() ? this.store.palette().accent : this.store.palette().text])
                Text(t(tab.title))
                  .fontSize(11)
                  .maxFontSize(11)
                  .minFontSize(8)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .fontColor(i === this.selTab() ? this.store.palette().accent : this.store.palette().text)
                  .fontWeight(i === this.selTab() ? FontWeight.Bold : FontWeight.Normal)
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(34)
              .backgroundColor(i === this.selTab() ? this.store.palette().accentSoft : Color.Transparent)
              .onClick(() => {
                this.selectTab(i);
              })
            }, (tab: TabDef) => tab.title)
          }
          .width(this.rootW > 0 ? this.rootW - 28 : '100%')
          .height('100%')
          .padding(6)
          .transition(TransitionEffect.OPACITY)
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
        .backgroundColor(this.store.wallpaperPath.length > 0 && this.store.backends.length > 0 ? '#000000' :
          (this.store.isDark() ? '#111316' : '#F4F4F6'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      if (this.store.glassOn && (this.store.wallpaperPath.length === 0 || this.store.backends.length === 0)) {
        this.glassBackdrop()
      }
      if (!this.store.privacyAgreed) {
        this.consentScreen()
      } else if (this.store.backends.length === 0) {
        this.setupScreen()
      } else {
        if (this.store.wallpaperPath.length > 0) {
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

        // 1.1.6: Tabs (own tab bar hidden) hold the six pages and support swiping; pages keep their state,
        // index <-> Store.tab: tapping the bar -> changeIndex animation; swiping -> onChange writes Store.tab.
        // Horizontal scrolls (e.g. crash log), sliders etc. inside a page win over the Tabs swipe.
        Tabs({ index: this.store.tab, controller: this.tabsCtl }) {
          TabContent() {
            OverviewView({ bottomPad: this.bottomPad(0) })
          }

          TabContent() {
            ProxiesView({ bottomPad: this.bottomPad(1) })
          }

          TabContent() {
            ConnectionsView({ bottomPad: this.bottomPad(2) })
          }

          TabContent() {
            LogsView({ bottomPad: this.bottomPad(3) })
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
        .animationDuration(300)
        .edgeEffect(EdgeEffect.None)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onAnimationStart((index: number, targetIndex: number, event: TabsAnimationEvent) => {
          if (targetIndex !== index) {
            this.navTarget = targetIndex;
          }
        })
        .onAnimationEnd((index: number, event: TabsAnimationEvent) => {
          if (this.navTarget >= 0 && (this.navTarget !== index || this.store.tab === index)) {
            this.navTarget = -1;
          }
        })
        .onChange((i: number) => {
          this.onPageChanged(i);
        })

        Column() {
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
      backgroundColor: this.store.palette().card,
      blurStyle: this.store.sheetBlur(),
      onDisappear: () => {
        this.showCrash = false;
      }
    })
  }
}
