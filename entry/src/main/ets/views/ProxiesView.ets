import { Store } from '../common/Store';
import { PullRefresh } from '../components/PullRefresh';
import { GlassHeader, headerGuess } from '../components/GlassHeader';
import { ProxyItem, ProxyProvider, parseIsoMillis } from '../common/Models';
import { fmtAgo, fmtBytes, fmtDate, safeRegex, textMatch } from '../common/Format';
import { LatencyBadge, ProxyIcon, RoundIconButton, SearchBox, SegTabs, Tag, EmptyCard } from '../components/Widgets';
import { t } from '../common/I18n';

@ComponentV2
struct GroupCard {
  private store: Store = Store.get();
  @Param name: string = '';
  @Event onOpen: () => void = () => {
  };

  aliveCount(g: ProxyItem, url: string): number {
    let n = 0;
    for (const x of g.all) {
      if (this.store.delayOf(x, url) > 0) {
        n++;
      }
    }
    return n;
  }

  build() {
    if (this.store.proxies.get(this.name) !== undefined) {
      Column() {
        Row() {
          Column() {
            Text(this.name)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.store.palette().text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text((this.store.proxies.get(this.name) as ProxyItem).type.toUpperCase() + ' · ' +
            this.aliveCount(this.store.proxies.get(this.name) as ProxyItem,
              this.store.groupTestUrl(this.store.proxies.get(this.name) as ProxyItem)) + '/' +
            (this.store.proxies.get(this.name) as ProxyItem).all.length)
              .fontSize(12)
              .fontColor(this.store.palette().subtle)
              .letterSpacing(1)
              .maxLines(1)
              .margin({ top: 6 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          ProxyIcon({ url: (this.store.proxies.get(this.name) as ProxyItem).icon, iconSize: 40 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row() {
          SymbolGlyph((this.store.proxies.get(this.name) as ProxyItem).fixed.length > 0 ? $r('sys.symbol.pin') :
          $r('sys.symbol.arrow_right_circle'))
            .fontSize(16)
            .fontColor([this.store.palette().subtle])
            .margin({ right: 6 })
          ProxyIcon({
            url: this.store.proxies.get((this.store.proxies.get(this.name) as ProxyItem).now)?.icon ?? '',
            iconSize: 18
          })
          Text((this.store.proxies.get(this.name) as ProxyItem).now)
            .fontSize(14)
            .fontColor(this.store.palette().text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          LatencyBadge({
            pal: this.store.palette(),
            delay: this.store.delayOf(this.name, this.store.groupTestUrl(this.store.proxies.get(this.name) as ProxyItem)),
            low: this.store.lowLatency,
            medium: this.store.mediumLatency,
            testing: this.store.testing.get(this.name) === true,
            onTap: () => {
              const g = this.store.proxies.get(this.name);
              if (g !== undefined) {
                this.store.testGroup(g);
              }
            }
          })
        }
        .width('100%')
        .margin({ top: 10 })
      }
      .width('100%')
      .padding({ left: 16, right: 14, top: 14, bottom: 12 })
      .borderRadius(18)
      .attributeModifier(Store.get().glass('card'))
      .onClick(() => {
        this.onOpen();
      })
    }
  }
}

@ComponentV2
struct NodeCard {
  private store: Store = Store.get();
  @Param groupName: string = '';
  @Param node: string = '';

  build() {
    Column() {
      Row() {
        ProxyIcon({ url: this.store.proxies.get(this.node)?.icon ?? '', iconSize: 18 })
        Text(this.node)
          .fontSize(14)
          .fontColor(this.store.palette().text)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontWeight(this.store.proxies.get(this.groupName)?.now === this.node ? FontWeight.Bold : FontWeight.Normal)
      }
      .width('100%')

      Row() {
        Row({ space: 4 }) {
          Tag({ pal: this.store.palette(), text: this.store.proxies.get(this.node)?.type ?? '?' })
          if (this.store.proxies.get(this.node)?.udp === true) {
            Tag({ pal: this.store.palette(), text: 'UDP' })
          }
          if (this.store.proxies.get(this.node)?.isGroup() === true) {
            Tag({ pal: this.store.palette(), text: this.store.proxies.get(this.node)?.now ?? '' })
          }
        }
        .layoutWeight(1)
        .clip(true)

        LatencyBadge({
          pal: this.store.palette(),
          delay: this.store.delayOf(this.node, this.url()),
          low: this.store.lowLatency,
          medium: this.store.mediumLatency,
          testing: this.store.nodeTesting.get(this.node) === true,
          onTap: () => {
            const p = this.store.proxies.get(this.node);
            if (p !== undefined && p.isGroup()) {
              this.store.testGroup(p);
            } else {
              this.store.testNode(this.node, this.url());
            }
          }
        })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .padding(12)
    .borderRadius(18)
    .attributeModifier(Store.get().glass('plain'))
    .border({
      width: 2,
      color: this.store.proxies.get(this.groupName)?.now === this.node ? this.store.palette().accentUi : Color.Transparent,
      radius: 18
    })
    .onClick(() => {
      const g = this.store.proxies.get(this.groupName);
      if (g !== undefined && this.store.isSelectable(g)) {
        this.store.select(g, this.node);
      }
    })
  }

  url(): string {
    const g = this.store.proxies.get(this.groupName);
    return g !== undefined ? this.store.groupTestUrl(g) : this.store.testUrl;
  }
}

@ComponentV2
struct GroupDetail {
  private store: Store = Store.get();
  @Param name: string = '';

  build() {
    Column() {
      if (this.store.proxies.get(this.name) !== undefined) {
        Row() {
          ProxyIcon({ url: (this.store.proxies.get(this.name) as ProxyItem).icon, iconSize: 34 })
          Column() {
            Text(this.name)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.store.palette().text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(t('group_detail_sub', (this.store.proxies.get(this.name) as ProxyItem).type,
              this.store.nodesOf(this.store.proxies.get(this.name) as ProxyItem).length,
              (this.store.proxies.get(this.name) as ProxyItem).now || '-'))
              .fontSize(12)
              .fontColor(this.store.palette().subtle)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 6 })

          if ((this.store.proxies.get(this.name) as ProxyItem).fixed.length > 0 &&
            (this.store.proxies.get(this.name) as ProxyItem).type.toLowerCase() !== 'selector') {
            Button(t('act_unfix'), { type: ButtonType.Capsule })
              .fontSize(13)
              .height(32)
              .fontColor(this.store.palette().text)
              .backgroundColor(this.store.palette().chip)
              .margin({ right: 8 })
              .onClick(() => {
                const g = this.store.proxies.get(this.name);
                if (g !== undefined) {
                  this.store.unfix(g);
                }
              })
          }
          RoundIconButton({
            pal: this.store.palette(),
            icon: $r('sys.symbol.bolt'),
            active: this.store.testing.get(this.name) === true,
            onTap: () => {
              const g = this.store.proxies.get(this.name);
              if (g !== undefined) {
                this.store.testGroup(g);
              }
            }
          })
        }
        .width('100%')
        .padding({ left: 18, right: 18 })

        Grid() {
          ForEach(this.store.nodesOf(this.store.proxies.get(this.name) as ProxyItem), (n: string) => {
            GridItem() {
              NodeCard({ groupName: this.name, node: n })
            }
          }, (n: string) => n)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .padding({ left: 14, right: 14, top: 12, bottom: 32 })
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.store.palette().sheet)
  }
}

@ComponentV2
struct ProviderCard {
  private store: Store = Store.get();
  @Param provider: ProxyProvider = new ProxyProvider();
  @Local expanded: boolean = false;

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.provider.name).fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(t('provider_sub', this.provider.vehicleType, this.provider.proxies.length,
            fmtAgo(parseIsoMillis(this.provider.updatedAt))))
            .fontSize(12)
            .fontColor(this.store.palette().subtle)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.store.testing.get('provider:' + this.provider.name) === true) {
          LoadingProgress().width(22).height(22).color(this.store.palette().subtle).margin({ right: 10 })
        } else {
          SymbolGlyph($r('sys.symbol.bolt'))
            .fontSize(20)
            .fontColor([this.store.palette().text])
            .margin({ right: 14 })
            .onClick(() => {
              this.store.healthcheck(this.provider.name);
            })
        }
        if (this.provider.vehicleType.toLowerCase() === 'http') {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(20)
            .fontColor([this.store.palette().text])
            .onClick(() => {
              this.store.updateProvider(this.provider.name);
            })
        }
      }
      .width('100%')

      if (this.provider.subTotal > 0) {
        Progress({
          value: Math.min(this.provider.subTotal, this.provider.subUpload + this.provider.subDownload),
          total: this.provider.subTotal,
          type: ProgressType.Linear
        })
          .style({ strokeWidth: 6 })
          .color(this.store.palette().accentUi)
          .backgroundColor(this.store.palette().chip)
          .width('100%')
          .margin({ top: 8 })
        Text(fmtBytes(this.provider.subUpload + this.provider.subDownload) + ' / ' + fmtBytes(this.provider.subTotal) +
          (this.provider.subExpire > 0 ? t('sub_expire', fmtDate(this.provider.subExpire * 1000)) : ''))
          .fontSize(12)
          .fontColor(this.store.palette().subtle)
          .margin({ top: 4 })
      }

      if (this.expanded) {
        Column() {
          ForEach(this.provider.proxies, (n: ProxyItem) => {
            Row() {
              Text(n.name)
                .fontSize(14)
                .fontColor(this.store.palette().text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              Tag({ pal: this.store.palette(), text: n.type })
              Blank().width(6)
              LatencyBadge({
                pal: this.store.palette(),
                delay: this.store.delayOf(n.name, this.provider.testUrl),
                low: this.store.lowLatency,
                medium: this.store.mediumLatency,
                testing: this.store.nodeTesting.get(n.name) === true,
                onTap: () => {
                  this.store.testNode(n.name, this.provider.testUrl.length > 0 ? this.provider.testUrl : this.store.testUrl);
                }
              })
            }
            .width('100%')
            .padding({ top: 5, bottom: 5 })
          }, (n: ProxyItem) => n.name)
        }
        .margin({ top: 10 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(18)
    .attributeModifier(Store.get().glass('row'))
    .onClick(() => {
      this.expanded = !this.expanded;
    })
  }
}

// Frozen while not the current page (hidden TabContent); latest data applies on return, page state is kept
@ComponentV2({ freezeWhenInactive: true })
export struct ProxiesView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(2);
  private sc: Scroller = new Scroller();
  private sc2: Scroller = new Scroller();
  @Local query: string = '';
  @Local tab: number = 0;
  @Local openGroup: string = '';
  @Local showSheet: boolean = false;

  matchGroup(g: ProxyItem, re: RegExp | null): boolean {
    if (textMatch(re, this.query, g.name)) {
      return true;
    }
    for (const n of g.all) {
      if (textMatch(re, this.query, n)) {
        return true;
      }
    }
    return false;
  }

  shownGroups(): ProxyItem[] {
    const re = safeRegex(this.query);
    return this.store.groups().filter((g: ProxyItem) => this.matchGroup(g, re));
  }

  shownProviders(): ProxyProvider[] {
    const re = safeRegex(this.query);
    return this.store.providers.filter((p: ProxyProvider) => {
      if (textMatch(re, this.query, p.name)) {
        return true;
      }
      for (const n of p.proxies) {
        if (textMatch(re, this.query, n.name)) {
          return true;
        }
      }
      return false;
    });
  }

  @Builder
  optionsMenu() {
    Menu() {
      MenuItemGroup({ header: t('menu_node_sort') }) {
        MenuItem({ content: t('sort_default') }).selected(this.store.sortProxies === 'default').selectIcon(true)
          .onClick(() => {
            this.store.sortProxies = 'default';
            this.store.savePrefs();
          })
        MenuItem({ content: t('sort_by_latency') }).selected(this.store.sortProxies === 'latency').selectIcon(true)
          .onClick(() => {
            this.store.sortProxies = 'latency';
            this.store.savePrefs();
          })
        MenuItem({ content: t('sort_by_name') }).selected(this.store.sortProxies === 'name').selectIcon(true)
          .onClick(() => {
            this.store.sortProxies = 'name';
            this.store.savePrefs();
          })
      }

      MenuItemGroup({ header: t('menu_display') }) {
        MenuItem({ content: t('hide_unavailable') }).selected(this.store.hideUnavailable).selectIcon(true)
          .onClick(() => {
            this.store.hideUnavailable = !this.store.hideUnavailable;
            this.store.savePrefs();
          })
        MenuItem({ content: t('show_global_short') }).selected(this.store.showGlobal).selectIcon(true)
          .onClick(() => {
            this.store.showGlobal = !this.store.showGlobal;
            this.store.savePrefs();
          })
        MenuItem({ content: t('show_hidden_groups') }).selected(this.store.showHiddenGroups).selectIcon(true)
          .onClick(() => {
            this.store.showHiddenGroups = !this.store.showHiddenGroups;
            this.store.savePrefs();
          })
      }

      MenuItemGroup({ header: t('cards_per_row') }) {
        MenuItem({ content: t('n_cols', 1) }).selected(this.store.proxyCols === 1).selectIcon(true)
          .onClick(() => {
            this.store.proxyCols = 1;
            this.store.savePrefs();
          })
        MenuItem({ content: t('n_cols', 2) }).selected(this.store.proxyCols === 2).selectIcon(true)
          .onClick(() => {
            this.store.proxyCols = 2;
            this.store.savePrefs();
          })
        MenuItem({ content: t('n_cols', 3) }).selected(this.store.proxyCols === 3).selectIcon(true)
          .onClick(() => {
            this.store.proxyCols = 3;
            this.store.savePrefs();
          })
      }

      MenuItem({ content: t('act_refresh') }).onClick(() => {
        this.store.refreshProxies();
      })
    }
  }

  @Builder
  groupSheet() {
    GroupDetail({ name: this.openGroup })
  }

  colsTemplate(): string {
    const n = Math.max(1, Math.min(3, this.store.proxyCols));
    if (n === 1) {
      return '1fr';
    }
    if (n === 2) {
      return '1fr 1fr';
    }
    return '1fr 1fr 1fr';
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      PullRefresh({ topInset: this.headerH, page: 'proxies' }) {
        if (this.tab === 0 || this.store.providers.length === 0) {
          if (this.shownGroups().length === 0) {
            Column() {
              EmptyCard({ pal: this.store.palette(), text: this.store.proxiesLoading ? t('loading') : t('no_data') })
            }
            .padding({ left: 16, right: 16, top: this.headerH + 16 })
          } else {
            Grid(this.sc) {
              ForEach(this.shownGroups(), (g: ProxyItem) => {
                GridItem() {
                  GroupCard({
                    name: g.name, onOpen: () => {
                      this.openGroup = g.name;
                      this.showSheet = true;
                    }
                  })
                }
              }, (g: ProxyItem) => g.name)
            }
            .columnsTemplate(this.colsTemplate())
            .columnsGap(12)
            .rowsGap(12)
            .padding({ left: 14, right: 14, top: this.headerH + 14, bottom: this.bottomPad + 14 })
            .width('100%')
            .height('100%')
            .clipContent(ContentClipMode.BOUNDARY)
            .onDidScroll((d: number, st: ScrollState) => {
              this.store.navScroll(this.sc, d, st);
            })
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .scrollBar(BarState.Off)
          }
        } else {
          List({ space: 12, scroller: this.sc2 }) {
            ForEach(this.shownProviders(), (p: ProxyProvider) => {
              ListItem() {
                ProviderCard({ provider: p })
              }
            }, (p: ProxyProvider) => p.name + '_' + p.updatedAt + '_' + p.proxies.length)
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

      GlassHeader({
        onHeight: (h: number) => {
          this.headerH = h;
        }
      }) {
        Column() {
          if (this.store.providers.length > 0) {
            SegTabs({
              pal: this.store.palette(), dense: true,
              items: [t('seg_groups', this.store.groups().length), t('seg_providers', this.store.providers.length)],
              selected: this.tab,
              onSelect: (i: number) => {
                this.tab = i;
              }
            })
              .margin({ bottom: 6 })
          }
          Row({ space: 6 }) {
            SearchBox({
              pal: this.store.palette(), dense: true,
              value: this.query,
              placeholder: this.tab === 0 ? t('search_groups') : t('search_providers'),
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

            if (this.tab === 0) {
              RoundIconButton({
                pal: this.store.palette(), dense: true, icon: $r('sys.symbol.bolt'), onTap: () => {
                  this.store.testAllGroups();
                }
              })
            } else {
              RoundIconButton({
                pal: this.store.palette(), dense: true, icon: $r('sys.symbol.arrow_clockwise'), onTap: () => {
                  this.store.updateAllProviders();
                }
              })
            }
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
    .bindSheet(this.showSheet, this.groupSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      backgroundColor: this.store.palette().sheet,
      blurStyle: this.store.sheetBlur(),
      onDisappear: () => {
        this.showSheet = false;
      }
    })
  }
}
