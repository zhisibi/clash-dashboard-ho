/**
 * Shared service-widget card UI (1.4.0): a gradient card tinted by the app's current accent.
 * All texts arrive pre-formatted from the app snapshot (WidgetSync.ets); the card does no
 * network work. Tapping the card opens the app, which also refreshes the snapshot it shows.
 */
@Component
export struct WidgetBody {
  @Prop brand: string = 'Mimi Panel';
  @Prop connected: boolean = false;
  @Prop statusText: string = 'Not connected';
  @Prop labelText: string = '';
  @Prop upText: string = '0 B/s';
  @Prop downText: string = '0 B/s';
  @Prop connText: string = '0';
  @Prop memText: string = '-';
  @Prop totalText: string = '';
  @Prop modeText: string = '';
  @Prop nodeText: string = '';
  @Prop egressText: string = '';
  @Prop egressIp: string = '';
  @Prop hasEgress: boolean = false;
  @Prop updatedText: string = '';
  @Prop bgA: string = '#0A59F7';
  @Prop bgB: string = '#0646C8';
  @Prop compact: boolean = false;

  private openApp(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { target: 'overview' }
    });
  }

  @Builder
  chip(icon: Resource, text: string) {
    Row() {
      SymbolGlyph(icon).fontSize(11).fontColor(['#E6FFFFFF'])
      Text(text).fontSize(11).fontColor('#E6FFFFFF').margin({ left: 4 })
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
    .borderRadius(10)
    .backgroundColor('#26FFFFFF')
    .margin({ right: 6 })
    .constraintSize({ maxWidth: '62%' })
  }

  build() {
    Stack() {
      // gradient backdrop + two soft light blobs
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [[this.bgA, 0.0], [this.bgB, 1.0]]
        })
      Circle().width(170).height(170).fill('#FFFFFF').opacity(0.10)
        .position({ x: '62%', y: '-38%' })
      Circle().width(110).height(110).fill('#FFFFFF').opacity(0.07)
        .position({ x: '-12%', y: '58%' })

      Column() {
        // header: brand, backend label, status, refresh
        Row() {
          Circle().width(8).height(8).fill(this.connected ? '#4ADE80' : '#B8BDC4')
          Text(this.brand).fontSize(this.compact ? 13 : 15).fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF').margin({ left: 6 })
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.labelText.length > 0) {
            Text(this.labelText).fontSize(11).fontColor('#BFFFFFFF').margin({ left: 6 })
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          } else {
            Blank().layoutWeight(1)
          }
          Text(this.statusText).fontSize(11).fontColor('#D9FFFFFF')
            .maxLines(1)
        }
        .width('100%')

        if (this.compact) {
          // 2x2: big download, then up / connections / egress stacked tight
          Row() {
            SymbolGlyph($r('sys.symbol.arrow_down')).fontSize(16).fontColor(['#FFFFFF'])
            Text(this.downText).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .margin({ left: 4 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .margin({ top: 8 })

          Row() {
            SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(12).fontColor(['#D9FFFFFF'])
            Text(this.upText).fontSize(12).fontColor('#D9FFFFFF').margin({ left: 3 })
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.link')).fontSize(12).fontColor(['#D9FFFFFF'])
              .margin({ left: 10 })
            Text(this.connText).fontSize(12).fontColor('#D9FFFFFF').margin({ left: 3 })
          }
          .margin({ top: 4 })

          Row() {
            SymbolGlyph($r('sys.symbol.pin')).fontSize(12).fontColor(['#D9FFFFFF'])
            Text(this.hasEgress ? this.egressText : this.statusText).fontSize(11)
              .fontColor('#D9FFFFFF').margin({ left: 4 })
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            Text(this.updatedText).fontSize(10).fontColor('#99FFFFFF')
          }
          .width('100%')
          .margin({ top: 6 })
        } else {
          // 2x4: live speeds side by side
          Row() {
            Column() {
              Row() {
                SymbolGlyph($r('sys.symbol.arrow_down')).fontSize(13).fontColor(['#BFFFFFFF'])
                Text('DOWN').fontSize(10).fontColor('#BFFFFFFF').margin({ left: 4 })
              }
              Text(this.downText).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .margin({ top: 2 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column() {
              Row() {
                SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(13).fontColor(['#BFFFFFFF'])
                Text('UP').fontSize(10).fontColor('#BFFFFFFF').margin({ left: 4 })
              }
              Text(this.upText).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .margin({ top: 2 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column() {
              Row() {
                SymbolGlyph($r('sys.symbol.link')).fontSize(13).fontColor(['#BFFFFFFF'])
                Text('CONN').fontSize(10).fontColor('#BFFFFFFF').margin({ left: 4 })
              }
              Text(this.connText).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .margin({ top: 2 }).maxLines(1)
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .margin({ top: 10 })

          // chips: node / egress / memory+totals
          Row() {
            if (this.nodeText.length > 0) {
              this.chip($r('sys.symbol.paperplane'), this.nodeText)
            }
            if (this.hasEgress) {
              this.chip($r('sys.symbol.pin'), this.egressText.length > 0 ? this.egressText : this.egressIp)
            } else if (this.modeText.length > 0) {
              this.chip($r('sys.symbol.slider_horizontal_2'), this.modeText)
            }
          }
          .width('100%')
          .margin({ top: 10 })

          Row() {
            Text(this.totalText).fontSize(10).fontColor('#99FFFFFF')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            Text(this.memText).fontSize(10).fontColor('#99FFFFFF')
              .maxLines(1).margin({ left: 8 })
            Text(this.updatedText).fontSize(10).fontColor('#99FFFFFF')
              .maxLines(1).margin({ left: 8 })
          }
          .width('100%')
          .margin({ top: 6 })
        }
      }
      .width('100%')
      .height('100%')
      .padding(this.compact ? 12 : 14)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
    .onClick(() => {
      this.openApp();
    })
  }
}
