import { Store } from '../common/Store';
import { JObj, asNum, jArr, jBool, jGet, jNum, jObj, jStr } from '../common/Models';
import { fmtClock } from '../common/Format';
import { parseIsoMillis } from '../common/Models';
import { HeaderStatus, SegTabs } from '../components/Widgets';
import { GlassHeader, headerGuess } from '../components/GlassHeader';
import { HonkCoreApi } from '../common/HonkCoreApi';
import { errMsg } from '../common/CoreApi';
import { t } from '../common/I18n';

class GRow {
  id: string = '';
  name: string = '';
  kind: string = '';
  memberCount: number = 0;
  selName: string = '';
}

class MRow {
  id: string = '';
  name: string = '';
  kind: string = '';
  latency: number = -1;
  current: boolean = false;
}

class NRow {
  id: string = '';
  name: string = '';
  proto: string = '';
  provider: string = '';
  latency: number = -1;
  alive: boolean = true;
}

class PRow {
  id: string = '';
  name: string = '';
  kind: string = '';
  nodeCount: number = 0;
  updated: string = '';
  status: string = '';
  error: string = '';
}

function bestLatency(health: Object[] | undefined): number {
  if (health === undefined) {
    return -1;
  }
  let best = -1;
  for (const e of health) {
    const h = e as JObj;
    if (jStr(h, 'state') === 'healthy') {
      const v = jGet(h, 'latency_ms');
      if (typeof v === 'number') {
        const ms = v as number;
        if (best < 0 || ms < best) {
          best = ms;
        }
      }
    }
  }
  return best;
}

/**
 * 1.5.0: honk-mode proxies page = the standalone Honk panel's policy page
 * (groups / nodes / subscriptions with native selection and probing),
 * drawn with this app's design system.
 */
