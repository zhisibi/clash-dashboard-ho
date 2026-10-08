import { Store } from '../common/Store';
import { PullRefresh } from '../components/PullRefresh';
import { GlassHeader, headerGuess } from '../components/GlassHeader';
import { ConnItem } from '../common/Models';
import { fmtBytes, fmtClock, fmtDuration, fmtSpeed, safeRegex, textMatch } from '../common/Format';
import { DropdownChip, EmptyCard, RoundIconButton, SearchBox, SegTabs, Tag } from '../components/Widgets';
import { isEn, t } from '../common/I18n';

const SORT_KEYS: string[] = ['host', 'start', 'download', 'upload', 'downloadSpeed', 'uploadSpeed', 'rule', 'chains',
  'process', 'source', 'type'];
/** i18n keys of the sort options (same order as SORT_KEYS) */
const SORT_LABELS: string[] = ['cs_host', 'cs_start', 'cs_download', 'cs_upload', 'cs_dlspeed', 'cs_ulspeed', 'cs_rule',
  'cs_chains', 'cs_process', 'cs_source', 'cs_type'];

function sortLabels(): string[] {
  return SORT_LABELS.map((k: string) => t(k));
}

class KV {
  k: string = '';
  v: string = '';

  constructor(k: string, v: string) {
    this.k = k;
    this.v = v;
  }
}

function sortKey(c: ConnItem, s: string): string | number {
  switch (s) {
    case 'host':
      return c.meta.displayHost();
    case 'download':
      return c.download;
    case 'upload':
      return c.upload;
    case 'downloadSpeed':
      return c.downloadSpeed;
    case 'uploadSpeed':
      return c.uploadSpeed;
    case 'rule':
      return c.rule + c.rulePayload;
    case 'chains':
      return c.chains.join(',');
    case 'process':
      return c.meta.process;
    case 'source':
      return c.meta.sourceIP;
    case 'type':
      return c.meta.type + c.meta.network;
    default:
      return c.startMillis;
  }
}

function cmp(a: string | number, b: string | number): number {
  if (typeof a === 'number' && typeof b === 'number') {
    return (a as number) - (b as number);
  }
  return String(a).localeCompare(String(b));
}

@ComponentV2
struct ConnCard {
  private store: Store = Store.get();
  @Param conn: ConnItem = new ConnItem();
  @Param compact: boolean = false;
  @Event onOpen: () => void = () => {
  };

  build() {
    Column() {
      Row() {
        Text(this.conn.meta.displayHost() + ':' + this.conn.meta.destinationPort)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.conn.closedAt === 0) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([this.store.palette().subtle])
            .onClick(() => {
              this.store.closeConn(this.conn.id);
            })
        }
      }
      .width('100%')

      Row() {
        Tag({ pal: this.store.palette(), text: this.conn.meta.type + '|' + this.conn.meta.network.toUpperCase() })
        Text(this.conn.chains.slice().reverse().join(' → '))
          .fontSize(13)
          .fontColor(this.store.palette().text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 6 })
      }
      .width('100%')
      .margin({ top: 4 })

      if (!this.compact) {
        Text((this.conn.rulePayload.length > 0 ? this.conn.rule + ': ' + this.conn.rulePayload : this.conn.rule) +
          (this.conn.meta.process.length > 0 ? ' · ' + this.conn.meta.process : '') +
          (this.conn.meta.sourceIP.length > 0 ? ' · ' + this.conn.meta.sourceIP : ''))
          .fontSize(12)
          .fontColor(this.store.palette().subtle)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })
        Row() {
          Text('↑ ' + fmtBytes(this.conn.upload) +
            (this.conn.uploadSpeed > 0 ? ' (' + fmtSpeed(this.conn.uploadSpeed) + ')' : ''))
            .fontSize(12)
            .fontColor(this.store.palette().upText)
          Text('↓ ' + fmtBytes(this.conn.download) +
            (this.conn.downloadSpeed > 0 ? ' (' + fmtSpeed(this.conn.downloadSpeed) + ')' : ''))
            .fontSize(12)
            .fontColor(this.store.palette().downText)
            .margin({ left: 10 })
          Blank()
          Text(fmtDuration((this.conn.closedAt > 0 ? this.conn.closedAt : Date.now()) - this.conn.startMillis))
            .fontSize(12)
            .fontColor(this.store.palette().subtle)
        }
        .width('100%')
        .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: this.compact ? 8 : 12, bottom: this.compact ? 8 : 12 })
    .borderRadius(18)
    .attributeModifier(Store.get().glass('row'))
    .onClick(() => {
      this.onOpen();
    })
  }
}

