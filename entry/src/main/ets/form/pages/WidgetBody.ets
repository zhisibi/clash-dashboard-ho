/**
 * Shared service-widget card UI (1.4.0; interactive since 1.4.1, rewired in 1.4.2, layout
 * rounds in 1.4.2/1.4.4): a gradient card tinted by the app's current accent. All texts arrive
 * pre-formatted from the app snapshot (WidgetSync.ets); the card itself does no network work.
 * Interactions: tapping the header or the speed area opens the app (router action). The mode
 * buttons fire 'call' actions that start EntryAbility in the background; its callee runs the
 * switch through the app's own Store and pushes a fresh snapshot back, so the card re-renders
 * immediately with a short result line. The node row is display only: the boss removed its
 * tap-to-cycle action in 1.4.7 (node switching happens in the app).
 * Wide card layout (boss, 2026-11-01): the right rail holds the connection status on top of
 * the Rule / Global / Direct buttons, aligned as one column and vertically centered; no
 * connection count, no totals line, no switch button. Small card: mode segment at the bottom
 * with no clock text, node row without the switch glyph.
 * Since 1.4.8 the mode button labels come from the card's own string resources (following the
 * system language), not from the snapshot, so they can never get stuck in the wrong language;
 * the small card's content is vertically centered as a whole (the minus-one-screen host gives
 * the 2x2 form more height than the desktop, which left a blank band at the bottom).
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
  @Prop upTotalText: string = '';
  @Prop downTotalText: string = '';
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

  @Builder
  modeChip(mode: string, label: Resource, enabled: boolean) {
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
        this.modeChip('rule', $r('app.string.widget_mode_rule'), true)
      }
      if (this.hasGlobal) {
        this.modeChip('global', $r('app.string.widget_mode_global'), true)
      }
      if (this.hasDirect) {
        this.modeChip('direct', $r('app.string.widget_mode_direct'), true)
      }
    }
    .width('100%')
    .margin({ top: this.compact ? 7 : 9 })
  }

  /** Wide card right rail: one mode button, stacked vertically (boss layout, 1.4.2/1.4.4) */
  @Builder
  railBtn(mode: string, label: Resource, enabled: boolean, first: boolean) {
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

  @Builder
  headerRow(withStatus: boolean) {
    Row() {
      Circle().width(8).height(8).fill(this.connected ? '#4ADE80' : '#B8BDC4')
      Text(this.brand).fontSize(this.compact ? 13 : 14).fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF').margin({ left: 6 })
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.labelText.length > 0 && !this.compact) {
        Text(this.labelText).fontSize(11).fontColor('#BFFFFFFF').margin({ left: 6 })
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      } else {
        Blank().layoutWeight(1)
      }
      if (withStatus) {
        Text(this.statusText).fontSize(11).fontColor('#D9FFFFFF')
          .maxLines(1)
      }
    }
    .width('100%')
    .onClick(() => {
      this.openApp();
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

      if (this.compact) {
        Column() {
          this.headerRow(true)

          // 2x2: download / upload totals, one per line (live speeds left in 1.4.11). The
          // 1.4.12 single-row layout still ellipsized the download value on device: sharing
          // the row with the upload value left too little width, and minFontSize alone does
          // not engage ArkUI's adaptive shrink (min AND max are both required). Each total
          // now gets the full card width plus proper adaptive sizing (1.4.14)
          Row() {
            SymbolGlyph($r('sys.symbol.arrow_down')).fontSize(15).fontColor(['#FFFFFF'])
            Text(this.downTotalText).fontSize(19).minFontSize(11).maxFontSize(19)
              .fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .margin({ left: 4 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 7 })
          .onClick(() => {
            this.openApp();
          })

          Row() {
            SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(13).fontColor(['#D9FFFFFF'])
            Text(this.upTotalText).fontSize(14).minFontSize(10).maxFontSize(14)
              .fontColor('#E6FFFFFF')
              .margin({ left: 4 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 3 })
          .onClick(() => {
            this.openApp();
          })

          Row() {
            SymbolGlyph($r('sys.symbol.paperplane')).fontSize(11).fontColor(['#D9FFFFFF'])
            Text(this.nodeText.length > 0 ? this.nodeText : this.statusText).fontSize(11)
              .fontColor('#E6FFFFFF').margin({ left: 4 })
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .margin({ top: 3 })

          this.modeRow()
        }
        .width('100%')
        .height('100%')
        .padding(11)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      } else {
        // 2x4 (boss layout): left = header / speeds / node; right rail = status + mode
        // buttons, aligned as one column and vertically centered as a whole
        Row() {
          Column() {
            this.headerRow(false)

            // totals + memory on one row (tap opens the app); live speeds left in 1.4.11
            Row() {
              Column() {
                Row() {
                  SymbolGlyph($r('sys.symbol.arrow_down')).fontSize(12).fontColor(['#BFFFFFFF'])
                  Text($r('app.string.widget_total_down')).fontSize(9).fontColor('#BFFFFFFF')
                    .margin({ left: 4 })
                }
                Text(this.downTotalText).fontSize(17).minFontSize(11).maxFontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  .margin({ top: 1 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column() {
                Row() {
                  SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(12).fontColor(['#BFFFFFFF'])
                  Text($r('app.string.widget_total_up')).fontSize(9).fontColor('#BFFFFFFF')
                    .margin({ left: 4 })
                }
                Text(this.upTotalText).fontSize(17).minFontSize(11).maxFontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  .margin({ top: 1 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column() {
                Row() {
                  SymbolGlyph($r('sys.symbol.memory_module')).fontSize(12).fontColor(['#BFFFFFFF'])
                  Text($r('app.string.widget_mem')).fontSize(9).fontColor('#BFFFFFFF')
                    .margin({ left: 4 })
                }
                Text(this.memText).fontSize(17).minFontSize(11).maxFontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  .margin({ top: 1 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 8 })
            .onClick(() => {
              this.openApp();
            })

            // node row: group + current node on one line, display only (1.4.7)
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
            }
            .width('100%')
            .margin({ top: 9 })
          }
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .height('100%')

          // right rail: status aligned over the three mode buttons, centered as a whole
          Column() {
            Text(this.statusText).fontSize(11).fontColor('#D9FFFFFF')
              .textAlign(TextAlign.Center)
              .width(58)
              .maxLines(1)
              .margin({ bottom: 8 })
            if (this.hasRule) {
              this.railBtn('rule', $r('app.string.widget_mode_rule'), true, true)
            }
            if (this.hasGlobal) {
              this.railBtn('global', $r('app.string.widget_mode_global'), true, !this.hasRule)
            }
            if (this.hasDirect) {
              this.railBtn('direct', $r('app.string.widget_mode_direct'), true, !this.hasRule && !this.hasGlobal)
            }
          }
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .height('100%')
          .margin({ left: 10 })
        }
        .width('100%')
        .height('100%')
        .padding(12)
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
  }
}
