import { Store } from '../common/Store';
import { Palette } from '../common/Theme';
import { ProxyItem, Traffic } from '../common/Models';
import { fmtBytes, fmtSpeed, modeName } from '../common/Format';
import { HeaderStatus, Legend, LineChart, SegTabs } from '../components/Widgets';
import { PullRefresh } from '../components/PullRefresh';
import { GlassHeader, headerGuess } from '../components/GlassHeader';
import { t } from '../common/I18n';

class HostStat {
  host: string = '';
  bytes: number = 0;
  count: number = 0;
}

@ComponentV2
struct BigStat {
  @Param pal: Palette = new Palette();
  @Param title: string = '';
  @Param value: string = '';
  @Param icon: Resource = $r('sys.symbol.arrow_up');
  @Param color: string = '';

  build() {
    Column() {
      Row() {
        SymbolGlyph(this.icon).fontSize(16).fontColor([this.color.length > 0 ? this.color : this.pal.subtle])
        Text(this.title).fontSize(13).fontColor(this.pal.subtle).margin({ left: 6 })
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      }
      .width('100%')

      Text(this.value)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .fontColor(this.color.length > 0 ? this.color : this.pal.text)
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(18)
    .attributeModifier(Store.get().glass('card'))
  }
}

// Frozen while not the current page (hidden TabContent); latest data applies on return, page state is kept
@ComponentV2({ freezeWhenInactive: true })
export struct OverviewView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(1);
  private sc: Scroller = new Scroller();

  topHosts(): HostStat[] {
    const m = new Map<string, HostStat>();
    for (const c of this.store.activeConns) {
      const h = c.meta.displayHost();
      let s = m.get(h);
      if (s === undefined) {
        s = new HostStat();
        s.host = h;
        m.set(h, s);
      }
      s.bytes += c.download + c.upload;
      s.count += 1;
    }
    const arr: HostStat[] = [];
    m.forEach((v: HostStat) => {
      arr.push(v);
    });
    arr.sort((a: HostStat, b: HostStat) => b.bytes - a.bytes);
    return arr.slice(0, 6);
  }

