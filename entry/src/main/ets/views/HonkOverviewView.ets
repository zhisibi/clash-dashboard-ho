import { Store } from '../common/Store';
import { Palette } from '../common/Theme';
import { JObj, Traffic, asNum, jArr, jGet, jNum, jObj, jStr } from '../common/Models';
import { fmtBytes, fmtDuration, fmtSpeed } from '../common/Format';
import { HeaderStatus, Legend, LineChart } from '../components/Widgets';
import { GlassHeader, headerGuess } from '../components/GlassHeader';
import { HonkCoreApi } from '../common/HonkCoreApi';
import { errMsg } from '../common/CoreApi';
import { t } from '../common/I18n';

class DegRow {
  component: string = '';
  code: string = '';
  message: string = '';
}

class ObRow {
  name: string = '';
  kind: string = '';
  note: string = '';
}

class QsGroup {
  id: string = '';
  name: string = '';
  currentId: string = '';
  currentName: string = '';
}

class QsMember {
  id: string = '';
  name: string = '';
  kind: string = '';
}

/**
 * 1.5.0: honk-mode overview. Same information as the standalone Honk panel's
 * overview (runtime state, CPU, outbounds, degradations, quick node switch),
 * drawn with this app's design system (palette, glass cards, widgets).
 * Live traffic / totals / memory ride the Store streams like the clash page.
 */
