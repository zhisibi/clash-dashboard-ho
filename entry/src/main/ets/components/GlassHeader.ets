import { Store } from '../common/Store';

/**
 * 页面顶栏（毛玻璃）：叠放在滚动内容之上，延伸到状态栏下方。
 * 内容从顶栏下面滚过并被模糊；页面需要给滚动内容留出 顶栏高度（含状态栏）的上边距，
 * 高度通过 onHeight 回传。
 *
 * 用法：
 *   Stack({ alignContent: Alignment.Top }) {
 *     List(...).padding({ top: this.headerH + 14 }).clipContent(ContentClipMode.BOUNDARY)
 *     GlassHeader({ onHeight: (h: number) => { this.headerH = h; } }) { ...顶栏内容... }
 *   }
 */
@ComponentV2
export struct GlassHeader {
  private store: Store = Store.get();
  /** 顶栏内容的左右内边距 */
  @Param hPad: number = 12;
  @Event onHeight: (h: number) => void = (h: number) => {
  };

  @Builder
  emptyContent() {
  }

  @BuilderParam content: () => void = this.emptyContent;

  build() {
    Column() {
      Column() {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      // 1.1.6：顶栏收窄为紧凑样式（约为原来一半高），仍延伸到状态栏下方
      .padding({ left: this.hPad, right: this.hPad, top: this.store.safeTop + 4, bottom: 5 })

      Divider().color(this.store.palette().outlineVariant)
    }
    .width('100%')
    .attributeModifier(this.store.glass('top'))
    .onAreaChange((o: Area, n: Area) => {
      const h = Math.round(Number(n.height));
      if (h > 0) {
        this.onHeight(h);
      }
    })
  }
}

/** 页面顶栏的初始高度估计（真实值由 onAreaChange 回传） */
export function headerGuess(rows: number): number {
  return Store.get().safeTop + 10 + rows * 34 + (rows - 1) * 6;
}