  peak(): number {
    let p = 0;
    for (const tr of this.store.trafficHistory) {
      p = Math.max(p, tr.up, tr.down);
    }
    return p;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      PullRefresh({ topInset: this.headerH, page: 'overview' }) {
        Scroll(this.sc) {
          Column({ space: 12 }) {
            // quick mode switch
            Row() {
              Text(t('proxy_mode')).fontSize(16).fontColor(this.store.palette().text).layoutWeight(1)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              SegTabs({
                pal: this.store.palette(),
                items: this.store.config.modes.map((m: string) => modeName(m)),
                selected: Math.max(0, this.store.config.modes.indexOf(this.store.config.mode)),
                onSelect: (i: number) => {
                  this.store.setMode(this.store.config.modes[i]);
                }
              })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .borderRadius(18)
            .attributeModifier(Store.get().glass('card'))

            Row({ space: 12 }) {
              BigStat({
                pal: this.store.palette(), title: t('upload'), value: fmtSpeed(this.store.traffic.up),
                icon: $r('sys.symbol.arrow_up'), color: this.store.palette().up
              })
              BigStat({
                pal: this.store.palette(), title: t('download'), value: fmtSpeed(this.store.traffic.down),
                icon: $r('sys.symbol.arrow_down'), color: this.store.palette().down
              })
            }

            Row({ space: 12 }) {
              BigStat({
                pal: this.store.palette(), title: t('upload_total'), value: fmtBytes(this.store.connTotalUp),
                icon: $r('sys.symbol.arrow_up_icloud'), color: ''
              })
              BigStat({
                pal: this.store.palette(), title: t('download_total'), value: fmtBytes(this.store.connTotalDown),
                icon: $r('sys.symbol.cloud_and_arrow_down'), color: ''
              })
            }

            Row({ space: 12 }) {
              BigStat({
                pal: this.store.palette(), title: t('active_conns'), value: this.store.activeConns.length.toString(),
                icon: $r('sys.symbol.link'), color: ''
              })
              BigStat({
                pal: this.store.palette(), title: t('memory_usage'), value: fmtBytes(this.store.memory),
                icon: $r('sys.symbol.memory_module'), color: ''
              })
            }

            // speed chart
            Column() {
              Row() {
                Text(t('live_speed')).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
                  .layoutWeight(1)
                Text(t('peak', fmtSpeed(this.peak()))).fontSize(12).fontColor(this.store.palette().subtle)
              }
              .width('100%')
              .margin({ bottom: 10 })

              LineChart({
                series: [
                  this.store.trafficHistory.map((x: Traffic) => x.up),
                  this.store.trafficHistory.map((x: Traffic) => x.down)
                ],
                colors: [this.store.palette().up, this.store.palette().down],
                grid: this.store.palette().outlineVariant,
                chartHeight: 160
              })
              Row() {
                Legend({ pal: this.store.palette(), color: this.store.palette().up, label: t('upload') })
                Legend({ pal: this.store.palette(), color: this.store.palette().down, label: t('download') })
              }
              .width('100%')
              .margin({ top: 8 })
            }
            .width('100%')
            .padding(16)
            .borderRadius(18)
            .attributeModifier(Store.get().glass('card'))

            // memory chart
            Column() {
              Row() {
                Text(t('memory')).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
                  .layoutWeight(1)
                Text(fmtBytes(this.store.memory)).fontSize(12).fontColor(this.store.palette().subtle)
              }
              .width('100%')
              .margin({ bottom: 10 })

              LineChart({
                series: [this.store.memoryHistory.slice()],
                colors: [this.store.palette().primary],
                grid: this.store.palette().outlineVariant,
                chartHeight: 110
              })
            }
            .width('100%')
            .padding(16)
            .borderRadius(18)
            .attributeModifier(Store.get().glass('card'))

            // top hosts by traffic
            if (this.topHosts().length > 0) {
              Column() {
                Text(t('top_hosts')).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
                  .margin({ bottom: 8 })
                ForEach(this.topHosts(), (h: HostStat) => {
                  Column() {
                    Row() {
                      Text(h.host)
                        .fontSize(14)
                        .fontColor(this.store.palette().text)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      Text(fmtBytes(h.bytes) + ' · ' + h.count).fontSize(12).fontColor(this.store.palette().subtle)
                    }
                    .width('100%')

                    Progress({
                      value: h.bytes,
                      total: Math.max(1, this.topHosts()[0].bytes),
                      type: ProgressType.Linear
                    })
                      .color(this.store.palette().down)
                      .backgroundColor(this.store.palette().chip)
                      .style({ strokeWidth: 5 })
                      .width('100%')
                      .margin({ top: 4 })
                  }
                  .padding({ top: 5, bottom: 5 })
                }, (h: HostStat) => h.host + '_' + h.bytes + '_' + h.count)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .borderRadius(18)
              .attributeModifier(Store.get().glass('card'))
            }

            Row({ space: 12 }) {
              BigStat({
                pal: this.store.palette(), title: t('proxy_groups'),
                value: this.store.groups().filter((g: ProxyItem) => g.name !== 'GLOBAL').length.toString(),
                icon: $r('sys.symbol.paperplane'), color: ''
              })
              BigStat({
                pal: this.store.palette(), title: t('rules'), value: this.store.rules.length.toString(),
                icon: $r('sys.symbol.list_bullet'), color: ''
              })
            }
          }
          .padding({ left: 14, right: 14, top: this.headerH + 14, bottom: this.bottomPad + 14 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onDidScroll((x: number, y: number, st: ScrollState) => {
          this.store.navScroll(this.sc, y, st);
        })
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }

      GlassHeader({
        hPad: 20, onHeight: (h: number) => {
          this.headerH = h;
        }
      }) {
        HeaderStatus({
          pal: this.store.palette(),
          title: t('overview'),
          connState: this.store.connState,
          address: this.store.active !== null ? this.store.active.host + ':' + this.store.active.port : t('not_connected'),
          tag: this.store.version
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.store.palette().bg)
  }
}
