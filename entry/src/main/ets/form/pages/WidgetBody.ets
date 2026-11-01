/**
 * Shared service-widget card UI (1.4.0; interactive since 1.4.1, rewired in 1.4.2): a gradient
 * card tinted by the app's current accent. All texts arrive pre-formatted from the app snapshot
 * (WidgetSync.ets); the card itself does no network work.
 * Interactions: tapping the header or the speed area opens the app (router action). The mode
 * buttons and the node switch fire 'call' actions that start EntryAbility in the background;
 * its callee runs the switch through the app's own Store and pushes a fresh snapshot back, so
 * the card re-renders immediately with a short result line under the header. (1.4.1 used
 * 'message' actions with a hand-built payload the system never delivered to onFormEvent, so
 * every button was dead; the form-process executor is gone.)
 * A full node list cannot be shown on a form card (system restriction), so the node button
 * cycles to the next leaf node of the main group.
 * Wide card layout (boss, 2026-11-01): no connection count; the Rule / Global / Direct buttons
 * sit in a vertical rail on the right edge; heights are kept tight so nothing is clipped.
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
      action: 'call',
      abilityName: 'EntryAbility',
      params: {
        method: 'widgetAction',
        params: JSON.stringify({ action: 'setMode', mode: mode })
      }
    });
  }

  private cycleNode(): void {
    postCardAction(this, {
      action: 'call',
      abilityName: 'EntryAbility',
      params: {
        method: 'widgetAction',
        params: JSON.stringify({ action: 'cycleNode' })
      }
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

  /** Wide card right rail: one mode button, stacked vertically (boss layout, 1.4.2) */
  @Builder
  railBtn(mode: string, label: string, enabled: boolean, first: boolean) {
    Text(label)
      .fontSize(11)
      .fontWeight(this.modeKey === mode ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.modeKey === mode ? '#1D2025' : (enabled ? '#F2FFFFFF' : '#66FFFFFF'))
      .textAlign(TextAlign.Center)
      .width(58)
      .padding({ top: 7, bottom: 7 })
      .borderRadius(12)
      .backgroundColor(this.modeKey === mode ? '#FFFFFF' : '#26FFFFFF')
      .margin({ top: first ? 0 : 6 })
      .onClick(() => {
        if (enabled && this.modeKey !== mode) {
          this.setMode(mode);
        }
      })
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
          Text(this.brand).fontSize(this.compact ? 13 : 14).fontWeight(FontWeight.Bold)
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

        // action feedback: directly under the header so it is never clipped (1.4.2)
        if (this.msgText.length > 0) {
          Text(this.msgText).fontSize(10).fontColor('#FDE68A')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
        }

        if (this.compact) {
          // 2x2: big download, up, node row (tap cycles), then the mode segment
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
          // 2x4 (boss layout): content left, mode rail right; no connection count
          Row() {
            Column() {
              // live speeds side by side (tap opens the app)
              Row() {
                Column() {
                  Row() {
                    SymbolGlyph($r('sys.symbol.arrow_down')).fontSize(12).fontColor(['#BFFFFFFF'])
                    Text('DOWN').fontSize(9).fontColor('#BFFFFFFF').margin({ left: 4 })
                  }
                  Text(this.downText).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                    .margin({ top: 1 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column() {
                  Row() {
                    SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(12).fontColor(['#BFFFFFFF'])
                    Text('UP').fontSize(9).fontColor('#BFFFFFFF').margin({ left: 4 })
                  }
                  Text(this.upText).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                    .margin({ top: 1 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .onClick(() => {
                this.openApp();
              })

              // node row: group + current node on one line, switch button cycles the node
              Row() {
                SymbolGlyph($r('sys.symbol.paperplane')).fontSize(12).fontColor(['#E6FFFFFF'])
                if (this.groupName.length > 0) {
                  Text(this.groupName).fontSize(9).fontColor('#99FFFFFF')
                    .margin({ left: 5 })
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                Text(this.nodeText.length > 0 ? this.nodeText : '-').fontSize(12)
                  .fontColor('#FFFFFF').margin({ left: 4 })
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                Row() {
                  SymbolGlyph($r('sys.symbol.arrow_left_arrow_right')).fontSize(11)
                    .fontColor(['#FFFFFF'])
                  Text(this.switchText).fontSize(11).fontColor('#FFFFFF').margin({ left: 4 })
                }
                .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                .borderRadius(12)
                .backgroundColor('#33FFFFFF')
                .margin({ left: 6 })
                .onClick(() => {
                  this.cycleNode();
                })
              }
              .width('100%')
              .margin({ top: 7 })

              // bottom line: egress chip + totals / memory
              Row() {
                if (this.hasEgress) {
                  this.chip($r('sys.symbol.pin'), this.egressText.length > 0 ? this.egressText : this.egressIp)
                }
                Blank().layoutWeight(1)
                Text(this.totalText + '  ·  ' + this.memText).fontSize(10).fontColor('#99FFFFFF')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            // right rail: Rule / Global / Direct stacked vertically
            Column() {
              if (this.hasRule) {
                this.railBtn('rule', this.modeRuleText, true, true)
              }
              if (this.hasGlobal) {
                this.railBtn('global', this.modeGlobalText, true, !this.hasRule)
              }
              if (this.hasDirect) {
                this.railBtn('direct', this.modeDirectText, true, !this.hasRule && !this.hasGlobal)
              }
            }
            .margin({ left: 8 })
          }
          .width('100%')
          .margin({ top: 6 })
          .alignItems(VerticalAlign.Top)
        }
      }
      .width('100%')
      .height('100%')
      .padding(this.compact ? 11 : 12)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
  }
}