@ComponentV2({ freezeWhenInactive: true })
export struct HonkPolicyView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(1);
  private sc: Scroller = new Scroller();

  @Local tab: number = 0;
  @Local groups: GRow[] = [];
  @Local nodes: NRow[] = [];
  @Local providers: PRow[] = [];
  @Local loadError: string = '';
  @Local busyKey: string = '';

  // group detail (inline expansion)
  @Local openGroupId: string = '';
  @Local members: MRow[] = [];
  @Local detailSelId: string = '';
  @Local detailCanSelect: boolean = false;

  @Local nodeQuery: string = '';
  @Local probeDone: number = 0;
  @Local probeTotal: number = 0;
  @Local exitNodeId: string = '';
  @Local updatedOkId: string = '';

  private nameById: Map<string, string> = new Map<string, string>();
  private loaded: boolean = false;
  private timer: number = -1;
  private ticks: number = 0;
  private lastTab: number = -1;
  private lastBackendKey: string = '';

  aboutToAppear(): void {
    if (!this.loaded) {
      this.loaded = true;
      this.loadAll();
    }
    // sync watcher: reload at once when the backend changes or this tab
    // becomes active, and periodically while it stays active
    this.timer = setInterval(() => {
      this.watchTick();
    }, 2000);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private watchTick(): void {
    const key = this.store.active !== null ? this.store.active.id : '';
    if (key !== this.lastBackendKey) {
      this.lastBackendKey = key;
      this.openGroupId = '';
      this.members = [];
      this.loadAll();
      return;
    }
    const tab = this.store.tab;
    if (tab === 1 && this.lastTab !== 1) {
      this.lastTab = tab;
      this.loadAll();
      this.refreshOpenDetail();
      return;
    }
    this.lastTab = tab;
    this.ticks++;
    if (tab === 1 && this.ticks % 7 === 0 && this.busyKey === '') {
      this.loadAll();
      this.refreshOpenDetail();
    }
  }

  private refreshOpenDetail(): void {
    if (this.openGroupId === '') {
      return;
    }
    for (const g of this.groups) {
      if (g.id === this.openGroupId) {
        this.loadDetail(g);
        return;
      }
    }
  }

  private api(): HonkCoreApi | null {
    return this.store.honkApi();
  }

  private memberName(id: string): string {
    const n = this.nameById.get(id);
    return n !== undefined && n !== '' ? n : id;
  }

  private async loadAll(): Promise<void> {
    const api = this.api();
    if (api === null || this.store.connState !== 'connected') {
      return;
    }
    try {
      const gs = await api.nGroups();
      const ns = await api.nNodes();
      const ps = await api.nProviders();
      const map = new Map<string, string>();
      for (const n of ns) {
        map.set(jStr(n, 'id'), jStr(n, 'name'));
      }
      for (const g of gs) {
        map.set(jStr(g, 'id'), jStr(g, 'name'));
      }
      const provName = new Map<string, string>();
      for (const p of ps) {
        provName.set(jStr(p, 'id'), jStr(p, 'name'));
      }
      this.nameById = map;
      const grows: GRow[] = [];
      for (const g of gs) {
        const r = new GRow();
        r.id = jStr(g, 'id');
        r.name = jStr(g, 'name');
        const pol = jObj(g, 'policy');
        r.kind = pol !== undefined ? (jStr(pol, 'kind') || jStr(pol, 'native')) : '';
        r.memberCount = jNum(g, 'member_count');
        const sel = jObj(g, 'selection');
        const cur = sel !== undefined ? jStr(sel, 'tcp_member_id') : '';
        r.selName = cur !== '' ? this.memberName(cur) : '';
        grows.push(r);
      }
      this.groups = grows;
      // current exit node: the live runtime selection of selector groups
      // (list selection is the config value and goes stale after a switch)
      let exitId = '';
      for (const g of grows) {
        if (g.kind !== 'selector') {
          continue;
        }
        try {
          const d = await api.nGroupDetail(g.id);
          const rt = jObj(d, 'runtime');
          const rsel = rt !== undefined ? jObj(rt, 'selection') : undefined;
          const tcp = rsel !== undefined ? jObj(rsel, 'tcp') : undefined;
          const live = tcp !== undefined ? jStr(tcp, 'member_id') : '';
          if (live !== '') {
            const nm = this.memberName(live);
            for (const gr of grows) {
              if (gr.id === g.id) {
                gr.selName = nm;
              }
            }
            if (exitId === '') {
              exitId = live;
            }
          }
        } catch (e) {
          // keep list values
        }
      }
      if (exitId !== '') {
        this.exitNodeId = exitId;
      }
      const nrows: NRow[] = [];
      for (const n of ns) {
        const r = new NRow();
        r.id = jStr(n, 'id');
        r.name = jStr(n, 'name');
        r.proto = jStr(n, 'protocol') || jStr(n, 'type');
        const pn = provName.get(jStr(n, 'provider_id'));
        r.provider = pn !== undefined ? pn : '';
        r.latency = bestLatency(jArr(n, 'health'));
        const health = jArr(n, 'health');
        r.alive = health === undefined || health.length === 0 || bestLatency(health) >= 0;
        nrows.push(r);
      }
      this.nodes = nrows;
      const prows: PRow[] = [];
      for (const p of ps) {
        const r = new PRow();
        r.id = jStr(p, 'id');
        r.name = jStr(p, 'name');
        r.kind = jStr(p, 'kind');
        r.nodeCount = jNum(p, 'node_count');
        const fetched = jStr(p, 'last_fetch_at') || jStr(p, 'updated_at');
        r.updated = fetched !== '' ? fmtClock(parseIsoMillis(fetched)) : '';
        r.status = jStr(p, 'status');
        const err = jObj(p, 'error');
        r.error = err !== undefined ? jStr(err, 'message') : '';
        prows.push(r);
      }
      this.providers = prows;
      this.loadError = '';
    } catch (e) {
      this.loadError = errMsg(e as Object);
    }
  }

  private async toggleGroup(g: GRow): Promise<void> {
    if (this.openGroupId === g.id) {
      this.openGroupId = '';
      this.members = [];
      return;
    }
    const api = this.api();
    if (api === null) {
      return;
    }
    this.openGroupId = g.id;
    this.members = [];
    await this.loadDetail(g);
  }

  private async loadDetail(g: GRow): Promise<void> {
    const api = this.api();
    if (api === null) {
      return;
    }
    try {
      const d = await api.nGroupDetail(g.id);
      const rt = jObj(d, 'runtime');
      const healthById = new Map<string, number>();
      if (rt !== undefined) {
        const health = jArr(rt, 'health');
        if (health !== undefined) {
          for (const e of health) {
            const h = e as JObj;
            const v = jGet(h, 'latency_ms');
            if (jStr(h, 'state') === 'healthy' && typeof v === 'number') {
              healthById.set(jStr(h, 'member_id'), v as number);
            }
          }
        }
      }
      const rsel = rt !== undefined ? jObj(rt, 'selection') : undefined;
      const tcp = rsel !== undefined ? jObj(rsel, 'tcp') : undefined;
      this.detailSelId = tcp !== undefined ? jStr(tcp, 'member_id') : '';
      const caps = jObj(d, 'capabilities');
      this.detailCanSelect = caps !== undefined &&
        (caps['can_select'] === true || caps['can_override'] === true);
      const rows: MRow[] = [];
      const arr = jArr(d, 'members');
      if (arr !== undefined) {
        for (const e of arr) {
          const m = e as JObj;
          const r = new MRow();
          r.id = jStr(m, 'id');
          r.name = jStr(m, 'name');
          r.kind = jStr(m, 'kind');
          const lat = healthById.get(r.id);
          r.latency = lat !== undefined ? lat : -1;
          r.current = r.id === this.detailSelId;
          rows.push(r);
        }
      }
      this.members = rows;
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
  }

  private async selectMember(gid: string, m: MRow): Promise<void> {
    const api = this.api();
    if (api === null || this.busyKey !== '') {
      return;
    }
    this.busyKey = 'sel_' + m.id;
    try {
      await api.nSelect(gid, m.id);
      this.store.toast(t('act_ok', t('honk_switch')));
      this.detailSelId = m.id;
      const rows: MRow[] = [];
      for (const r of this.members) {
        const c = new MRow();
        c.id = r.id;
        c.name = r.name;
        c.kind = r.kind;
        c.latency = r.latency;
        c.current = r.id === m.id;
        rows.push(c);
      }
      this.members = rows;
      this.store.refreshProxies();
      await this.loadAll();
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
    this.busyKey = '';
  }

  private async probeGroup(g: GRow): Promise<void> {
    const api = this.api();
    if (api === null || this.busyKey !== '') {
      return;
    }
    this.busyKey = 'probe_' + g.id;
    try {
      const target: JObj = { 'type': 'group', 'group_id': g.id };
      await api.nProbe(target);
      this.store.toast(t('act_ok', t('honk_probe')));
      if (this.openGroupId === g.id) {
        await this.loadDetail(g);
      }
      await this.loadAll();
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
    this.busyKey = '';
  }

  private async probeNode(n: NRow): Promise<void> {
    const api = this.api();
    if (api === null || this.busyKey !== '') {
      return;
    }
    this.busyKey = 'probe_' + n.id;
    try {
      const target: JObj = { 'type': 'node', 'node_id': n.id };
      await api.nProbe(target);
      await this.loadAll();
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
    this.busyKey = '';
  }

  private async probeAll(): Promise<void> {
    const api = this.api();
    if (api === null || this.busyKey !== '') {
      return;
    }
    const targets = this.visibleNodes().filter((n: NRow) => n.name !== 'direct' && n.name !== 'block');
    if (targets.length === 0) {
      return;
    }
    this.busyKey = 'probe_all';
    this.probeDone = 0;
    this.probeTotal = targets.length;
    const BATCH = 6;
    for (let i = 0; i < targets.length; i += BATCH) {
      const batch = targets.slice(i, i + BATCH);
      const jobs: Promise<void>[] = [];
      for (const n of batch) {
        const target: JObj = { 'type': 'node', 'node_id': n.id };
        jobs.push(api.nProbe(target).then(() => {
        }).catch(() => {
        }));
      }
      await Promise.all(jobs);
      this.probeDone = Math.min(targets.length, i + BATCH);
      await this.loadAll();
    }
    this.busyKey = '';
    this.store.toast(t('act_ok', t('honk_test_all')));
  }

  /** Tap a node: switch it as the exit of the first selectable group that
   * contains it (honk selection is per-group; there is no global switch) */
  private async switchNode(n: NRow): Promise<void> {
    const api = this.api();
    if (api === null || this.busyKey !== '' || n.id === this.exitNodeId) {
      return;
    }
    this.busyKey = 'switch_' + n.id;
    try {
      let done = false;
      for (const g of this.groups) {
        if (g.kind !== 'selector') {
          continue;
        }
        const d = await api.nGroupDetail(g.id);
        const caps = jObj(d, 'capabilities');
        const can = caps !== undefined && (caps['can_select'] === true || caps['can_override'] === true);
        if (!can) {
          continue;
        }
        const arr = jArr(d, 'members');
        if (arr === undefined) {
          continue;
        }
        let contains = false;
        for (const e of arr) {
          if (jStr(e as JObj, 'id') === n.id) {
            contains = true;
            break;
          }
        }
        if (!contains) {
          continue;
        }
        await api.nSelect(g.id, n.id);
        done = true;
        break;
      }
      if (done) {
        this.exitNodeId = n.id;
        this.store.toast(t('act_ok', t('honk_switch')));
        this.store.refreshProxies();
        await this.loadAll();
      } else {
        this.store.toast(t('honk_no_group'));
      }
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
    this.busyKey = '';
  }

  private visibleNodes(): NRow[] {
    const q = this.nodeQuery.trim().toLowerCase();
    if (q === '') {
      return this.nodes;
    }
    return this.nodes.filter((n: NRow) => n.name.toLowerCase().indexOf(q) >= 0);
  }

  private latencyColor(ms: number): string {
    if (ms < 0) {
      return this.store.palette().subtle;
    }
    if (ms <= this.store.lowLatency) {
      return this.store.palette().good;
    }
    if (ms <= this.store.mediumLatency) {
      return this.store.palette().warn;
    }
    return this.store.palette().bad;
  }

  /** Radio circle + check marking the current selection */
  @Builder
  radioMark() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(22)
        .height(22)
        .borderRadius(11)
        .border({ width: 1.5, color: this.store.palette().accentUi })
        .backgroundColor(this.store.palette().accentSoft)
      SymbolGlyph($r('sys.symbol.checkmark'))
        .fontSize(12)
        .fontColor([this.store.palette().accentUi])
    }
    .width(22)
    .height(22)
  }

  @Builder
  groupsSection() {
    Column({ space: 12 }) {
      ForEach(this.groups, (g: GRow) => {
        Column() {
          Row() {
            Column() {
              Row({ space: 6 }) {
                Text(g.name).fontSize(16).fontWeight(FontWeight.Medium)
                  .fontColor(this.store.palette().text)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(g.kind).fontSize(10).fontColor(this.store.palette().subtle)
                  .backgroundColor(this.store.palette().chip)
                  .borderRadius(5)
                  .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              }
              Text(t('honk_member_count', g.memberCount.toString()) +
                (g.selName !== '' ? ' · ' + g.selName : ''))
                .fontSize(12)
                .fontColor(this.store.palette().good)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 3 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            if (this.busyKey === 'probe_' + g.id) {
              LoadingProgress().width(20).height(20).color(this.store.palette().accentUi)
                .margin({ left: 9, right: 9 })
            } else {
              Button(t('honk_probe'))
                .height(38)
                .fontSize(13)
                .fontColor(this.store.palette().text)
                .backgroundColor(this.store.palette().chip)
                .onClick(() => {
                  this.probeGroup(g);
                })
            }
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(16)
              .fontColor([this.store.palette().subtle])
              .margin({ left: 10 })
              .rotate({ angle: this.openGroupId === g.id ? 180 : 0 })
          }
          .width('100%')
          .onClick(() => {
            this.toggleGroup(g);
          })

          if (this.openGroupId === g.id) {
            Column() {
              if (this.detailCanSelect) {
                Text(t('honk_clear_override'))
                  .fontSize(13)
                  .fontColor(this.store.palette().accent)
                  .padding({ top: 8, bottom: 4 })
                  .onClick(() => {
                    const api = this.api();
                    if (api !== null) {
                      api.nClearSelection(g.id).then(() => {
                        this.store.toast(t('act_ok', t('honk_clear_override')));
                        this.loadAll();
                      }).catch((e: Object) => {
                        this.store.toast(errMsg(e));
                      });
                    }
                  })
              }
              ForEach(this.members, (m: MRow) => {
                Row() {
                  Text(m.kind === 'group' ? t('honk_groups') : t('honk_nodes'))
                    .fontSize(10)
                    .fontColor(this.store.palette().subtle)
                    .backgroundColor(this.store.palette().chip)
                    .borderRadius(5)
                    .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                  Text(m.name)
                    .fontSize(14)
                    .fontColor(this.store.palette().text)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                    .margin({ left: 8 })
                  if (m.latency >= 0) {
                    Text(m.latency.toString() + ' ms')
                      .fontSize(12)
                      .fontColor(this.latencyColor(m.latency))
                      .margin({ right: 8 })
                  }
                  if (this.busyKey === 'sel_' + m.id) {
                    LoadingProgress().width(16).height(16).color(this.store.palette().accentUi)
                  } else if (m.current) {
                    this.radioMark()
                  }
                }
                .width('100%')
                .padding({ top: 11, bottom: 11 })
                .onClick(() => {
                  if (this.detailCanSelect && !m.current) {
                    this.selectMember(g.id, m);
                  }
                })
              }, (m: MRow) => m.id)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .attributeModifier(this.store.glass('card'))
      }, (g: GRow) => g.id)
    }
    .width('100%')
  }

  @Builder
  nodesSection() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        TextInput({ text: this.nodeQuery, placeholder: t('search') })
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .fontColor(this.store.palette().text)
          .placeholderColor(this.store.palette().subtle)
          .backgroundColor(this.store.palette().chip)
          .borderRadius(12)
          .onChange((v: string) => {
            this.nodeQuery = v;
          })
        Button(t('honk_test_all'))
          .height(42)
          .fontSize(13)
          .fontColor(this.store.palette().text)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            this.probeAll();
          })
      }
      .width('100%')

      if (this.busyKey === 'probe_all') {
        Column() {
          Row() {
            Text(t('honk_probe')).fontSize(12).fontColor(this.store.palette().subtle)
              .layoutWeight(1)
            Text(this.probeDone.toString() + ' / ' + this.probeTotal.toString())
              .fontSize(12)
              .fontColor(this.store.palette().subtle)
          }
          .width('100%')
          Progress({
            value: this.probeDone,
            total: Math.max(1, this.probeTotal),
            type: ProgressType.Linear
          })
            .color(this.store.palette().accentUi)
            .backgroundColor(this.store.palette().chip)
            .style({ strokeWidth: 5 })
            .width('100%')
            .margin({ top: 4 })
        }
        .width('100%')
      }

      ForEach(this.visibleNodes(), (n: NRow) => {
        Row() {
          Column() {
            Row({ space: 6 }) {
              Text(n.alive ? '●' : '○')
                .fontSize(11)
                .fontColor(this.store.palette().good)
              Text(n.name)
                .fontSize(15)
                .fontColor(this.store.palette().text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            Text((n.proto !== '' ? n.proto : '') + (n.provider !== '' ? ' · ' + n.provider : ''))
              .fontSize(12)
              .fontColor(this.store.palette().subtle)
              .maxLines(1)
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            this.switchNode(n);
          })
          if (this.busyKey === 'probe_' + n.id || this.busyKey === 'switch_' + n.id) {
            LoadingProgress().width(20).height(20).color(this.store.palette().accentUi)
          } else {
            if (n.latency >= 0) {
              Text(n.latency.toString() + ' ms')
                .fontSize(13)
                .fontColor(this.latencyColor(n.latency))
                .padding({ left: 6, right: 6, top: 8, bottom: 8 })
                .onClick(() => {
                  this.probeNode(n);
                })
            } else {
              Text(t('honk_probe'))
                .fontSize(13)
                .fontColor(this.store.palette().accent)
                .padding({ left: 6, right: 6, top: 8, bottom: 8 })
                .onClick(() => {
                  this.probeNode(n);
                })
            }
            if (n.id === this.exitNodeId) {
              Row() {
                this.radioMark()
              }
              .margin({ left: 4 })
            }
          }
        }
        .width('100%')
        .padding(14)
        .borderRadius(18)
        .attributeModifier(this.store.glass('card'))
      }, (n: NRow) => n.id)
    }
    .width('100%')
  }

  @Builder
  providersSection() {
    Column({ space: 12 }) {
      ForEach(this.providers, (p: PRow) => {
        Column() {
          Row() {
            Text(p.name).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(this.store.palette().text)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(p.kind).fontSize(10).fontColor(this.store.palette().subtle)
              .backgroundColor(this.store.palette().chip)
              .borderRadius(5)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          }
          .width('100%')
          Text(t('honk_node_count', p.nodeCount.toString()) +
            (p.updated !== '' ? ' · ' + t('honk_updated_at', p.updated) : ''))
            .fontSize(12)
            .fontColor(this.store.palette().subtle)
            .margin({ top: 4 })
          if (p.error !== '') {
            Text(p.error).fontSize(12).fontColor(this.store.palette().bad)
              .margin({ top: 4 })
          } else if (p.status !== '') {
            Text(p.status).fontSize(12).fontColor(this.store.palette().subtle)
              .margin({ top: 4 })
          }
          if (p.kind === 'subscription') {
            Row({ space: 8 }) {
              if (this.busyKey === 'prov_' + p.id) {
                LoadingProgress().width(20).height(20).color(this.store.palette().accentUi)
              } else {
                Button(t('honk_update'))
                  .height(38)
                  .fontSize(13)
                  .fontColor(this.store.palette().text)
                  .backgroundColor(this.store.palette().chip)
                  .onClick(() => {
                    const api = this.api();
                    if (api === null || this.busyKey !== '') {
                      return;
                    }
                    this.busyKey = 'prov_' + p.id;
                    api.nRefreshProvider(p.id).then(() => {
                      this.store.toast(t('act_ok', t('honk_update')));
                      this.busyKey = '';
                      this.updatedOkId = p.id;
                      setTimeout(() => {
                        if (this.updatedOkId === p.id) {
                          this.updatedOkId = '';
                        }
                      }, 2500);
                      this.loadAll();
                    }).catch((e: Object) => {
                      this.store.toast(errMsg(e));
                      this.busyKey = '';
                    });
                  })
              }
              if (this.updatedOkId === p.id) {
                this.radioMark()
              }
            }
            .margin({ top: 10 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .borderRadius(18)
        .attributeModifier(this.store.glass('card'))
      }, (p: PRow) => p.id)
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.sc) {
        Column({ space: 12 }) {
          SegTabs({
            pal: this.store.palette(),
            items: [t('honk_groups'), t('honk_nodes'), t('honk_providers')],
            selected: this.tab,
            onSelect: (i: number) => {
              this.tab = i;
            }
          })
          if (this.loadError !== '') {
            Text(this.loadError).fontSize(13).fontColor(this.store.palette().bad)
          }
          if (this.tab === 0) {
            this.groupsSection()
          } else if (this.tab === 1) {
            this.nodesSection()
          } else {
            this.providersSection()
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
          title: t('tab_proxies'),
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