@ComponentV2
struct ConnDetail {
  private store: Store = Store.get();
  @Param conn: ConnItem = new ConnItem();
  @Event onDone: () => void = () => {
  };

  rows(): KV[] {
    const c = this.conn;
    const all: KV[] = [
      new KV(t('kv_host'), c.meta.host), new KV(t('kv_sniff'), c.meta.sniffHost),
      new KV(t('kv_dst_ip'), c.meta.destinationIP), new KV(t('kv_dst_port'), c.meta.destinationPort),
      new KV(t('kv_remote'), c.meta.remoteDestination),
      new KV(t('kv_source'), c.meta.sourceIP + ':' + c.meta.sourcePort), new KV(t('kv_inbound'), c.meta.inboundName),
      new KV(t('kv_inbound_user'), c.meta.inboundUser), new KV(t('kv_type'), c.meta.type + ' / ' + c.meta.network),
      new KV(t('kv_dns'), c.meta.dnsMode), new KV(t('kv_process'), c.meta.process),
      new KV(t('kv_process_path'), c.meta.processPath),
      new KV('UID', c.meta.uid), new KV(t('kv_rule'), c.rule), new KV(t('kv_rule_payload'), c.rulePayload),
      new KV(t('kv_chains'), c.chains.slice().reverse().join(' → ')), new KV(t('kv_upload'), fmtBytes(c.upload)),
      new KV(t('kv_download'), fmtBytes(c.download)),
      new KV(t('kv_start'), c.startMillis > 0 ? fmtClock(c.startMillis) : ''),
      new KV('ID', c.id)
    ];
    return all.filter((kv: KV) => kv.v.trim().length > 0 && kv.v !== ':');
  }

  build() {
    Column() {
      Row() {
        Text(t('conn_detail')).fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.conn.closedAt === 0) {
          Button(t('close'), { type: ButtonType.Capsule })
            .fontColor(this.store.palette().onPrimary)
            .backgroundColor(this.store.palette().primary)
            .onClick(() => {
              this.store.closeConn(this.conn.id);
              this.onDone();
            })
        }
      }
      .width('100%')
      .margin({ bottom: 10 })

      Scroll() {
        Column() {
          ForEach(this.rows(), (kv: KV) => {
            Row() {
              Text(kv.k).fontSize(13).fontColor(this.store.palette().subtle).width(isEn() ? 104 : 84).maxLines(2)
                .margin({ right: 6 })
              Text(kv.v)
                .fontSize(13)
                .fontColor(this.store.palette().text)
                .layoutWeight(1)
                .copyOption(CopyOptions.LocalDevice)
                .fontFamily(kv.k === 'ID' ? 'monospace' : 'HarmonyOS Sans')
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .padding({ top: 5, bottom: 5 })
          }, (kv: KV) => kv.k)
        }
        .padding(14)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .borderRadius(18)
      .attributeModifier(Store.get().glass('row'))
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, bottom: 24 })
    .backgroundColor(this.store.palette().sheet)
  }
}

