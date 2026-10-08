import { Store } from '../common/Store';
import { mixColor, withAlpha } from '../common/Theme';

/** 1.2.3: scrim alpha (page color) over a wallpaper behind text-only overlay pages such as the legal docs */
export const OVERLAY_SCRIM: number = 0.92;

/** Soft accent gradient drawn behind glass pages when there is no wallpaper (was Index.glassBackdrop) */
@ComponentV2
export struct GlassGradient {
  private store: Store = Store.get();

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: this.store.isDark() ?
            [['#15171C', 0], [mixColor('#111316', this.store.palette().accentFill, 0.18), 0.55], ['#0E1013', 1]] :
            [['#F7F8FB', 0], [mixColor('#F4F4F6', this.store.palette().accentFill, 0.16), 0.55], ['#EEF0F4', 1]]
        })
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [(this.store.lightOn ? 30 + Math.sin(this.store.lightDeg * Math.PI / 180) * 18 : 22) + '%', '18%'],
          radius: '75%',
          colors: [[withAlpha(this.store.palette().accentFill, this.store.isDark() ? 0.38 : 0.30), 0],
            [withAlpha(this.store.palette().accentFill, 0), 1]]
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
}

/**
 * 1.2.3: full-screen background for pages drawn ON TOP of another page (legal docs, ...).
 * palette().bg is transparent when glass or a wallpaper is on, so such a page used to show the page and the
 * bottom bar beneath through its text. This always starts with an opaque page-color base; the glass gradient,
 * or a strongly blurred wallpaper under a page-color scrim, only goes on top of that base.
 */
@ComponentV2
export struct PageBackdrop {
  private store: Store = Store.get();

  hasWallpaper(): boolean {
    return this.store.wallpaperPath.length > 0 && this.store.backends.length > 0;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.store.solidBg())
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      if (this.hasWallpaper()) {
        Image(this.store.wallpaperSrc())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(Math.max(40, this.store.wallpaperBlur))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(withAlpha(this.store.solidBg(), OVERLAY_SCRIM))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      } else if (this.store.glassOn) {
        GlassGradient()
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
