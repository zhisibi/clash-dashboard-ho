import { Store } from '../common/Store';
import { PullRefresh } from '../components/PullRefresh';
import { GlassHeader, headerGuess } from '../components/GlassHeader';
import { RuleItem, RuleProvider, parseIsoMillis } from '../common/Models';
import { fmtAgo, safeRegex, textMatch } from '../common/Format';
import { EmptyCard, ProxyIcon, RoundIconButton, SearchBox, SegTabs, Tag, latencyColor } from '../components/Widgets';

@ComponentV2
struct ProxyChainChip {
  private store: Store = Store.get();
  @Param proxy: string = '';

  build() {
    Row() {
      ProxyIcon({ url: this.store.proxies.get(this.proxy)?.icon ?? '', iconSize: 18 })
      Text(this.proxy).fontSize(14).maxLines(1).fontColor(this.store.palette().text)
      if (this.store.resolveNow(this.proxy) !== this.proxy) {
        Text('  ›  ').fontSize(14).fontColor(this.store.palette().subtle)
        ProxyIcon({ url: this.store.proxies.get(this.store.resolveNow(this.proxy))?.icon ?? '', iconSize: 18 })
        Text(this.store.resolveNow(this.proxy))
          .fontSize(14)
          .maxLines(1)
          .fontColor(this.store.palette().text)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 140 })
      }
      if (this.store.proxies.get(this.proxy) !== undefined && this.store.delayOf(this.proxy, this.store.testUrl) > 0) {
        Text(this.store.delayOf(this.proxy, this.store.testUrl).toString())
          .fontSize(13)
          .margin({ left: 8 })
          .fontColor(latencyColor(this.store.palette(), this.store.delayOf(this.proxy, this.store.testUrl),
            this.store.lowLatency, this.store.mediumLatency))
      }
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .borderRadius(16)
    .backgroundColor(this.store.palette().chip)
    .flexShrink(1)
  }
}

