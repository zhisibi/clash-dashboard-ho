import { Store } from '../common/Store';
import { AGREEMENT_LINES, PRIVACY_LINES } from '../common/Legal';

/** 隐私政策 / 用户协议全文页（doc: 'privacy' | 'agreement'），覆盖在当前界面之上 */
@ComponentV2
export struct LegalView {
  private store: Store = Store.get();
  @Param doc: string = 'privacy';
  @Event onClose: () => void = () => {
  };

  lines(): string[] {
    return this.doc === 'agreement' ? AGREEMENT_LINES : PRIVACY_LINES;
  }

  title(): string {
    return this.doc === 'agreement' ? '用户协议' : '隐私政策';
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([this.store.palette().text])
          .padding({ left: 2, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.onClose();
          })
        Text(this.title()).fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: this.store.safeTop + 8, bottom: 8 })

      Scroll() {
        Column() {
          ForEach(this.lines(), (l: string, i: number) => {
            if (l.startsWith('# ')) {
              Text(l.substring(2))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.store.palette().text)
                .margin({ bottom: 6 })
            } else if (l.startsWith('## ')) {
              Text(l.substring(3))
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.store.palette().text)
                .margin({ top: 10, bottom: 4 })
            } else if (l.startsWith('- ')) {
              Row() {
                Text('•').fontSize(14).fontColor(this.store.palette().subtle).width(14)
                Text(l.substring(2))
                  .fontSize(14)
                  .lineHeight(22)
                  .fontColor(this.store.palette().text)
                  .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .margin({ top: 2, bottom: 2 })
            } else if (l.length === 0) {
              Blank().height(6)
            } else {
              Text(l)
                .fontSize(14)
                .lineHeight(22)
                .fontColor(this.store.palette().text)
                .width('100%')
            }
          }, (l: string, i: number) => i + ':' + l)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 4, bottom: this.store.safeBottom + 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.store.palette().bg)
  }
}
