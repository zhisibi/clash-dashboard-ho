import { Store } from '../common/Store';
/** Shared UI components (Kotlin ui/Common.kt) */
import { Palette } from '../common/Theme';
import { t } from '../common/I18n';

export function rgba(hex: string, alpha: number): string {
  let h = hex.startsWith('#') ? hex.substring(1) : hex;
  if (h.length === 8) {
    h = h.substring(2);
  }
  const r = parseInt(h.substring(0, 2), 16);
  const g = parseInt(h.substring(2, 4), 16);
  const b = parseInt(h.substring(4, 6), 16);
  return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
}

export function latencyColor(p: Palette, delay: number, low: number, medium: number): string {
  if (delay <= 0) {
    return p.subtle;
  }
  if (delay <= low) {
    return p.good;
  }
  if (delay <= medium) {
    return p.warn;
  }
  return p.bad;
}

@ComponentV2
export struct LatencyBadge {
  @Param pal: Palette = new Palette();
  @Param delay: number = 0;
  @Param low: number = 400;
  @Param medium: number = 800;
  @Param testing: boolean = false;
  @Event onTap: () => void = () => {
  };

  build() {
    Row() {
      if (this.testing) {
        LoadingProgress().width(16).height(16).color(this.pal.subtle)
      } else {
        Text(this.delay > 0 ? this.delay.toString() : (this.delay === 0 ? '-' : t('timeout')))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(latencyColor(this.pal, this.delay, this.low, this.medium))
      }
    }
    .constraintSize({ minWidth: 40 })
    .height(24)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 10, right: 10 })
    .borderRadius(12)
    .backgroundColor(this.pal.chip)
    .onClick(() => {
      this.onTap();
    })
  }
}

@ComponentV2
export struct SearchBox {
  @Param pal: Palette = new Palette();
  @Param value: string = '';
  @Param placeholder: string = '';
  /** Compact size (for headers) */
  @Param dense: boolean = false;
  @Event onChange: (v: string) => void = (v: string) => {
  };

  build() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(this.dense ? 16 : 18).fontColor([this.pal.subtle])
      TextInput({ text: this.value, placeholder: this.placeholder })
        .layoutWeight(1)
        .height(this.dense ? 32 : 40)
        .fontSize(this.dense ? 14 : 15)
        .fontColor(this.pal.text)
        .placeholderColor(this.pal.subtle)
        .caretColor(this.pal.accent)
        .backgroundColor(Color.Transparent)
        .padding({ left: 8, right: 4 })
        .onChange((v: string) => {
          this.onChange(v);
        })
      if (this.value.length > 0) {
        SymbolGlyph($r('sys.symbol.xmark')).fontSize(16).fontColor([this.pal.subtle])
          .onClick(() => {
            this.onChange('');
          })
      }
    }
    .height(this.dense ? 34 : 44)
    .padding({ left: this.dense ? 10 : 12, right: this.dense ? 10 : 12 })
    .borderRadius(this.dense ? 12 : 14)
    .attributeModifier(Store.get().glass('plain'))
    .border({ width: 1, color: this.pal.outlineVariant, radius: this.dense ? 12 : 14 })
  }
}

@ComponentV2
export struct RoundIconButton {
  @Param pal: Palette = new Palette();
  @Param icon: Resource = $r('sys.symbol.gearshape');
  @Param active: boolean = false;
  @Param tint: string = '';
  /** Compact size (for headers) */
  @Param dense: boolean = false;
  @Event onTap: () => void = () => {
  };

  build() {
    Stack() {
      SymbolGlyph(this.icon)
        .fontSize(this.dense ? 17 : 20)
        .fontColor([this.tint.length > 0 ? this.tint : (this.active ? this.pal.onPrimary : this.pal.text)])
    }
    .width(this.dense ? 34 : 44)
    .height(this.dense ? 34 : 44)
    .borderRadius(this.dense ? 17 : 22)
    .backgroundColor(this.active ? this.pal.primary : this.pal.chip)
    .onClick(() => {
      this.onTap();
    })
  }
}

/**
 * 1.2.3: icon button for sheet headers. 48 vp touch target around a 40 vp chip circle. Sheets that put buttons on
 * the right of their header hide the system close (showClose: false) and draw SheetHeaderButton(xmark) instead, because
 * the system close sits over the header's top-right corner.
 */