// Frozen while not the current page (hidden TabContent); latest data applies on return, page state is kept
@ComponentV2({ freezeWhenInactive: true })
export struct ConnectionsView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(3);
  private sc: Scroller = new Scroller();
  @Local tab: number = 0;
  @Local query: string = '';
  @Local sourceFilter: string = '';
  @Local compact: boolean = false;
  @Local detail: ConnItem = new ConnItem();
  @Local showDetail: boolean = false;

  base(): ConnItem[] {
    if (this.tab === 0) {
      return this.store.activeConns;
    }
    if (this.tab === 1) {
      return this.store.closedConns;
    }
    return this.store.activeConns.concat(this.store.closedConns);
  }

  sources(): string[] {
    const set = new Set<string>();
    for (const c of this.store.activeConns) {
      if (c.meta.sourceIP.length > 0) {
        set.add(c.meta.sourceIP);
      }
    }
    for (const c of this.store.closedConns) {
      if (c.meta.sourceIP.length > 0) {
        set.add(c.meta.sourceIP);
      }
    }
    const arr: string[] = [];
    set.forEach((s: string) => {
      arr.push(s);
    });
    arr.sort((a: string, b: string) => a.localeCompare(b));
    return arr;
  }

  list(): ConnItem[] {
    const re = safeRegex(this.query);
    const filtered = this.base().filter((c: ConnItem) => {
      if (this.sourceFilter.length > 0 && c.meta.sourceIP !== this.sourceFilter) {
        return false;
      }
      if (this.query.trim().length === 0) {
        return true;
      }
      const hay = [c.meta.displayHost(), c.meta.destinationIP, c.meta.sourceIP, c.rule, c.rulePayload,
        c.chains.join(' '), c.meta.process, c.meta.network, c.meta.type].join(' ');
      return textMatch(re, this.query, hay);
    });
    const s = this.store.connSort;
    const desc = this.store.connSortDesc;
    filtered.sort((a: ConnItem, b: ConnItem) => {
      const r = cmp(sortKey(a, s), sortKey(b, s));
      return desc ? -r : r;
    });
    return filtered;
  }

  sortIndex(): number {
    return Math.max(0, SORT_KEYS.indexOf(this.store.connSort));
  }

  confirmClose(list: ConnItem[]): void {
    const ui = this.getUIContext();
    const filtered = this.query.trim().length > 0 || this.sourceFilter.length > 0;
    ui.showAlertDialog({
      title: filtered ? t('close_filtered_q', list.length) : t('close_all_q'),
      message: '',
      autoCancel: true,
      primaryButton: {
        value: t('cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: t('close'),
        fontColor: this.store.palette().bad,
        action: () => {
          if (filtered) {
            this.store.closeConns(list.filter((c: ConnItem) => c.closedAt === 0).map((c: ConnItem) => c.id));
          } else {
            this.store.closeAll();
          }
        }
      }
    });
  }

  @Builder
  detailSheet() {
    ConnDetail({
      conn: this.detail, onDone: () => {
        this.showDetail = false;
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      PullRefresh({ topInset: this.headerH, page: 'connections' }) {
        if (this.list().length === 0) {
          // 1.2.2: empty state sits in a full-size Scroll so it still bounces (and pulls to refresh)
          Scroll() {
            Column() {
              EmptyCard({ pal: this.store.palette() })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: this.headerH + 6 })
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        } else {
          List({ space: this.compact ? 6 : 10, scroller: this.sc }) {
            Repeat<ConnItem>(this.list())
              .each((ri: RepeatItem<ConnItem>) => {
                ListItem() {
                  ConnCard({
                    conn: ri.item,
                    compact: this.compact,
                    onOpen: () => {
                      this.detail = ri.item;
                      this.showDetail = true;
                    }
                  })
                }
              })
              .key((c: ConnItem) => c.id + '_' + c.closedAt + '_' + c.upload + '_' + c.download + '_' + c.uploadSpeed + '_' +
              c.downloadSpeed)
              .virtualScroll()
          }
          .padding({ left: 14, right: 14, top: this.headerH + 4, bottom: this.bottomPad + 14 })
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
      }

      GlassHeader({
        onHeight: (h: number) => {
          this.headerH = h;
        }
      }) {
        Column({ space: 6 }) {
          // First row: segments + up/down totals (compact, on the right)
          Row() {
            SegTabs({
              pal: this.store.palette(),
              dense: true,
              items: [t('seg_active', this.store.activeConns.length), t('seg_closed', this.store.closedConns.length), t('seg_all')],
              selected: this.tab,
              onSelect: (i: number) => {
                this.tab = i;
              }
            })
              .flexShrink(0)
            Blank().layoutWeight(1)
            Column() {
              Text('↑ ' + fmtBytes(this.store.connTotalUp))
                .fontSize(11)
                .maxLines(1)
                .fontColor(this.store.palette().upText)
              Text('↓ ' + fmtBytes(this.store.connTotalDown))
                .fontSize(11)
                .maxLines(1)
                .fontColor(this.store.palette().downText)
            }
            .alignItems(HorizontalAlign.End)
            .flexShrink(1)
            .margin({ left: 6 })
          }
          .width('100%')

          Row({ space: 6 }) {
            DropdownChip({
              pal: this.store.palette(),
              dense: true,
              label: sortLabels()[this.sortIndex()],
              options: sortLabels(),
              onSelect: (i: number) => {
                this.store.setConnSort(SORT_KEYS[i], this.store.connSortDesc);
              }
            })
              .layoutWeight(1)
            Text(t('n_items', this.list().length))
              .fontSize(11)
              .maxLines(1)
              .fontColor(this.store.palette().subtle)
            RoundIconButton({
              pal: this.store.palette(),
              dense: true,
              icon: this.store.connSortDesc ? $r('sys.symbol.arrow_down') : $r('sys.symbol.arrow_up'),
              onTap: () => {
                this.store.setConnSort(this.store.connSort, !this.store.connSortDesc);
              }
            })
            RoundIconButton({
              pal: this.store.palette(),
              dense: true,
              icon: this.compact ? $r('sys.symbol.line_3_horizontal') : $r('sys.symbol.list_bullet'),
              active: this.compact,
              onTap: () => {
                this.compact = !this.compact;
              }
            })
            RoundIconButton({
              pal: this.store.palette(),
              dense: true,
              icon: this.store.connsPaused ? $r('sys.symbol.play') : $r('sys.symbol.pause'),
              active: this.store.connsPaused,
              onTap: () => {
                this.store.connsPaused = !this.store.connsPaused;
              }
            })
            RoundIconButton({
              pal: this.store.palette(),
              dense: true,
              icon: this.tab === 1 ? $r('sys.symbol.trash') : $r('sys.symbol.xmark'),
              onTap: () => {
                if (this.tab === 1) {
                  this.store.clearClosed();
                } else {
                  this.confirmClose(this.list());
                }
              }
            })
          }
          .width('100%')

          Row({ space: 6 }) {
            DropdownChip({
              pal: this.store.palette(),
              dense: true,
              label: this.sourceFilter.length === 0 ? t('all_sources') : this.sourceFilter,
              options: [t('all')].concat(this.sources()),
              chipWidth: 128,
              onSelect: (i: number) => {
                this.sourceFilter = i === 0 ? '' : this.sources()[i - 1];
              }
            })
            SearchBox({
              pal: this.store.palette(),
              dense: true,
              value: this.query,
              placeholder: t('search_regex'),
              onChange: (v: string) => {
                this.query = v;
              }
            })
              .layoutWeight(1)
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
    .bindSheet(this.showDetail, this.detailSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      backgroundColor: this.store.palette().sheet,
      blurStyle: this.store.sheetBlur(),
      onDisappear: () => {
        this.showDetail = false;
      }
    })
  }
}
