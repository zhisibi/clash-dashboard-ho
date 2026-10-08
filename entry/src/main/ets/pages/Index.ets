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

class TabDef {
  title: string = '';
  icon: Resource;

  constructor(title: string, icon: Resource) {
    this.title = title;
    this.icon = icon;
  }
}

const TABS: TabDef[] = [
  new TabDef('概览', $r('sys.symbol.house')),
  new TabDef('代理', $r('sys.symbol.paperplane')),
  new TabDef('连接', $r('sys.symbol.arrow_left_arrow_right')),
  new TabDef('日志', $r('sys.symbol.doc_text')),
  new TabDef('规则', $r('sys.symbol.list_bullet')),
  new TabDef('设置', $r('sys.symbol.gearshape'))
];

/** 展开状态的底栏高度 */
const BAR_H: number = 64;
/** 收起后圆形按钮的直径 */
const DOT: number = 56;

@Entry
@ComponentV2
struct Index {
  private store: Store = Store.get();
  @Local showCrash: boolean = false;
  @Local crashName: string = '';
  /** 流光扫过：-1 在左侧外，1 在右侧外 */
  @Local sweepPos: number = -1;
  @Local sweepShow: boolean = false;
  @Local barWidth: number = 360;
  /** 根布局宽度，用于底栏 展开 ↔ 圆形按钮 的宽度形变动画 */
  @Local rootW: number = 0;
  /** 页面切换动画进行中的目标页（-1 表示没有动画），让底栏高亮在动画开始时就跟上 */
  @Local navTarget: number = -1;
  private tabsCtl: TabsController = new TabsController();

  aboutToAppear(): void {
    if (this.store.crashPrompt) {
      setTimeout(() => {
        this.promptCrash();
      }, 600);
    }
  }

  /** 底栏距离屏幕底边：贴近手势指示条，留出约 8vp 的间隙 */
  navBottom(): number {
    const b = this.store.safeBottom;
    return b > 0 ? Math.max(8, b - 6) : 10;
  }

  /** 各页面滚动内容底部留白：让最后一项可以滚到底栏上方（第 i 页） */
  bottomPad(i: number): number {
    return this.navBottom() + BAR_H + 16 + (this.store.connState === 'failed' && i !== 5 ? 52 : 0);
  }

  /** 底栏当前高亮的页：切换动画进行中时取目标页 */
  selTab(): number {
    return this.navTarget >= 0 ? this.navTarget : this.store.tab;
  }