@ComponentV2
export struct SheetHeaderButton {
  @Param pal: Palette = new Palette();
  @Param icon: Resource = $r('sys.symbol.xmark');
  @Param active: boolean = false;
  @Param label: string = '';
  @Event onTap: () => void = () => {
  };

  build() {
    Stack() {
      Stack() {
        SymbolGlyph(this.icon)
          .fontSize(19)
          .fontColor([this.active ? this.pal.onPrimary : this.pal.text])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.active ? this.pal.primary : this.pal.chip)
    }
    .width(48)
    .height(48)
    .accessibilityText(this.label)
    .onClick(() => {
      this.onTap();
    })
  }
}

@ComponentV2
export struct SegTabs {
  @Param pal: Palette = new Palette();
  @Param items: string[] = [];
  @Param selected: number = 0;
  /** Compact size (for headers) */
  @Param dense: boolean = false;
  @Event onSelect: (i: number) => void = (i: number) => {
  };

  build() {
    Row() {
      ForEach(this.items, (s: string, i: number) => {
        Text(s)
          .fontSize(this.dense ? 13 : 15)
          .maxLines(1)
          .fontColor(i === this.selected ? this.pal.onPrimary : this.pal.subtle)
          .padding({
            left: this.dense ? 11 : 14, right: this.dense ? 11 : 14,
            top: this.dense ? 5 : 7, bottom: this.dense ? 5 : 7
          })
          .borderRadius(this.dense ? 9 : 11)
          .backgroundColor(i === this.selected ? this.pal.primary : Color.Transparent)
          .onClick(() => {
            this.onSelect(i);
          })
      }, (s: string, i: number) => i + '_' + s)
    }
    .padding(this.dense ? 3 : 4)
    .borderRadius(this.dense ? 12 : 14)
    .backgroundColor(this.pal.chip)
  }
}

@ComponentV2
export struct DropdownChip {
  @Param pal: Palette = new Palette();
  @Param label: string = '';
  @Param options: string[] = [];
  @Param chipWidth: Length = 'auto';
  /** Compact size (for headers) */
  @Param dense: boolean = false;
  @Event onSelect: (i: number) => void = (i: number) => {
  };

  menu(): MenuElement[] {
    const out: MenuElement[] = [];
    for (let i = 0; i < this.options.length; i++) {
      const idx = i;
      const el: MenuElement = {
        value: this.options[i],
        action: () => {
          this.onSelect(idx);
        }
      };
      out.push(el);
    }
    return out;
  }

  build() {
    Row() {
      Text(this.label)
        .fontSize(this.dense ? 14 : 15)
        .maxLines(1)
        .fontColor(this.pal.text)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(1)
      SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(this.dense ? 12 : 14).fontColor([this.pal.subtle])
        .margin({ left: this.dense ? 4 : 6 })
    }
    .width(this.chipWidth)
    .height(this.dense ? 34 : 44)
    .padding({ left: this.dense ? 10 : 14, right: this.dense ? 8 : 12 })
    .justifyContent(FlexAlign.SpaceBetween)
    .borderRadius(this.dense ? 12 : 14)
    .attributeModifier(Store.get().glass('plain'))
    .border({ width: 1, color: this.pal.outlineVariant, radius: this.dense ? 12 : 14 })
    .bindMenu(this.menu())
  }
}

@ComponentV2
export struct Tag {
  @Param pal: Palette = new Palette();
  @Param text: string = '';
  @Param color: string = '';

  build() {
    Text(this.text)
      .fontSize(11)
      .maxLines(1)
      // 1.2.3: ends in an ellipsis when the caller lets it shrink (.flexShrink(1)) in a Row that is too narrow
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .fontColor(this.color.length > 0 ? this.color : this.pal.subtle)
      .padding({ left: 6, right: 6, top: 1, bottom: 1 })
      .borderRadius(6)
      .backgroundColor(this.pal.chip)
  }
}

@ComponentV2
export struct SectionTitle {
  @Param pal: Palette = new Palette();
  @Param text: string = '';

  build() {
    Text(this.text)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.pal.subtle)
      .padding({ left: 6, top: 18, bottom: 8 })
      .width('100%')
  }
}

@ComponentV2
export struct EmptyCard {
  @Param pal: Palette = new Palette();
  @Param text: string = '';

