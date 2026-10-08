import { Store } from '../common/Store';

/** Pull distance (vp) that triggers a refresh on release (also where content rests while refreshing) */
const PULL_OFFSET: number = 64;
/** Refresh indicator size */
const IND_SIZE: number = 26;
/** Minimum time the indicator stays visible, so it doesn't just flash */
const MIN_SHOW_MS: number = 400;

/**
 * Pull to refresh (1.1.9), based on the ArkUI Refresh component.
 *
 * GlassHeader overlays the content, so Refresh's own indicator would sit at the top hidden behind it;
 * a transparent placeholder builder disables it, and an accent-colored LoadingProgress is drawn below
 * the header (at topInset), following the pull distance (onOffsetChange) in the gap between header and content.
 *
 * Usage (inside the page Stack, before GlassHeader):
 *   PullRefresh({ topInset: this.headerH, page: 'rules' }) { List(...) ... }
 * Lists need .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) so short content can still be pulled.
 */
@ComponentV2
export struct PullRefresh {
  private store: Store = Store.get();
  /** Header height (incl. status bar); the indicator shows below it */
  @Param topInset: number = 0;
  /** Page id; Store.pullRefresh decides what to reload */
  @Param page: string = '';
  @Local refreshing: boolean = false;
  @Local pull: number = 0;

  @Builder
  emptyContent() {
  }

  @BuilderParam content: () => void = this.emptyContent;

  /** Placeholder for the built-in indicator: 1 vp tall, fully transparent */
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
    // Middle of the gap between header bottom and content top (content has ~14 vp top padding)
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
          .color(this.store.palette().accentUi)
          .opacity(this.refreshing ? 1 : Math.min(1, this.pull / PULL_OFFSET))
          .offset({ y: this.indicatorY() })
          .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
  }
}
