import { Store } from '../common/Store';

/**
 * Page header (frosted): overlays the scrolling content and extends under the status bar.
 * Content scrolls underneath and is blurred; pages pad their content by the header height (incl. status bar),
 * which is reported through onHeight.
 *
 * Usage:
 *   Stack({ alignContent: Alignment.Top }) {
 *     List(...).padding({ top: this.headerH + 14 }).clipContent(ContentClipMode.BOUNDARY)
 *     GlassHeader({ onHeight: (h: number) => { this.headerH = h; } }) { ...header content... }
 *   }
 */
@ComponentV2
export struct GlassHeader {
  private store: Store = Store.get();
  /** Horizontal padding of the header content */
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
      // 1.1.6: compact header (about half the old height), still under the status bar
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

/** Initial header height guess (the real value comes from onAreaChange) */
export function headerGuess(rows: number): number {
  return Store.get().safeTop + 10 + rows * 34 + (rows - 1) * 6;
}
