import { Store } from '../common/Store';
import { JObj, asNum, jArr, jBool, jGet, jNum, jObj, jStr } from '../common/Models';
import { fmtClock, fmtMsInt } from '../common/Format';
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
  latTcp: number = -1;
  latUdp: number = -1;
  hasTcp: boolean = false;
  hasUdp: boolean = false;
  state: string = 'unknown';
  current: boolean = false;
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


/** Flag emoji prefix of a node name (two regional indicators), '' if none */
function flagOf(name: string): string {
  if (name.length >= 4) {
    const a = name.charCodeAt(0);
    const b = name.charCodeAt(1);
    const c = name.charCodeAt(2);
    const d = name.charCodeAt(3);
    if (a === 0xD83C && b >= 0xDDE6 && b <= 0xDDFF && c === 0xD83C && d >= 0xDDE6 && d <= 0xDDFF) {
      return name.substring(0, 4);
    }
  }
  return '';
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
  @Local providers: PRow[] = [];
  @Local loadError: string = '';
  @Local busyKey: string = '';

  // group detail (inline expansion)
  @Local openGroupId: string = '';
  @Local members: MRow[] = [];
  @Local detailSelId: string = '';
  @Local detailCanSelect: boolean = false;

  @Local probeDone: number = 0;
  @Local probeTotal: number = 0;
  @Local groupProbeId: string = '';
  // doona-style member toolbar state
  @Local mQuery: string = '';
  @Local mNet: number = 0;
  @Local mRegion: string = '';
  @Local mSort: number = 0;
  @Local mOnlyAvail: boolean = false;
  @Local detailPinned: boolean = false;
  @Local updatedOkId: string = '';
  /** opened from the overview outbound card: return there after a pick */
  @Local pickReturn: boolean = false;

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
    if (this.store.tab === 1) {
      this.consumePick();
    }
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

  /** Overview outbound card jump: open the requested group so the user
   * can pick a member; a successful pick returns to the overview. */
  private consumePick(): void {
    const gid = this.store.honkPickGroup;
    if (gid === '') {
      return;
    }
    for (const g of this.groups) {
      if (g.id === gid) {
        this.store.honkPickGroup = '';
        this.pickReturn = true;
        this.tab = 0;
        if (this.openGroupId !== gid) {
          this.toggleGroup(g);
        }
        return;
      }
    }
    // groups not loaded yet: keep the request for the next tick
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
      // group card selection label: the live runtime selection (the list
      // selection is the config value and goes stale after a switch)
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
          }
        } catch (e) {
          // keep list values
        }
      }
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
      const tcpById = new Map<string, number>();
      const udpById = new Map<string, number>();
      const testedById = new Set<string>();
      const seenTcp = new Set<string>();
      const seenUdp = new Set<string>();
      if (rt !== undefined) {
        const health = jArr(rt, 'health');
        if (health !== undefined) {
          for (const e of health) {
            const h = e as JObj;
            const mid = jStr(h, 'member_id');
            const net = jStr(h, 'network');
            testedById.add(mid);
            if (net === 'tcp' || net === '') {
              seenTcp.add(mid);
            }
            if (net === 'udp' || net === '') {
              seenUdp.add(mid);
            }
            const v = jGet(h, 'latency_ms');
            if (jStr(h, 'state') === 'healthy' && typeof v === 'number') {
              const ms = v as number;
              const prev = healthById.get(mid);
              if (prev === undefined || ms < prev) {
                healthById.set(mid, ms);
              }
              if (net === 'tcp' || net === '') {
                const pt = tcpById.get(mid);
                if (pt === undefined || ms < pt) {
                  tcpById.set(mid, ms);
                }
              }
              if (net === 'udp' || net === '') {
                const pu = udpById.get(mid);
                if (pu === undefined || ms < pu) {
                  udpById.set(mid, ms);
                }
              }
            }
          }
        }
      }
      const rsel = rt !== undefined ? jObj(rt, 'selection') : undefined;
      const tcp = rsel !== undefined ? jObj(rsel, 'tcp') : undefined;
      this.detailSelId = tcp !== undefined ? jStr(tcp, 'member_id') : '';
      const src = tcp !== undefined ? jStr(tcp, 'source') : '';
      this.detailPinned = src.indexOf('manual') >= 0 || src.indexOf('override') >= 0 ||
        src.indexOf('pin') >= 0 || src.indexOf('user') >= 0;
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
          const lt = tcpById.get(r.id);
          r.latTcp = lt !== undefined ? lt : -1;
          const lu = udpById.get(r.id);
          r.latUdp = lu !== undefined ? lu : -1;
          r.hasTcp = seenTcp.has(r.id);
          r.hasUdp = seenUdp.has(r.id);
          r.state = !testedById.has(r.id) ? 'unknown' : (r.latency >= 0 ? 'ok' : 'dead');
          r.current = r.id === this.detailSelId;
          rows.push(r);
        }
      }
      this.members = rows;
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
  }

  /** Tap a member's latency: re-probe just that member. */
  private async probeMember(g: GRow, m: MRow): Promise<void> {
    const api = this.api();
    if (api === null || this.busyKey !== '') {
      return;
    }
    this.busyKey = 'probe_' + m.id;
    try {
      const target: JObj = m.kind === 'group' ?
        { 'type': 'group', 'group_id': m.id } : { 'type': 'node', 'node_id': m.id };
      await api.nProbe(target);
      await this.loadDetail(g);
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
    this.busyKey = '';
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
        c.latTcp = r.latTcp;
        c.latUdp = r.latUdp;
        c.hasTcp = r.hasTcp;
        c.hasUdp = r.hasUdp;
        c.state = r.state;
        c.current = r.id === m.id;
        rows.push(c);
      }
      this.members = rows;
      this.store.refreshProxies();
      await this.loadAll();
      if (this.pickReturn) {
        this.pickReturn = false;
        this.store.tab = 0;
      }
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
    this.busyKey = '';
  }

  /** Clear a manual override on an auto-policy group: honk falls back
   * to its own automatic pick; reload the detail so the check lands on
   * the auto-picked member right away. */
  private async clearOverride(g: GRow): Promise<void> {
    const api = this.api();
    if (api === null || this.busyKey !== '') {
      return;
    }
    this.busyKey = 'clear_' + g.id;
    try {
      await api.nClearSelection(g.id);
      this.detailPinned = false;
      this.store.toast(t('act_ok', t('honk_clear_override')));
      this.store.refreshProxies();
      // honk re-forms the automatic selection asynchronously; give it a
      // beat before reading the detail back
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => {
          resolve();
        }, 700);
      });
      await this.loadDetail(g);
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
    this.groupProbeId = g.id;
    try {
      const d = await api.nGroupDetail(g.id);
      const targets: JObj[] = [];
      const arr = jArr(d, 'members');
      if (arr !== undefined) {
        for (const e of arr) {
          const m = e as JObj;
          const mid = jStr(m, 'id');
          if (mid === '') {
            continue;
          }
          if (jStr(m, 'kind') === 'group') {
            targets.push({ 'type': 'group', 'group_id': mid });
          } else {
            targets.push({ 'type': 'node', 'node_id': mid });
          }
        }
      }
      if (targets.length === 0) {
        const target: JObj = { 'type': 'group', 'group_id': g.id };
        await api.nProbe(target);
      } else {
        this.probeDone = 0;
        this.probeTotal = targets.length;
        const BATCH = 6;
        for (let i = 0; i < targets.length; i += BATCH) {
          const batch = targets.slice(i, i + BATCH);
          const jobs: Promise<void>[] = [];
          for (const tg of batch) {
            jobs.push(api.nProbe(tg).then(() => {
            }).catch(() => {
            }));
          }
          await Promise.all(jobs);
          this.probeDone = Math.min(targets.length, i + BATCH);
          if (this.openGroupId === g.id) {
            await this.loadDetail(g);
          }
        }
      }
      this.store.toast(t('act_ok', t('honk_probe')));
      await this.loadAll();
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
    this.busyKey = '';
    this.groupProbeId = '';
  }

  private effLatency(m: MRow): number {
    if (this.mNet === 1) {
      return m.latTcp;
    }
    if (this.mNet === 2) {
      return m.latUdp;
    }
    return m.latency;
  }

  private effState(m: MRow): string {
    if (this.mNet === 1) {
      if (m.latTcp >= 0) {
        return 'ok';
      }
      return m.hasTcp ? 'dead' : m.state;
    }
    if (this.mNet === 2) {
      if (m.latUdp >= 0) {
        return 'ok';
      }
      return m.hasUdp ? 'dead' : m.state;
    }
    return m.state;
  }

  private regionKey(name: string): string {
    const f = flagOf(name);
    return f !== '' ? f : '__other__';
  }

  private regionKeys(): string[] {
    const seen: string[] = [];
    for (const m of this.members) {
      const k = this.regionKey(m.name);
      if (seen.indexOf(k) < 0) {
        seen.push(k);
      }
    }
    return seen;
  }

  private regionLabel(k: string): string {
    return k === '__other__' ? t('honk_other_region') : k;
  }

  private visibleMembers(): MRow[] {
    let rows = this.members.slice();
    const q = this.mQuery.trim().toLowerCase();
    if (q !== '') {
      rows = rows.filter((m: MRow) => m.name.toLowerCase().indexOf(q) >= 0);
    }
    if (this.mRegion !== '') {
      rows = rows.filter((m: MRow) => this.regionKey(m.name) === this.mRegion);
    }
    if (this.mOnlyAvail) {
      rows = rows.filter((m: MRow) => this.effState(m) !== 'dead');
    }
    if (this.mSort === 1) {
      rows.sort((a: MRow, b: MRow) => {
        const sa = this.effState(a);
        const sb = this.effState(b);
        const ra = sa === 'ok' ? 0 : (sa === 'unknown' ? 1 : 2);
        const rb = sb === 'ok' ? 0 : (sb === 'unknown' ? 1 : 2);
        if (ra !== rb) {
          return ra - rb;
        }
        const la = this.effLatency(a) >= 0 ? this.effLatency(a) : 1000000000;
        const lb = this.effLatency(b) >= 0 ? this.effLatency(b) : 1000000000;
        return la - lb;
      });
    } else if (this.mSort === 2) {
      rows.sort((a: MRow, b: MRow) => a.name.localeCompare(b.name));
    }
    return rows;
  }

  private countState(rows: MRow[], state: string): number {
    let n = 0;
    for (const m of rows) {
      if (this.effState(m) === state) {
        n++;
      }
    }
    return n;
  }

  private sortOptions(): SelectOption[] {
    const a: SelectOption = { value: t('honk_sort_default') };
    const b: SelectOption = { value: t('honk_sort_latency') };
    const c: SelectOption = { value: t('honk_sort_name') };
    return [a, b, c];
  }

  private regionOptionsSel(): SelectOption[] {
    const out: SelectOption[] = [];
    const all: SelectOption = { value: t('honk_all_regions') };
    out.push(all);
    for (const k of this.regionKeys()) {
      const o: SelectOption = { value: this.regionLabel(k) };
      out.push(o);
    }
    return out;
  }

  private detailSelName(): string {
    for (const m of this.members) {
      if (m.id === this.detailSelId) {
        return m.name;
      }
    }
    return this.detailSelId !== '' ? this.memberName(this.detailSelId) : '';
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

          if (this.groupProbeId === g.id) {
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
            .margin({ top: 10 })
          }

          if (this.openGroupId === g.id) {
            Column() {
              if (this.detailCanSelect && g.kind !== 'selector' && this.detailPinned) {
                Button(t('honk_clear_override'))
                  .height(38)
                  .fontSize(13)
                  .fontColor(this.store.palette().text)
                  .backgroundColor(this.store.palette().chip)
                  .margin({ top: 8, bottom: 4 })
                  .onClick(() => {
                    this.clearOverride(g);
                  })
              }
              Row({ space: 14 }) {
                Row({ space: 4 }) {
                  Text('●').fontSize(10).fontColor(this.store.palette().good)
                  Text(t('honk_avail', this.countState(this.members, 'ok').toString()))
                    .fontSize(12).fontColor(this.store.palette().subtle)
                }
                Row({ space: 4 }) {
                  Text('●').fontSize(10).fontColor(this.store.palette().bad)
                  Text(t('honk_dead', this.countState(this.members, 'dead').toString()))
                    .fontSize(12).fontColor(this.store.palette().subtle)
                }
                Row({ space: 4 }) {
                  Text('●').fontSize(10).fontColor(this.store.palette().subtle)
                  Text(t('honk_untested', this.countState(this.members, 'unknown').toString()))
                    .fontSize(12).fontColor(this.store.palette().subtle)
                }
              }
              .width('100%')
              .margin({ top: 10, bottom: 2 })

              if (this.detailSelId !== '') {
                Row({ space: 8 }) {
                  Text(t('honk_current') + this.detailSelName())
                    .fontSize(13)
                    .fontColor(this.store.palette().text)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  if (this.detailPinned || g.kind === 'selector') {
                    Text(t('honk_pinned'))
                      .fontSize(11)
                      .fontColor(this.store.palette().subtle)
                      .backgroundColor(this.store.palette().chip)
                      .borderRadius(6)
                      .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  }
                }
                .width('100%')
                .margin({ bottom: 4 })
              }

              TextInput({ text: this.mQuery, placeholder: t('honk_filter_nodes') })
                .width('100%')
                .height(40)
                .fontSize(14)
                .fontColor(this.store.palette().text)
                .placeholderColor(this.store.palette().subtle)
                .backgroundColor(this.store.palette().chip)
                .borderRadius(12)
                .onChange((v: string) => {
                  this.mQuery = v;
                })

              Row({ space: 8 }) {
                Button(t('honk_net_both'))
                  .height(36)
                  .fontSize(13)
                  .fontColor(this.store.palette().text)
                  .backgroundColor(this.mNet === 0 ? this.store.palette().accentSoft : this.store.palette().chip)
                  .onClick(() => {
                    this.mNet = 0;
                  })
                Button('TCP')
                  .height(36)
                  .fontSize(13)
                  .fontColor(this.store.palette().text)
                  .backgroundColor(this.mNet === 1 ? this.store.palette().accentSoft : this.store.palette().chip)
                  .onClick(() => {
                    this.mNet = 1;
                  })
                Button('UDP')
                  .height(36)
                  .fontSize(13)
                  .fontColor(this.store.palette().text)
                  .backgroundColor(this.mNet === 2 ? this.store.palette().accentSoft : this.store.palette().chip)
                  .onClick(() => {
                    this.mNet = 2;
                  })
                Select(this.regionOptionsSel())
                  .selected(this.mRegion === '' ? 0 : this.regionKeys().indexOf(this.mRegion) + 1)
                  .value(t('honk_all_regions'))
                  .font({ size: 13 })
                  .fontColor(this.store.palette().text)
                  .height(36)
                  .layoutWeight(1)
                  .onSelect((idx: number) => {
                    this.mRegion = idx === 0 ? '' : this.regionKeys()[idx - 1];
                  })
              }
              .width('100%')
              .margin({ top: 8 })

              Row({ space: 8 }) {
                Text(t('honk_sort')).fontSize(13).fontColor(this.store.palette().subtle)
                Select(this.sortOptions())
                  .selected(this.mSort)
                  .value(t('honk_sort_default'))
                  .font({ size: 13 })
                  .fontColor(this.store.palette().text)
                  .height(36)
                  .onSelect((idx: number) => {
                    this.mSort = idx;
                  })
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.mOnlyAvail })
                  .selectedColor(this.store.palette().accentUi)
                  .onChange((on: boolean) => {
                    this.mOnlyAvail = on;
                  })
                Text(t('honk_only_avail')).fontSize(13).fontColor(this.store.palette().text)
              }
              .width('100%')
              .margin({ top: 8, bottom: 2 })

              ForEach(this.visibleMembers(), (m: MRow) => {
                Row() {
                  Text('●')
                    .fontSize(10)
                    .fontColor(this.effState(m) === 'ok' ? this.store.palette().good :
                      (this.effState(m) === 'dead' ? this.store.palette().bad : this.store.palette().subtle))
                  Text(m.name)
                    .fontSize(14)
                    .fontColor(this.effState(m) === 'dead' ? this.store.palette().subtle : this.store.palette().text)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                    .margin({ left: 8 })
                  if (m.kind === 'group') {
                    Text(t('honk_groups'))
                      .fontSize(10)
                      .fontColor(this.store.palette().subtle)
                      .backgroundColor(this.store.palette().chip)
                      .borderRadius(5)
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                      .margin({ right: 8 })
                  }
                  if (this.effLatency(m) >= 0) {
                    Text(fmtMsInt(this.effLatency(m)) + ' ms')
                      .fontSize(12)
                      .fontColor(this.latencyColor(this.effLatency(m)))
                      .margin({ right: 8 })
                      .onClick(() => {
                        if (this.busyKey === '') {
                          this.probeMember(g, m);
                        }
                      })
                  } else if (this.effState(m) === 'dead') {
                    Text(t('honk_timeout'))
                      .fontSize(12)
                      .fontColor(this.store.palette().bad)
                      .margin({ right: 8 })
                  }
                  if (this.busyKey === 'sel_' + m.id) {
                    LoadingProgress().width(16).height(16).color(this.store.palette().accentUi)
                  } else if (m.id === this.detailSelId) {
                    this.radioMark()
                  }
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .borderRadius(14)
                .backgroundColor(m.id === this.detailSelId ? this.store.palette().accentSoft : this.store.palette().chip)
                .margin({ bottom: 8 })
                .onClick(() => {
                  if (this.detailCanSelect && m.id !== this.detailSelId) {
                    this.selectMember(g.id, m);
                  }
                })
              }, (m: MRow) => m.id + (m.id === this.detailSelId ? ':c' : ''))

              Text(t('honk_members_dead', this.members.length.toString(),
                this.countState(this.members, 'dead').toString()))
                .fontSize(12)
                .fontColor(this.store.palette().subtle)
                .width('100%')
                .margin({ top: 6 })
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
            items: [t('honk_groups'), t('honk_providers')],
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