  /** 点击底栏页签：动画切换到该页（index 与 Store.tab 由 Tabs.onChange 回写，双向同步） */
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
    // 兜底：万一 onChange 没有回调（例如控制器尚未绑定），直接写入 Store.tab，Tabs 的 index 参数会跟随
    setTimeout(() => {
      if (this.store.tab !== i && this.navTarget === i) {
        this.store.tab = i;
        this.navTarget = -1;
      }
    }, 650);
  }

  /** Tabs 页面已切换（点击或左右滑动） */
  onPageChanged(i: number): void {
    this.navTarget = -1;
    if (this.store.tab !== i) {
      this.store.tab = i;
      this.sweep();
    }
    // 滑动切页时，自动收起的底栏重新展开
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

  /** 底栏流光扫过一次（一次性动画，结束后移除图层，不常驻刷新） */
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

  /** 毛玻璃开启且没有壁纸时，绘制一层柔和的主题色渐变背景，让玻璃的模糊与光感可见 */
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
      title: '上次运行发生了闪退',
      message: '已自动保存错误日志。可以查看后复制或分享给开发者。',
      autoCancel: true,
      primaryButton: {
        value: '忽略',
        action: () => {
          CrashLog.markSeen();
          this.store.crashPrompt = false;
        }
      },
      secondaryButton: {
        value: '查看日志',
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

  /** 首次启动：同意隐私政策与用户协议之前不发起任何网络请求；不同意则退出 */
  @Builder
  consentScreen() {
    Column() {
      Scroll() {
        Column() {
          Image($r('app.media.layered_image')).width(72).height(72).borderRadius(18)
          Text('欢迎使用咪咪面板')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.store.palette().text)
            .margin({ top: 16 })
          Text('咪咪面板用于管理你自行部署、与 mihomo 兼容的代理内核的外部控制器（external-controller）。本应用不包含代理内核，也不提供代理服务。')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(this.store.palette().subtle)
            .margin({ top: 10 })
          Column() {
            this.consentPoint('无账号、不收集个人信息、不含第三方 SDK')
            this.consentPoint('后端地址、密钥与设置只保存在本机')
            this.consentPoint('网络请求只发往你自己配置的后端')
            this.consentPoint('闪退日志只保存在本机，仅在你点击分享/复制/另存为时导出')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 16 })
          .padding(16)
          .borderRadius(16)
          .backgroundColor(this.store.palette().chip)

          Text() {
            Span('请阅读并同意')
            Span('《隐私政策》')
              .fontColor(this.store.palette().accent)
              .onClick(() => {
                this.store.legalDoc = 'privacy';
              })
            Span('和')
            Span('《用户协议》')
              .fontColor(this.store.palette().accent)
              .onClick(() => {
                this.store.legalDoc = 'agreement';
              })
            Span('。点击“同意”即表示你已阅读并同意上述内容；点击“不同意”将退出应用。')
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
        Button('不同意', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontColor(this.store.palette().text)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            this.store.declinePrivacy();
          })
        Blank().width(12)
        Button('同意', { type: ButtonType.Capsule })
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
        Text('连接后端')
          .fontSize(26)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().text)
          .margin({ top: 16 })
        Text('填写 external-controller 的地址与密钥。本机内核一般是 127.0.0.1:9090。')
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
   * 悬浮底栏。
   * 1.1.6 修复“底栏按钮点不动”：
   *  - 底栏外层容器是全宽、HitTestMode.Transparent 的 Column，叠在全屏页面之上；Transparent 会让触摸同时
   *    命中下方的页面（List/Scroll 的拖动手势、卡片的 onClick 等），页签的点击要和它们一起参与手势竞争，
   *    在真机上经常被下层吞掉。现在底栏本体使用 HitTestMode.BLOCK_HIERARCHY：落在底栏上的触摸只交给底栏。
   *  - 去掉外层 Stack 上与页签 onClick 嵌套竞争的 onClick（收起的圆形按钮自己处理点击）。
   *  - 流光层不再用 .overlay() 叠在底栏上，而是作为底栏内部的最上层子节点并设为 HitTestMode.None。
   */
  @Builder
  bottomBar() {
    Stack() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.collapsed()) {
          // 收起：左下角的圆形玻璃按钮，显示当前页图标，点击展开
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
            ForEach(TABS, (t: TabDef, i: number) => {
              Column() {
                SymbolGlyph(t.icon).fontSize(22)
                  .fontColor([i === this.selTab() ? this.store.palette().accent : this.store.palette().text])
                Text(t.title)
                  .fontSize(11)
                  .maxLines(1)
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
            }, (t: TabDef) => t.title)
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

  /** 后端连接失败的提示条（悬浮在底栏上方） */
  @Builder
  failBanner() {
    Row() {
      SymbolGlyph($r('sys.symbol.exclamationmark')).fontSize(18).fontColor([this.store.palette().bad])
      Text('后端连接失败：' + this.store.connError)
        .fontSize(13)
        .fontColor(this.store.palette().bad)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 8 })
      Text('重试')
        .fontSize(14)
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

  /** 流光层：纯装饰，不参与触摸测试 */
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

  build() {
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

        // 1.1.6：Tabs（隐藏自带页签栏）承载六个页面，支持左右滑动切页；页面切换后保留状态（不重建），
        // index 与 Store.tab 双向同步：点底栏 → changeIndex 动画切页；滑动 → onChange 回写 Store.tab。
        // 页面内的横向滚动（如闪退日志）、滑块等子组件的手势优先于 Tabs 的翻页手势。
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
    // 全屏沉浸：根布局铺满整个窗口（含状态栏与底部手势指示条区域），各页面自行按避让区高度留白
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