// 不在当前页时冻结界面刷新（Tabs 中不可见的 TabContent），切回来时再应用最新数据；页面状态保留
@ComponentV2({ freezeWhenInactive: true })
export struct RulesView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(2);
  private sc: Scroller = new Scroller();
  private sc2: Scroller = new Scroller();
  @Local tab: number = 0;
  @Local query: string = '';

  providerCount(name: string): number {
    for (const p of this.store.ruleProviders) {
      if (p.name === name) {
        return p.ruleCount;
      }
    }
    return -1;
  }

  isProvider(name: string): boolean {
    return this.providerCount(name) >= 0;
  }

  rulesList(): RuleItem[] {
    const re = safeRegex(this.query);
    return this.store.rules.filter((r: RuleItem) =>
    textMatch(re, this.query, r.payload) || textMatch(re, this.query, r.type) || textMatch(re, this.query, r.proxy));
  }

  providerList(): RuleProvider[] {
    const re = safeRegex(this.query);
    return this.store.ruleProviders.filter((p: RuleProvider) =>
    textMatch(re, this.query, p.name) || textMatch(re, this.query, p.behavior));
  }

  @Builder
  optionsMenu() {
    Menu() {
      MenuItem({ content: '显示命中次数' }).selected(this.store.showRuleHits).selectIcon(true).onClick(() => {
        this.store.showRuleHits = !this.store.showRuleHits;
        this.store.savePrefs();
      })
      MenuItem({ content: '刷新' }).onClick(() => {
        this.store.refreshRules();
      })
      if (this.store.ruleProviders.length > 0) {
        MenuItem({ content: '更新全部规则集' }).onClick(() => {
          this.store.updateAllRuleProviders();
        })
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      PullRefresh({ topInset: this.headerH, page: 'rules' }) {
        if (this.tab === 0) {
          if (this.rulesList().length === 0) {
            Column() {
              EmptyCard({ pal: this.store.palette() })
            }
            .padding({ left: 14, right: 14, top: this.headerH + 14 })
          } else {
            List({ space: 10, scroller: this.sc }) {
              Repeat<RuleItem>(this.rulesList())
                .each((ri: RepeatItem<RuleItem>) => {
                  ListItem() {
                    Column() {
                      Row() {
                        Text((ri.item.index + 1).toString()).fontSize(14).fontColor(this.store.palette().subtle)
                        Text(ri.item.type + ' :').fontSize(14).fontColor(this.store.palette().subtle).margin({ left: 14 })
                        Text(ri.item.payload.length > 0 ? ri.item.payload : '-')
                          .fontSize(16)
                          .fontColor(this.store.palette().text)
                          .maxLines(2)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .flexShrink(1)
                          .margin({ left: 10 })
                        if ((this.providerCount(ri.item.payload) > 0 ? this.providerCount(ri.item.payload) : ri.item.size) > 0) {
                          Text('(' + (this.providerCount(ri.item.payload) > 0 ? this.providerCount(ri.item.payload) :
                          ri.item.size) + ')')
                            .fontSize(13)
                            .fontColor(this.store.palette().subtle)
                            .margin({ left: 6 })
                        }
                        if (ri.item.type === 'RuleSet' && this.isProvider(ri.item.payload)) {
                          if (this.store.updatingRuleProviders.get(ri.item.payload) === true) {
                            LoadingProgress().width(18).height(18).color(this.store.palette().subtle).margin({ left: 6 })
                          } else {
                            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                              .fontSize(16)
                              .fontColor([this.store.palette().subtle])
                              .margin({ left: 6 })
                              .onClick(() => {
                                this.store.updateRuleProvider(ri.item.payload);
                              })
                          }
                        }
                      }
                      .width('100%')

                      Row() {
                        if (this.store.rulesDisableSupported) {
                          Toggle({ type: ToggleType.Switch, isOn: !ri.item.disabled })
                            .selectedColor(this.store.palette().accent)
                            .onChange((on: boolean) => {
                              if (on === ri.item.disabled) {
                                this.store.toggleRule(ri.item);
                              }
                            })
                            .margin({ right: 10 })
                        }
                        ProxyChainChip({ proxy: ri.item.proxy })
                        if (this.store.showRuleHits && ri.item.hitCount > 0) {
                          Blank()
                          Text('命中 ' + ri.item.hitCount).fontSize(12).fontColor(this.store.palette().subtle)
                        }
                      }
                      .width('100%')
                      .margin({ top: 8 })
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                    .borderRadius(18)
                    .attributeModifier(Store.get().glass('row'))
                  }
                })
                .key((r: RuleItem) => r.index + '_' + r.disabled + '_' + r.hitCount + '_' + r.proxy)
                .virtualScroll()
            }
            .padding({ left: 14, right: 14, top: this.headerH + 14, bottom: this.bottomPad + 14 })
            .width('100%')
            .height('100%')
            .clipContent(ContentClipMode.BOUNDARY)
            .onDidScroll((d: number, st: ScrollState) => {
              this.store.navScroll(this.sc, d, st);
            })
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .scrollBar(BarState.Off)
            .cachedCount(4)
          }
        } else {
          if (this.providerList().length === 0) {
            Column() {
              EmptyCard({ pal: this.store.palette() })
            }
            .padding({ left: 14, right: 14, top: this.headerH + 14 })
          } else {
            List({ space: 10, scroller: this.sc2 }) {
              ForEach(this.providerList(), (p: RuleProvider) => {
                ListItem() {
                  Row() {
                    Column() {
                      Row() {
                        Text(p.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
                        Text('(' + p.ruleCount + ')').fontSize(13).fontColor(this.store.palette().subtle).margin({ left: 6 })
                      }

                      Row({ space: 6 }) {
                        Tag({ pal: this.store.palette(), text: p.behavior })
                        Tag({ pal: this.store.palette(), text: p.vehicleType })
                        if (p.format.length > 0) {
                          Tag({ pal: this.store.palette(), text: p.format })
                        }
                        Text('更新于 ' + fmtAgo(parseIsoMillis(p.updatedAt))).fontSize(12).fontColor(this.store.palette().subtle)
                      }
                      .margin({ top: 4 })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    if (this.store.updatingRuleProviders.get(p.name) === true) {
                      LoadingProgress().width(22).height(22).color(this.store.palette().subtle)
                    } else {
                      SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                        .fontSize(20)
                        .fontColor([this.store.palette().text])
                        .onClick(() => {
                          this.store.updateRuleProvider(p.name);
                        })
                    }
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .borderRadius(18)
                  .attributeModifier(Store.get().glass('row'))
                }
              }, (p: RuleProvider) => p.name + '_' + p.updatedAt + '_' + p.ruleCount)
            }
            .padding({ left: 14, right: 14, top: this.headerH + 14, bottom: this.bottomPad + 14 })
            .width('100%')
            .height('100%')
            .clipContent(ContentClipMode.BOUNDARY)
            .onDidScroll((d: number, st: ScrollState) => {
              this.store.navScroll(this.sc2, d, st);
            })
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .scrollBar(BarState.Off)
          }
        }
      }

      GlassHeader({
        onHeight: (h: number) => {
          this.headerH = h;
        }
      }) {
        Column({ space: 6 }) {
          SegTabs({
            pal: this.store.palette(), dense: true,
            items: ['规则 ' + this.store.rules.length, '规则提供商 ' + this.store.ruleProviders.length],
            selected: this.tab,
            onSelect: (i: number) => {
              this.tab = i;
            }
          })
          Row({ space: 6 }) {
            SearchBox({
              pal: this.store.palette(), dense: true,
              value: this.query,
              placeholder: '搜索 | Regex',
              onChange: (v: string) => {
                this.query = v;
              }
            })
              .layoutWeight(1)
            Stack() {
              SymbolGlyph($r('sys.symbol.slider_horizontal_2')).fontSize(17).fontColor([this.store.palette().text])
            }
            .width(34)
            .height(34)
            .borderRadius(17)
            .backgroundColor(this.store.palette().chip)
            .bindMenu(this.optionsMenu())
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.store.palette().bg)
  }
}
