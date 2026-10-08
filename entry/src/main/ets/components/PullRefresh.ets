import { Store } from '../common/Store';

/** 下拉多少 vp 松手后触发刷新（也是刷新中内容停留的位置） */
const PULL_OFFSET: number = 64;
/** 刷新指示器尺寸 */
const IND_SIZE: number = 26;
/** 刷新动画至少显示多久，避免一闪而过 */
const MIN_SHOW_MS: number = 400;

/**
 * 页面下拉刷新（1.1.9）：基于 ArkUI Refresh 组件。
 *
 * 页面顶栏 GlassHeader 是叠放在内容之上的毛玻璃层，Refresh 自带的指示器会出现在组件顶部、被顶栏挡住，
 * 所以这里用一个透明的占位 builder 关掉自带指示器，再在顶栏下方（topInset 处）自绘一个主题色的
 * LoadingProgress，位置随下拉距离（onOffsetChange）移动，始终处在顶栏和内容之间的空隙里。
 *
 * 用法（放在页面 Stack 里、GlassHeader 之前）：
 *   PullRefresh({ topInset: this.headerH, page: 'rules' }) { List(...) ... }
 * 列表需设置 .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })，内容不满一屏时也能下拉。
 */
@ComponentV2
export struct PullRefresh {
  private store: Store = Store.get();
  /** 顶栏高度（含状态栏），指示器显示在它下面 */
  @Param topInset: number = 0;
  /** 页面标识，交给 Store.pullRefresh 决定刷新哪些数据 */
  @Param page: string = '';
  @Local refreshing: boolean = false;
  @Local pull: number = 0;

  @Builder
  emptyContent() {
  }

  @BuilderParam content: () => void = this.emptyContent;

  /** 自带指示器的占位：固定 1vp 高、全透明 */
  @Builder
  hiddenIndicator() {
    Column().width('100%').height(1).opacity(0)
  }

  start(): void {
    this.refreshing = true;
    const t0 = Date.now();
    const done = () => {
      const wait = Math.max(0, MIN_SHOW_MS - (Date.now() - t0));
      setTimeout(() => {
        this.refreshing = false;
      }, wait);
    };
    this.store.pullRefresh(this.page).then(done, done);
  }

  indicatorY(): number {
    const p = this.refreshing ? Math.max(this.pull, PULL_OFFSET) : this.pull;
    // 顶栏下沿与内容上沿之间空隙的中间（内容自身还有约 14vp 上边距）
    return this.topInset + (Math.min(p, PULL_OFFSET * 1.6) + 14 - IND_SIZE) / 2;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Refresh({ refreshing: this.refreshing, builder: this.hiddenIndicator() }) {
        this.content()
      }
      .width('100%')
      .height('100%')
      .refreshOffset(PULL_OFFSET)
      .pullToRefresh(true)
      .onOffsetChange((v: number) => {
        this.pull = v;
      })
      .onStateChange((s: RefreshStatus) => {
        if (s === RefreshStatus.Inactive) {
          this.pull = 0;
        }
      })
      .onRefreshing(() => {
        this.start();
      })

      if (this.pull > 1 || this.refreshing) {
        LoadingProgress()
          .width(IND_SIZE)
          .height(IND_SIZE)
          .color(this.store.palette().primary)
          .opacity(this.refreshing ? 1 : Math.min(1, this.pull / PULL_OFFSET))
          .offset({ y: this.indicatorY() })
          .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
  }
}