@ComponentV2({ freezeWhenInactive: true })
export struct HonkOverviewView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(1);
  private sc: Scroller = new Scroller();
  private timer: number = -1;
  private busy: boolean = false;
  private watch: number = -1;
  private lastTab: number = -1;
  private lastBackendKey: string = '';

  @Local cpuText: string = '-';
  @Local uptimeSec: number = 0;
  @Local lifeState: string = '';
  @Local connTcp: number = 0;
  @Local connUdp: number = 0;
  @Local degs: DegRow[] = [];
  @Local obs: ObRow[] = [];
  @Local lastReload: string = '';
  @Local rtError: string = '';

  @Local qsGroups: QsGroup[] = [];
  @Local showQs: boolean = false;
  @Local qsTitle: string = '';
  @Local qsMembers: QsMember[] = [];
  @Local qsSelId: string = '';
  @Local qsCanSelect: boolean = false;
  @Local qsBusyId: string = '';
  private qsGroupId: string = '';
  private nameById: Map<string, string> = new Map<string, string>();

  aboutToAppear(): void {
    this.loadExtras();
    this.timer = setInterval(() => {
      this.loadExtras();
    }, 5000);
    // immediate refresh when this tab becomes active or the backend changes
    this.watch = setInterval(() => {
      const key = this.store.active !== null ? this.store.active.id : '';
      if (key !== this.lastBackendKey) {
        this.lastBackendKey = key;
        this.showQs = false;
        this.loadExtras();
        return;
      }
      if (this.store.tab === 0 && this.lastTab !== 0) {
        this.loadExtras();
      }
      this.lastTab = this.store.tab;
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.watch >= 0) {
      clearInterval(this.watch);
      this.watch = -1;
    }
  }

  private api(): HonkCoreApi | null {
    return this.store.honkApi();
  }

  private async loadExtras(): Promise<void> {
    const api = this.api();
    if (api === null || this.busy || this.store.connState !== 'connected') {
      return;
    }
    this.busy = true;
    try {
      const rt = await api.nRuntime('full');
      const life = jObj(rt, 'lifecycle');
      this.lifeState = life !== undefined ? jStr(life, 'state') : '';
      this.uptimeSec = (life !== undefined ? jNum(life, 'uptime_seconds') : 0) || jNum(rt, 'uptime_seconds');
      let proc = jObj(rt, 'process');
      if (proc === undefined) {
        proc = jObj(rt, 'system');
      }
      let cpu = proc !== undefined ? jGet(proc, 'cpu_percent') : undefined;
      if (cpu === undefined && proc !== undefined) {
        cpu = jGet(proc, 'cpu_usage_percent');
      }
      if (cpu === undefined) {
        cpu = jGet(rt, 'cpu_percent');
      }
      this.cpuText = cpu === undefined ? '-' : asNum(cpu).toFixed(1) + '%';
      const traffic = jObj(rt, 'traffic');
      let conns = traffic !== undefined ? jObj(traffic, 'connections') : undefined;
      if (conns === undefined) {
        conns = jObj(rt, 'connections');
      }
      this.connTcp = conns !== undefined ? jNum(conns, 'tcp') : 0;
      this.connUdp = conns !== undefined ? jNum(conns, 'udp') : 0;
      if (this.connTcp === 0 && this.connUdp === 0 && conns !== undefined) {
        this.connTcp = jNum(conns, 'total') || jNum(conns, 'active');
      }
      const degs: DegRow[] = [];
      const degArr = jArr(rt, 'degradations');
      if (degArr !== undefined) {
        for (const e of degArr) {
          const d = e as JObj;
          const row = new DegRow();
          row.component = jStr(d, 'component');
          row.code = jStr(d, 'code');
          row.message = jStr(d, 'message');
          degs.push(row);
        }
      }
      this.degs = degs;
      const lr = jObj(rt, 'last_reload');
      this.lastReload = lr !== undefined ? jStr(lr, 'status') : '';
      this.rtError = '';
      await this.loadOutbounds(api);
      await this.loadQs(api);
    } catch (e) {
      this.rtError = errMsg(e as Object);
    }
    this.busy = false;
  }

  private async loadOutbounds(api: HonkCoreApi): Promise<void> {
    try {
      const root = await api.nOutbounds();
      const arr = jArr(root, 'outbounds');
      const rows: ObRow[] = [];
      if (arr !== undefined) {
        for (const e of arr) {
          const o = e as JObj;
          const row = new ObRow();
          row.name = jStr(o, 'name') || jStr(o, 'id');
          row.kind = jStr(o, 'kind') || jStr(o, 'type');
          const active = jNum(o, 'active_connections');
          const up = jNum(o, 'upload_bytes');
          const down = jNum(o, 'download_bytes');
          row.note = (active > 0 ? active + ' conn' : '') +
            (up + down > 0 ? ' · ↓' + fmtBytes(down) + ' ↑' + fmtBytes(up) : '');
          rows.push(row);
        }
      }
      this.obs = rows;
    } catch (e) {
      // outbounds are best-effort
    }
  }

  private async loadQs(api: HonkCoreApi): Promise<void> {
    try {
      const nodes = await api.nNodes();
      const map = new Map<string, string>();
      for (const n of nodes) {
        map.set(jStr(n, 'id'), jStr(n, 'name'));
      }
      const groups = await api.nGroups();
      for (const g of groups) {
        map.set(jStr(g, 'id'), jStr(g, 'name'));
      }
      this.nameById = map;
      const out: QsGroup[] = [];
      for (const g of groups) {
        const pol = jObj(g, 'policy');
        const kind = pol !== undefined ? (jStr(pol, 'kind') || jStr(pol, 'native')) : '';
        if (kind !== 'selector') {
          continue;
        }
        const q = new QsGroup();
        q.id = jStr(g, 'id');
        q.name = jStr(g, 'name');
        const sel = jObj(g, 'selection');
        q.currentId = sel !== undefined ? jStr(sel, 'tcp_member_id') : '';
        // the list selection is the config value; the live one is in the
        // group detail's runtime.selection (they diverge after a switch)
        try {
          const d = await api.nGroupDetail(q.id);
          const rt = jObj(d, 'runtime');
          const rsel = rt !== undefined ? jObj(rt, 'selection') : undefined;
          const tcp = rsel !== undefined ? jObj(rsel, 'tcp') : undefined;
          const live = tcp !== undefined ? jStr(tcp, 'member_id') : '';
          if (live !== '') {
            q.currentId = live;
          }
        } catch (e) {
          // keep the list value
        }
        const nm = this.nameById.get(q.currentId);
        q.currentName = nm !== undefined ? nm : q.currentId;
        out.push(q);
      }
      this.qsGroups = out;
    } catch (e) {
      // quick switch is best-effort
    }
  }

  private async openQs(g: QsGroup): Promise<void> {
    const api = this.api();
    if (api === null) {
      return;
    }
    this.qsGroupId = g.id;
    this.qsTitle = g.name;
    this.qsMembers = [];
    this.qsSelId = '';
    this.qsCanSelect = false;
    this.showQs = true;
    try {
      const d = await api.nGroupDetail(g.id);
      const members: QsMember[] = [];
      const arr = jArr(d, 'members');
      if (arr !== undefined) {
        for (const e of arr) {
          const m = e as JObj;
          const row = new QsMember();
          row.id = jStr(m, 'id');
          row.name = jStr(m, 'name');
          row.kind = jStr(m, 'kind');
          members.push(row);
        }
      }
      this.qsMembers = members;
      const rt = jObj(d, 'runtime');
      const rsel = rt !== undefined ? jObj(rt, 'selection') : undefined;
      const tcp = rsel !== undefined ? jObj(rsel, 'tcp') : undefined;
      this.qsSelId = tcp !== undefined ? jStr(tcp, 'member_id') : '';
      const caps = jObj(d, 'capabilities');
      this.qsCanSelect = caps !== undefined &&
        (caps['can_select'] === true || caps['can_override'] === true);
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
  }

  private async qsSelect(m: QsMember): Promise<void> {
    const api = this.api();
    if (api === null || this.qsBusyId !== '') {
      return;
    }
    this.qsBusyId = m.id;
    try {
      await api.nSelect(this.qsGroupId, m.id);
      this.store.toast(t('act_ok', t('honk_switch')));
      this.showQs = false;
      this.store.refreshProxies();
      await this.loadQs(api);
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
    this.qsBusyId = '';
  }

  private peak(): number {
    let p = 0;
    for (const x of this.store.trafficHistory) {
      p = Math.max(p, x.up, x.down);
    }
    return p;
  }

  @Builder
  statCell(title: string, value: string, color: string) {
    Column() {
      Text(title).fontSize(12).fontColor(this.store.palette().subtle)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(value).fontSize(17).fontWeight(FontWeight.Medium)
        .fontColor(color !== '' ? color : this.store.palette().text)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 3 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  qsSheet() {
    Column() {
      Text(this.qsTitle)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.store.palette().text)
        .margin({ top: 14, bottom: 4 })
      if (!this.qsCanSelect && this.qsMembers.length > 0) {
        Text(t('group_not_selectable', this.qsTitle))
          .fontSize(13)
          .fontColor(this.store.palette().warn)
          .margin({ bottom: 6 })
      }
      List() {
        ForEach(this.qsMembers, (m: QsMember) => {
          ListItem() {
            Row() {
              Text(m.kind === 'group' ? t('honk_groups') : t('honk_nodes'))
                .fontSize(10)
                .fontColor(this.store.palette().subtle)
                .backgroundColor(this.store.palette().chip)
                .borderRadius(5)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              Text(m.name)
                .fontSize(15)
                .fontColor(this.store.palette().text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
                .margin({ left: 8 })
              if (m.id === this.qsSelId) {
                Text('●')
                  .fontSize(13)
                  .fontColor(this.store.palette().good)
              } else if (this.qsBusyId === m.id) {
                LoadingProgress().width(16).height(16).color(this.store.palette().accentUi)
              }
            }
            .width('100%')
            .padding({ top: 13, bottom: 13, left: 4, right: 4 })
            .onClick(() => {
              if (this.qsCanSelect && m.id !== this.qsSelId) {
                this.qsSelect(m);
              }
            })
          }
        }, (m: QsMember) => m.id)
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0.5, color: this.store.palette().outlineVariant })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.sc) {
        Column({ space: 12 }) {
          if (this.store.connState !== 'connected') {
            Column() {
              Text(t('not_connected')).fontSize(15).fontColor(this.store.palette().subtle)
              if (this.store.connError.length > 0) {
                Text(this.store.connError).fontSize(13).fontColor(this.store.palette().bad)
                  .margin({ top: 6 })
              }
            }
            .width('100%')
            .padding(16)
            .borderRadius(18)
            .attributeModifier(this.store.glass('card'))
          } else {
            // status stats
            Column({ space: 14 }) {
              Row() {
                this.statCell(t('upload'), fmtSpeed(this.store.traffic.up), this.store.palette().upText)
                this.statCell(t('download'), fmtSpeed(this.store.traffic.down), this.store.palette().downText)
                this.statCell(t('honk_conns'), (this.connTcp + this.connUdp).toString(), '')
              }
              .width('100%')
              Row() {
                this.statCell(t('honk_total_up'), fmtBytes(this.store.connTotalUp), '')
                this.statCell(t('honk_total_down'), fmtBytes(this.store.connTotalDown), '')
                this.statCell(t('honk_memory'), this.store.memory > 0 ? fmtBytes(this.store.memory) : '-', '')
              }
              .width('100%')
              Row() {
                this.statCell('CPU', this.cpuText, '')
                this.statCell(t('honk_uptime'), this.uptimeSec > 0 ? fmtDuration(this.uptimeSec * 1000) : '-', '')
                this.statCell(t('version'), this.store.version.replace('honk ', ''), '')
              }
              .width('100%')
              if (this.rtError.length > 0) {
                Text(this.rtError).fontSize(12).fontColor(this.store.palette().bad)
              }
            }
            .width('100%')
            .padding(16)
            .borderRadius(18)
            .attributeModifier(this.store.glass('card'))

            // live chart
            Column() {
              Row() {
                Text(t('live_speed')).fontSize(16).fontWeight(FontWeight.Medium)
                  .fontColor(this.store.palette().text).layoutWeight(1)
                Legend({ pal: this.store.palette(), color: this.store.palette().up, label: t('upload') })
                Legend({ pal: this.store.palette(), color: this.store.palette().down, label: t('download') })
                Text(t('peak', fmtSpeed(this.peak()))).fontSize(12).fontColor(this.store.palette().subtle)
              }
              .width('100%')
              .margin({ bottom: 8 })
              LineChart({
                series: [
                  this.store.trafficHistory.map((x: Traffic) => x.down),
                  this.store.trafficHistory.map((x: Traffic) => x.up)
                ],
                colors: [this.store.palette().down, this.store.palette().up],
                grid: this.store.palette().outlineVariant,
                chartHeight: 80,
                mirror: true,
                bars: true
              })
            }
            .width('100%')
            .padding(14)
            .borderRadius(18)
            .attributeModifier(this.store.glass('card'))

            // quick switch
            if (this.qsGroups.length > 0) {
              Column() {
                Text(t('honk_quick_switch')).fontSize(16).fontWeight(FontWeight.Medium)
                  .fontColor(this.store.palette().text)
                  .margin({ bottom: 6 })
                ForEach(this.qsGroups, (g: QsGroup) => {
                  Row() {
                    Column() {
                      Text(g.name).fontSize(15).fontColor(this.store.palette().text)
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(g.currentName).fontSize(12).fontColor(this.store.palette().good)
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: 2 })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([this.store.palette().subtle])
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                  .onClick(() => {
                    this.openQs(g);
                  })
                }, (g: QsGroup) => g.id)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .borderRadius(18)
              .attributeModifier(this.store.glass('card'))
              .bindSheet(this.showQs, this.qsSheet(), {
                height: SheetSize.LARGE,
                dragBar: true,
                backgroundColor: this.store.palette().sheet,
                onDisappear: () => {
                  this.showQs = false;
                }
              })
            }

            // outbounds
            if (this.obs.length > 0) {
              Column() {
                Text(t('honk_outbounds')).fontSize(16).fontWeight(FontWeight.Medium)
                  .fontColor(this.store.palette().text)
                  .margin({ bottom: 6 })
                ForEach(this.obs, (o: ObRow) => {
                  Row() {
                    Text(o.name).fontSize(14).fontColor(this.store.palette().text)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                    if (o.kind !== '') {
                      Text(o.kind).fontSize(11).fontColor(this.store.palette().subtle)
                        .backgroundColor(this.store.palette().chip)
                        .borderRadius(5)
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                    }
                    if (o.note !== '') {
                      Text(o.note).fontSize(12).fontColor(this.store.palette().subtle)
                        .margin({ left: 6 })
                    }
                  }
                  .width('100%')
                  .padding({ top: 6, bottom: 6 })
                }, (o: ObRow) => o.name)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .borderRadius(18)
              .attributeModifier(this.store.glass('card'))
            }

            // degradations
            if (this.degs.length > 0) {
              Column() {
                Text(t('honk_degradations') + ' (' + this.degs.length + ')')
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.store.palette().warn)
                  .margin({ bottom: 6 })
                ForEach(this.degs, (d: DegRow) => {
                  Text((d.component !== '' ? d.component + ' · ' : '') + d.message)
                    .fontSize(13)
                    .fontColor(this.store.palette().text)
                    .padding({ top: 3, bottom: 3 })
                }, (d: DegRow) => d.component + d.code)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .borderRadius(18)
              .attributeModifier(this.store.glass('card'))
            }

            // reload
            Row() {
              Text(t('honk_reload')).fontSize(15).fontColor(this.store.palette().text).layoutWeight(1)
              if (this.lastReload !== '') {
                Text(this.lastReload).fontSize(12).fontColor(this.store.palette().subtle)
                  .margin({ right: 10 })
              }
              Button(t('honk_reload'))
                .height(38)
                .fontSize(13)
                .fontColor(this.store.palette().text)
                .backgroundColor(this.store.palette().chip)
                .onClick(() => {
                  const api = this.api();
                  if (api !== null) {
                    api.nReload().then(() => {
                      this.store.toast(t('act_ok', t('honk_reload')));
                      this.store.refreshAll();
                    }).catch((e: Object) => {
                      this.store.toast(errMsg(e));
                    });
                  }
                })
            }
            .width('100%')
            .padding(16)
            .borderRadius(18)
            .attributeModifier(this.store.glass('card'))
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: this.headerH + 8, bottom: this.bottomPad })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onDidScroll((x: number, y: number, st: ScrollState) => {
        this.store.navScroll(this.sc, y, st);
      })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })

      GlassHeader({
        hPad: 20, onHeight: (h: number) => {
          this.headerH = h;
        }
      }) {
        HeaderStatus({
          pal: this.store.palette(),
          title: t('tab_overview'),
          connState: this.store.connState,
          address: this.store.active !== null ? this.store.active.display() : t('not_connected'),
          tag: this.store.version
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.store.palette().bg)
  }
}
