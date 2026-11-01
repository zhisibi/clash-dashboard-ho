/**
 * Shared service-widget card UI (1.4.0; interactive since 1.4.1): a gradient card tinted by the
 * app's current accent. All texts arrive pre-formatted from the app snapshot (WidgetSync.ets);
 * the card itself does no network work.
 * Interactions: tapping the header or the speed area opens the app (router action); the mode
 * chips and the node switch button post message actions that EntryFormAbility executes against
 * the backend right in the form process, then re-renders the card from the updated snapshot.
 * A full node list cannot be shown on a form card (system restriction), so the node button
 * cycles to the next leaf node of the main group.
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
  @Prop modeKey: string = '';
  @Prop modeRuleText: string = 'Rule';
  @Prop modeGlobalText: string = 'Global';
  @Prop modeDirectText: string = 'Direct';
  @Prop hasRule: boolean = true;
  @Prop hasGlobal: boolean = true;
  @Prop hasDirect: boolean = true;
  @Prop switchText: string = 'Switch';
  @Prop msgText: string = '';
  @Prop groupName: string = '';
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

  private setMode(mode: string): void {
    postCardAction(this, {
      action: 'message',
      message: '{"action":"setMode","mode":"' + mode + '"}'
    });
  }

  private cycleNode(): void {
    postCardAction(this, {
      action: 'message',
      message: '{"action":"cycleNode"}'
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

  @Builder
  modeChip(mode: string, label: string, enabled: boolean) {
    Text(label)
      .fontSize(this.compact ? 10 : 11)
      .fontWeight(this.modeKey === mode ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.modeKey === mode ? '#1D2025' : (enabled ? '#E6FFFFFF' : '#66FFFFFF'))
      .padding({
        left: this.compact ? 7 : 9, right: this.compact ? 7 : 9,
        top: this.compact ? 3 : 4, bottom: this.compact ? 3 : 4
      })
      .borderRadius(10)
      .backgroundColor(this.modeKey === mode ? '#FFFFFF' : '#26FFFFFF')
      .margin({ right: 5 })
      .onClick(() => {
        if (enabled && this.modeKey !== mode) {
          this.setMode(mode);
        }
      })
  }

  @Builder
  modeRow() {
    Row() {
      if (this.hasRule) {
        this.modeChip('rule', this.modeRuleText, true)
      }
      if (this.hasGlobal) {
        this.modeChip('global', this.modeGlobalText, true)
      }
      if (this.hasDirect) {
        this.modeChip('direct', this.modeDirectText, true)
      }
      Blank().layoutWeight(1)
      Text(this.updatedText).fontSize(10).fontColor('#99FFFFFF')
    }
    .width('100%')
    .margin({ top: this.compact ? 7 : 9 })
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
        // header: brand, backend label, status (tap opens the app)
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
        .onClick(() => {
          this.openApp();
        })

        if (this.compact) {
          // 2x2: big download, up / connections, egress line, then the mode segment
          Row() {
            SymbolGlyph($r('sys.symbol.arrow_down')).fontSize(16).fontColor(['#FFFFFF'])
            Text(this.downText).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .margin({ left: 4 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(12).fontColor(['#D9FFFFFF'])
              .margin({ left: 10 })
            Text(this.upText).fontSize(12).fontColor('#D9FFFFFF').margin({ left: 3 })
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .margin({ top: 7 })
          .onClick(() => {
            this.openApp();
          })

          // node row: tap cycles to the next node of the main group
          Row() {
            SymbolGlyph($r('sys.symbol.paperplane')).fontSize(11).fontColor(['#D9FFFFFF'])
            Text(this.nodeText.length > 0 ? this.nodeText : this.statusText).fontSize(11)
              .fontColor('#E6FFFFFF').margin({ left: 4 })
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            SymbolGlyph($r('sys.symbol.arrow_left_arrow_right')).fontSize(11)
              .fontColor(['#FFFFFF'])
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .margin({ top: 3 })
          .onClick(() => {
            this.cycleNode();
          })

          this.modeRow()
        } else {
          // 2x4: live speeds side by side (tap opens the app)
          Row() {
            Column() {
              Row() {
                SymbolGlyph($r('sys.symbol.arrow_down')).fontSize(13).fontColor(['#BFFFFFFF'])
                Text('DOWN').fontSize(10).fontColor('#BFFFFFFF').margin({ left: 4 })
              }
              Text(this.downText).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .margin({ top: 2 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column() {
              Row() {
                SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(13).fontColor(['#BFFFFFFF'])
                Text('UP').fontSize(10).fontColor('#BFFFFFFF').margin({ left: 4 })
              }
              Text(this.upText).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .margin({ top: 2 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column() {
              Row() {
                SymbolGlyph($r('sys.symbol.link')).fontSize(13).fontColor(['#BFFFFFFF'])
                Text('CONN').fontSize(10).fontColor('#BFFFFFFF').margin({ left: 4 })
              }
              Text(this.connText).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .margin({ top: 2 }).maxLines(1)
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .margin({ top: 9 })
          .onClick(() => {
            this.openApp();
          })

          // node row: current node + switch button (cycles to the next leaf node)
          Row() {
            SymbolGlyph($r('sys.symbol.paperplane')).fontSize(12).fontColor(['#E6FFFFFF'])
            Column() {
              if (this.groupName.length > 0) {
                Text(this.groupName).fontSize(9).fontColor('#99FFFFFF')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              Text(this.nodeText.length > 0 ? this.nodeText : '-').fontSize(12)
                .fontColor('#FFFFFF')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 5 })

            Row() {
              SymbolGlyph($r('sys.symbol.arrow_left_arrow_right')).fontSize(11)
                .fontColor(['#FFFFFF'])
              Text(this.switchText).fontSize(11).fontColor('#FFFFFF').margin({ left: 4 })
            }
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .borderRadius(12)
            .backgroundColor('#33FFFFFF')
            .onClick(() => {
              this.cycleNode();
            })
          }
          .width('100%')
          .margin({ top: 9 })

          // chips: egress / totals + memory
          Row() {
            if (this.hasEgress) {
              this.chip($r('sys.symbol.pin'), this.egressText.length > 0 ? this.egressText : this.egressIp)
            }
            this.chip($r('sys.symbol.memory_module'), this.memText)
            Blank().layoutWeight(1)
            Text(this.totalText).fontSize(10).fontColor('#99FFFFFF')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .margin({ top: 8 })

          this.modeRow()
        }

        if (this.msgText.length > 0) {
          Text(this.msgText).fontSize(10).fontColor('#FDE68A')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 5 })
        }
      }
      .width('100%')
      .height('100%')
      .padding(this.compact ? 11 : 13)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
  }
}