  build() {
    Column() {
      Text(this.text).fontSize(16).fontColor(this.pal.text)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .borderRadius(18)
    .attributeModifier(Store.get().glass('card'))
  }
}

@ComponentV2
export struct ProxyIcon {
  @Param url: string = '';
  @Param iconSize: number = 18;

  build() {
    if (this.url.length > 0) {
      Image(this.url)
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Contain)
        .margin({ right: 4 })
    }
  }
}

/** Page title row: title | status dot + backend address */
@ComponentV2
export struct HeaderStatus {
  @Param pal: Palette = new Palette();
  @Param title: string = '';
  @Param connState: string = 'idle';
  @Param address: string = '';
  @Param tag: string = '';

  dotColor(): string {
    if (this.connState === 'connected') {
      return this.pal.good;
    }
    if (this.connState === 'connecting') {
      return this.pal.warn;
    }
    if (this.connState === 'failed') {
      return this.pal.bad;
    }
    return this.pal.subtle;
  }

  build() {
    Row() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.pal.text)
      Divider().vertical(true).height(16).color(this.pal.outline).margin({ left: 10, right: 10 })
      Row().width(8).height(8).borderRadius(4).backgroundColor(this.dotColor())
      Text(this.address)
        .fontSize(13)
        .fontColor(this.pal.subtle)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 8 })
      if (this.tag.length > 0) {
        Tag({ pal: this.pal, text: this.tag })
      }
    }
    .width('100%')
    .height(30)
    .alignItems(VerticalAlign.Center)
  }
}

/** Line chart (Kotlin LineChart): smooth Canvas curves + gradient fill */
@ComponentV2
export struct LineChart {
  @Param series: number[][] = [];
  @Param colors: string[] = [];
  @Param grid: string = '#E8EAED';
  @Param chartHeight: number = 160;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private c2d: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  @Monitor('series', 'colors', 'grid')
  onData(): void {
    this.draw();
  }

  draw(): void {
    if (!this.ready) {
      return;
    }
    const ctx = this.c2d;
    const w = ctx.width;
    const h = ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    ctx.clearRect(0, 0, w, h);
    let max = 1;
    for (const s of this.series) {
      for (const v of s) {
        if (v > max) {
          max = v;
        }
      }
    }
    max = max * 1.15;
    ctx.strokeStyle = this.grid;
    ctx.lineWidth = 1;
    for (let i = 1; i <= 3; i++) {
      const y = h * i / 4;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }
    for (let si = 0; si < this.series.length; si++) {
      const data = this.series[si];
      const color = si < this.colors.length ? this.colors[si] : '#16A6E8';
      if (data.length < 2) {
        continue;
      }
      const step = w / (data.length - 1);
      const path = new Path2D();
      for (let i = 0; i < data.length; i++) {
        const x = i * step;
        const y = h - (data[i] / max) * h;
        if (i === 0) {
          path.moveTo(x, y);
        } else {
          const px = (i - 1) * step;
          const py = h - (data[i - 1] / max) * h;
          const cx = (px + x) / 2;
          path.bezierCurveTo(cx, py, cx, y, x, y);
        }
      }
      const fill = new Path2D();
      fill.addPath(path);
      fill.lineTo(w, h);
      fill.lineTo(0, h);
      fill.closePath();
      const grad = ctx.createLinearGradient(0, 0, 0, h);
      grad.addColorStop(0, rgba(color, 0.25));
      grad.addColorStop(1, rgba(color, 0));
      ctx.fillStyle = grad;
      ctx.fill(fill);
      ctx.strokeStyle = color;
      ctx.lineWidth = 2.5;
      ctx.lineCap = 'round';
      ctx.stroke(path);
    }
  }

  build() {
    Canvas(this.c2d)
      .width('100%')
      .height(this.chartHeight)
      .onReady(() => {
        this.ready = true;
        this.draw();
      })
      .onAreaChange(() => {
        this.draw();
      })
  }
}

@ComponentV2
export struct Legend {
  @Param pal: Palette = new Palette();
  @Param color: string = '#000000';
  @Param label: string = '';

  build() {
    Row() {
      Row().width(8).height(8).borderRadius(4.0).backgroundColor(this.color)
      Text(this.label).fontSize(12).fontColor(this.pal.subtle).margin({ left: 4 })
    }
    .margin({ right: 14 })
  }
}
