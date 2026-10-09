import { Store } from '../common/Store';
import { agreementLines, privacyLines } from '../common/Legal';
import { t } from '../common/I18n';
import { PageBackdrop } from './PageBackdrop';

/** Full privacy policy / user agreement page (doc: 'privacy' | 'agreement'), shown over the current screen */
@ComponentV2
export struct LegalView {
  private store: Store = Store.get();
  @Param doc: string = 'privacy';
  @Event onClose: () => void = () => {
  };

  lines(): string[] {
    return this.doc === 'agreement' ? agreementLines() : privacyLines();
  }

  title(): string {
    return this.doc === 'agreement' ? t('user_agreement') : t('privacy_policy');
  }

  build() {
    // 1.2.3: the page sits on top of Settings > About (or the consent screen) and the bottom bar; with glass or a
    // wallpaper palette().bg is transparent, so it now draws its own opaque backdrop and blocks touches beneath.
    // 1.2.4: was HitTestMode.Block, which also blocked its own children, so the text could not scroll and the back
    // button did nothing; BLOCK_HIERARCHY lets the page and its children respond and stops everything beneath
    Stack({ alignContent: Alignment.Top }) {
      PageBackdrop()
    Column() {
      Row() {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([this.store.palette().text])
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .accessibilityText(t('back'))
        .onClick(() => {
          this.onClose();
        })
        Text(this.title())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 2 })
      }
      .width('100%')
      .padding({ left: 4, right: 14, top: this.store.safeTop + 2, bottom: 2 })

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
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
  }
}
