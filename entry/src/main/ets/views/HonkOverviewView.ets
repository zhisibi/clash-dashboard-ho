import { Store } from '../common/Store';
import { Palette } from '../common/Theme';
import { JObj, Traffic, asNum, asStr, jArr, jGet, jNum, jObj, jStr, parseIsoMillis } from '../common/Models';
import { fmtBytes, fmtClock, fmtDuration, fmtMsInt, fmtSpeed } from '../common/Format';
import { HeaderStatus, Legend, LineChart, SegTabs } from '../components/Widgets';
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
  active: number = 0;
  up: number = 0;
  down: number = 0;
  pct: number = 0;
}

class KV {
  k: string = '';
  v: string = '';
}

class LatRow {
  name: string = '';
  ms: number = 0;
}

class GrpCur {
  name: string = '';
  sel: string = '';
  ms: number = -1;
}

class RankRow {
  name: string = '';
  bytes: number = 0;
}

class QsGroup {
  id: string = '';
  name: string = '';
  currentId: string = '';
  currentName: string = '';
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
  @Local obActive: number = 0;
  @Local obUpSum: number = 0;
  @Local obDownSum: number = 0;
  @Local lastReload: string = '';
  @Local rtError: string = '';

  @Local subTab: number = 0;
  // locally polled values (the Store streams are only a fallback: on some
  // gateways the sampler fields the streams read stay empty)
  @Local rateUp: number = 0;
  @Local rateDown: number = 0;
  @Local totalUpL: number = 0;
  @Local totalDownL: number = 0;
  @Local memBytes: number = 0;
  @Local counterSince: string = '';
  @Local rateWindow: string = '';
  @Local startedText: string = '';
  @Local sysStatusRows: KV[] = [];
  @Local engineRows: KV[] = [];
  @Local trafficRows: KV[] = [];
  @Local memRows: KV[] = [];
  @Local dpRows: KV[] = [];
  @Local capOn: string[] = [];
  @Local capOff: string[] = [];
  @Local latOk: LatRow[] = [];
  @Local latDead: string[] = [];
  @Local latUnknown: string[] = [];
  @Local showAllLat: boolean = false;
  @Local rankTab: number = 0;
  @Local dnsRows: string[] = [];
  @Local grpCur: GrpCur[] = [];
  private prevTotUp: number = -1;
  private prevTotDown: number = -1;
  private prevTotAt: number = 0;
  private staticKey: string = '';
  private latByName: Map<string, number> = new Map<string, number>();

  @Local qsGroups: QsGroup[] = [];
  @Local qsSelId: string = '';
  @Local qsLeafName: string = '';
  @Local qsBusy: boolean = false;
  /** Outbound mode from the config catch-all: '' = auto, else the group
   * name all traffic is forced to. Mirrors doona's activity card. */
  @Local qsModeTarget: string = '';
  @Local qsModeWritable: boolean = false;
  private modeLoadedAt: number = 0;
  private fastBusy: boolean = false;
  private slowBusy: boolean = false;
  private slowAt: number = 0;
  private nameById: Map<string, string> = new Map<string, string>();

  aboutToAppear(): void {
    this.loadExtras();
    this.timer = setInterval(() => {
      this.loadExtras();
    }, 3000);
    // immediate refresh when this tab becomes active or the backend changes
    this.watch = setInterval(() => {
      const key = this.store.active !== null ? this.store.active.id : '';
      if (key !== this.lastBackendKey) {
        this.lastBackendKey = key;
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
    if (api === null || this.fastBusy || this.store.connState !== 'connected') {
      return;
    }
    this.fastBusy = true;
    try {
      const rt = await api.nRuntime('full');
      const life = jObj(rt, 'lifecycle');
      this.lifeState = life !== undefined ? jStr(life, 'state') : '';
      this.uptimeSec = (life !== undefined ? jNum(life, 'uptime_seconds') : 0) || jNum(rt, 'uptime_seconds');
      if (this.uptimeSec === 0 && life !== undefined) {
        // some builds omit uptime_seconds; derive it from started_at
        const started = parseIsoMillis(jStr(life, 'started_at'));
        if (started > 0 && Date.now() > started) {
          this.uptimeSec = Math.floor((Date.now() - started) / 1000);
        }
      }
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
      // traffic counters: totals feed the stats grid and the locally
      // computed rates; doona reads the same fields
      let totUp = 0;
      let totDown = 0;
      if (traffic !== undefined) {
        const bytes = jObj(traffic, 'bytes');
        if (bytes !== undefined) {
          totUp = asNum(jGet(bytes, 'upload')) || asNum(jGet(bytes, 'upload_bytes'));
          totDown = asNum(jGet(bytes, 'download')) || asNum(jGet(bytes, 'download_bytes'));
        }
        this.counterSince = jStr(traffic, 'counter_since');
        const rates = jObj(traffic, 'rates');
        if (rates !== undefined) {
          const w = jGet(rates, 'window_seconds');
          this.rateWindow = w !== undefined ? asNum(w).toFixed(1) : '';
        }
      }
      const gen = jObj(rt, 'generation');
      const cfgRev = gen !== undefined ? jStr(gen, 'config_revision') : '';
      const activatedAt = gen !== undefined ? jStr(gen, 'activated_at') : '';
      this.startedText = life !== undefined ? jStr(life, 'started_at') : '';
      const dp = jObj(rt, 'datapath');
      const dpRows: KV[] = [];
      if (dp !== undefined) {
        this.pushKv(dpRows, 'kind', jStr(dp, 'kind'));
        this.pushKv(dpRows, 'state', jStr(dp, 'state'));
        this.pushKv(dpRows, 'visibility', jStr(dp, 'visibility'));
        const ebpf = jObj(dp, 'ebpf');
        if (ebpf !== undefined) {
          for (const k of Object.keys(ebpf)) {
            const v = jGet(ebpf, k);
            if (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean') {
              this.pushKv(dpRows, k, asStr(v));
            }
          }
        }
      }
      this.dpRows = dpRows;
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
      if (lr !== undefined) {
        const st = jStr(lr, 'status') || jStr(lr, 'state') || jStr(lr, 'result');
        let at = jStr(lr, 'completed_at') || jStr(lr, 'finished_at') || jStr(lr, 'at') ||
          jStr(lr, 'started_at') || jStr(lr, 'timestamp');
        if (at !== '') {
          const ms = parseIsoMillis(at);
          at = ms > 0 ? fmtClock(ms) : at;
        }
        this.lastReload = (st + ' ' + at).trim();
      } else {
        this.lastReload = jStr(rt, 'last_reload');
      }
      this.rtError = '';
      await this.loadOutbounds(api);
      if (this.connTcp + this.connUdp === 0 && this.obActive > 0) {
        this.connTcp = this.obActive;
      }
      if (totUp === 0 && totDown === 0) {
        totUp = this.obUpSum;
        totDown = this.obDownSum;
      }
      this.totalUpL = totUp;
      this.totalDownL = totDown;
      // rates: prefer honk's own 1 s history samples (server-computed,
      // the same source doona charts); the totals delta below is only a
      // fallback for when the history recorder is off
      let histOk = false;
      try {
        const hist = await api.nTrafficHistory(30, 30);
        for (let i = hist.length - 1; i >= 0; i--) {
          const up = jGet(hist[i], 'upload_bytes_per_second');
          const down = jGet(hist[i], 'download_bytes_per_second');
          if (up !== undefined && down !== undefined) {
            this.rateUp = Math.max(0, Math.round(asNum(up)));
            this.rateDown = Math.max(0, Math.round(asNum(down)));
            histOk = true;
            break;
          }
        }
      } catch (e) {
        // history disabled on this backend: fall through to deltas
      }
      const nowMs = Date.now();
      if (!histOk && this.prevTotAt > 0 && nowMs > this.prevTotAt && this.prevTotUp >= 0) {
        const dt = (nowMs - this.prevTotAt) / 1000;
        this.rateUp = Math.max(0, Math.round((totUp - this.prevTotUp) / dt));
        this.rateDown = Math.max(0, Math.round((totDown - this.prevTotDown) / dt));
      }
      this.prevTotUp = totUp;
      this.prevTotDown = totDown;
      this.prevTotAt = nowMs;
      const tRows: KV[] = [];
      this.pushKv(tRows, t('honk_tcp_conn'), this.connTcp.toString());
      this.pushKv(tRows, t('honk_udp_conn'), this.connUdp.toString());
      this.pushKv(tRows, t('honk_conn_total'), (this.connTcp + this.connUdp).toString());
      this.pushKv(tRows, t('honk_total_up'), fmtBytes(totUp));
      this.pushKv(tRows, t('honk_total_down'), fmtBytes(totDown));
      if (this.rateWindow !== '') {
        this.pushKv(tRows, t('honk_rate_window'), this.rateWindow + ' s');
      }
      if (this.counterSince !== '') {
        const cs = parseIsoMillis(this.counterSince);
        this.pushKv(tRows, t('honk_counter_since'), cs > 0 ? fmtClock(cs) : this.counterSince);
      }
      this.trafficRows = tRows;
      const sRows: KV[] = [];
      this.pushKv(sRows, t('honk_status'), this.lifeState);
      this.pushKv(sRows, t('honk_config_ver'), cfgRev);
      this.pushKv(sRows, t('honk_uptime'),
        this.uptimeSec > 0 ? fmtDuration(this.uptimeSec * 1000) : '-');
      this.pushKv(sRows, 'CPU', this.cpuText);
      this.pushKv(sRows, t('honk_last_reload'), this.lastReload);
      this.pushKv(sRows, t('honk_started'),
        this.startedText !== '' ? fmtClock(parseIsoMillis(this.startedText)) : '');
      this.pushKv(sRows, t('honk_activated'),
        activatedAt !== '' ? fmtClock(parseIsoMillis(activatedAt)) : '');
      this.sysStatusRows = sRows;
      await this.loadQs(api);
      await this.loadMem(api);
    } catch (e) {
      this.rtError = errMsg(e as Object);
    }
    this.fastBusy = false;
    // slow lane: heavy lists refresh at most every 12 s and never block
    // the fast lane above (rates / quick-switch stay real-time)
    if (!this.slowBusy && Date.now() - this.slowAt > 12000 &&
      this.store.connState === 'connected') {
      this.slowBusy = true;
      this.slowAt = Date.now();
      const api2 = this.api();
      if (api2 !== null) {
        try {
          await this.loadNodesLat(api2);
          await this.loadGrpCur(api2);
          await this.loadDns(api2);
          await this.loadStatic(api2);
        } catch (e) {
          // slow lane is best-effort
        }
      }
      this.slowBusy = false;
    }
  }



  private pushKv(rows: KV[], k: string, v: string): void {
    if (v === '') {
      return;
    }
    const r = new KV();
    r.k = k;
    r.v = v;
    rows.push(r);
  }

  private async loadNodesLat(api: HonkCoreApi): Promise<void> {
    try {
      const ns = await api.nNodes();
      const ok: LatRow[] = [];
      const dead: string[] = [];
      const unknown: string[] = [];
      const byName = new Map<string, number>();
      for (const n of ns) {
        const name = jStr(n, 'name');
        if (name === '' || name === 'direct' || name === 'block') {
          continue;
        }
        const health = jArr(n, 'health');
        let best = -1;
        let tested = false;
        if (health !== undefined) {
          for (const e of health) {
            const h = e as JObj;
            tested = true;
            const v = jGet(h, 'latency_ms');
            if (jStr(h, 'state') === 'healthy' && typeof v === 'number') {
              if (best < 0 || (v as number) < best) {
                best = v as number;
              }
            }
          }
        }
        if (best >= 0) {
          const r = new LatRow();
          r.name = name;
          r.ms = best;
          ok.push(r);
          byName.set(name, best);
        } else if (tested) {
          dead.push(name);
        } else {
          unknown.push(name);
        }
      }
      ok.sort((a: LatRow, b: LatRow) => a.ms - b.ms);
      this.latOk = ok;
      this.latDead = dead;
      this.latUnknown = unknown;
      this.latByName = byName;
    } catch (e) {
      // latency card is best-effort
    }
  }

  private async loadGrpCur(api: HonkCoreApi): Promise<void> {
    try {
      const gs = await api.nGroups();
      const rows: GrpCur[] = [];
      for (const g of gs) {
        const sel = jObj(g, 'selection');
        const cur = sel !== undefined ? jStr(sel, 'tcp_member_id') : '';
        if (cur === '') {
          continue;
        }
        const r = new GrpCur();
        r.name = jStr(g, 'name');
        r.sel = this.nameById.get(cur) ?? cur;
        const ms = this.latByName.get(r.sel);
        r.ms = ms !== undefined ? ms : -1;
        rows.push(r);
      }
      this.grpCur = rows;
    } catch (e) {
      // best-effort
    }
  }

  private async loadMem(api: HonkCoreApi): Promise<void> {
    try {
      const m = await api.nRuntimeMemory();
      const proc = jObj(m, 'process');
      const rss = proc !== undefined ? jNum(proc, 'rss_bytes') : 0;
      if (rss > 0) {
        this.memBytes = rss;
      }
      const rows: KV[] = [];
      this.pushKv(rows, t('honk_rss'), rss > 0 ? fmtBytes(rss) : '-');
      const cg = jObj(m, 'cgroup');
      if (cg !== undefined) {
        const cur = jNum(cg, 'current_bytes');
        const lim = jNum(cg, 'limit_bytes');
        this.pushKv(rows, t('honk_cgroup_used'), cur > 0 ? fmtBytes(cur) : '-');
        this.pushKv(rows, t('honk_cgroup_limit'), lim > 0 ? fmtBytes(lim) : '-');
        this.pushKv(rows, t('honk_cgroup_scope'), jStr(cg, 'scope'));
        const ev = jObj(cg, 'events');
        if (ev !== undefined) {
          this.pushKv(rows, 'high', jStr(ev, 'high'));
          this.pushKv(rows, 'oom', jStr(ev, 'oom'));
          this.pushKv(rows, 'oom_kill', jStr(ev, 'oom_kill'));
        }
      }
      const kernel = jObj(m, 'kernel');
      if (kernel !== undefined) {
        const eb = jNum(kernel, 'ebpf_bytes');
        this.pushKv(rows, t('honk_ebpf_mem'), eb > 0 ? fmtBytes(eb) : '-');
      }
      this.memRows = rows;
    } catch (e) {
      // best-effort
    }
  }

  private async loadDns(api: HonkCoreApi): Promise<void> {
    try {
      const res = await api.nDnsLog('', 100);
      let entries = jArr(res, 'entries');
      if (entries === undefined || entries.length === 0) {
        entries = jArr(res, 'logs');
      }
      if (entries === undefined || entries.length === 0) {
        entries = jArr(res, 'records');
      }
      const rows: string[] = [];
      if (entries !== undefined) {
        for (const e of entries) {
          const o = e as JObj;
          const name = jStr(o, 'name') || jStr(o, 'domain') || jStr(o, 'question');
          if (name === '') {
            continue;
          }
          const ans = jStr(o, 'answer') || jStr(o, 'result') || jStr(o, 'status');
          rows.push(name + (ans !== '' ? ' → ' + ans : ''));
          if (rows.length >= 6) {
            break;
          }
        }
      }
      this.dnsRows = rows;
    } catch (e) {
      // best-effort
    }
  }

  private capLabel(key: string): string {
    const lk = 'cap_' + key;
    const v = t(lk);
    return v !== lk ? v : key;
  }

  private async loadStatic(api: HonkCoreApi): Promise<void> {
    const key = this.store.active !== null ? this.store.active.id : '';
    if (key === this.staticKey) {
      return;
    }
    this.staticKey = key;
    try {
      const v = await api.nVersionRaw();
      const rows: KV[] = [];
      const eng = jObj(v, 'engine');
      this.pushKv(rows, t('honk_engine'),
        (eng !== undefined ? jStr(eng, 'name') + ' ' + jStr(eng, 'version') : jStr(v, 'version')));
      const ap = jObj(v, 'api');
      if (ap !== undefined) {
        this.pushKv(rows, 'API', jStr(ap, 'name') + ' v' + jNum(ap, 'major').toString() +
          (jStr(ap, 'status') !== '' ? ' (' + jStr(ap, 'status') + ')' : ''));
      }
      const build = jObj(v, 'build');
      if (build !== undefined) {
        const rev = jStr(build, 'revision');
        const tgt = jStr(build, 'target');
        this.pushKv(rows, t('honk_build'),
          (rev !== '' ? rev.substring(0, Math.min(12, rev.length)) : '') +
          (tgt !== '' ? ' · ' + tgt : ''));
      }
      this.engineRows = rows;
    } catch (e) {
      // best-effort
    }
    try {
      const caps = await api.nCapabilities();
      const res = jObj(caps, 'resources');
      const on: string[] = [];
      const off: string[] = [];
      if (res !== undefined) {
        for (const k of Object.keys(res)) {
          const r = jObj(res, k);
          if (r === undefined) {
            continue;
          }
          const av = jGet(r, 'available');
          if (av === true) {
            on.push(this.capLabel(k));
          } else if (av === false) {
            off.push(this.capLabel(k));
          }
        }
      }
      this.capOn = on;
      this.capOff = off;
    } catch (e) {
      // best-effort
    }
  }

  private rankList(): RankRow[] {
    const agg = new Map<string, number>();
    for (const c of this.store.activeConns) {
      const key = this.rankTab === 0 ? c.meta.sourceIP :
        (c.meta.host !== '' ? c.meta.host : c.meta.destinationIP);
      if (key === '') {
        continue;
      }
      agg.set(key, (agg.get(key) ?? 0) + c.upload + c.download);
    }
    const rows: RankRow[] = [];
    agg.forEach((bytes: number, name: string) => {
      const r = new RankRow();
      r.name = name;
      r.bytes = bytes;
      rows.push(r);
    });
    rows.sort((a: RankRow, b: RankRow) => b.bytes - a.bytes);
    return rows.slice(0, 8);
  }

  private async loadOutbounds(api: HonkCoreApi): Promise<void> {
    try {
      const root = await api.nOutbounds();
      const arr = jArr(root, 'outbounds');
      const rows: ObRow[] = [];
      let obSum = 0;
      let upSum = 0;
      let downSum = 0;
      if (arr !== undefined) {
        for (const e of arr) {
          const o = e as JObj;
          const row = new ObRow();
          row.name = jStr(o, 'name') || jStr(o, 'id');
          row.kind = jStr(o, 'kind') || jStr(o, 'type');
          const active = jNum(o, 'active_connections');
          obSum += active;
          const up = jNum(o, 'upload_bytes');
          const down = jNum(o, 'download_bytes');
          row.active = active;
          row.up = up;
          row.down = down;
          upSum += up;
          downSum += down;
          row.note = (active > 0 ? active + ' conn' : '') +
            (up + down > 0 ? ' · ↓' + fmtBytes(down) + ' ↑' + fmtBytes(up) : '');
          rows.push(row);
        }
      }
      if (downSum > 0) {
        for (const r of rows) {
          r.pct = Math.round(r.down * 1000 / downSum) / 10;
        }
      }
      rows.sort((a: ObRow, b: ObRow) => b.down - a.down);
      this.obs = rows;
      this.obActive = obSum;
      this.obUpSum = upSum;
      this.obDownSum = downSum;
    } catch (e) {
      // outbounds are best-effort
    }
  }

  private async loadQs(api: HonkCoreApi): Promise<void> {
    try {
      const nodes = await api.nNodes();
      const map = new Map<string, string>();
      const latMap = new Map<string, number>();
      for (const n of nodes) {
        map.set(jStr(n, 'id'), jStr(n, 'name'));
        const health = jArr(n, 'health');
        let best = -1;
        if (health !== undefined) {
          for (const e of health) {
            const h = e as JObj;
            const v = jGet(h, 'latency_ms');
            if (jStr(h, 'state') === 'healthy' && typeof v === 'number') {
              if (best < 0 || (v as number) < best) {
                best = v as number;
              }
            }
          }
        }
        if (best >= 0) {
          latMap.set(jStr(n, 'name'), best);
        }
      }
      const groups = await api.nGroups();
      for (const g of groups) {
        map.set(jStr(g, 'id'), jStr(g, 'name'));
      }
      this.nameById = map;
      if (latMap.size > 0) {
        this.latByName = latMap;
      }
      // fetch every group's detail: the runtime selection gives the
      // live leaf node each group currently exits through
      const details = new Map<string, JObj>();
      for (const g of groups) {
        const gid = jStr(g, 'id');
        try {
          const d = await api.nGroupDetail(gid);
          details.set(gid, d);
        } catch (e) {
          // detail is best-effort per group
        }
      }
      const leafOf = (gid: string): string => {
        let cur = gid;
        for (let hop = 0; hop < 4; hop++) {
          const d = details.get(cur);
          if (d === undefined) {
            return cur === gid ? '' : cur;
          }
          const rt = jObj(d, 'runtime');
          const rsel = rt !== undefined ? jObj(rt, 'selection') : undefined;
          const tcp = rsel !== undefined ? jObj(rsel, 'tcp') : undefined;
          if (tcp === undefined) {
            return '';
          }
          const leaf = jStr(tcp, 'resolved_leaf_node_id');
          if (leaf !== '') {
            return leaf;
          }
          const mid = jStr(tcp, 'member_id');
          if (mid === '') {
            return '';
          }
          const isGroup = map.has(mid) && details.has(mid);
          if (!isGroup) {
            return mid;
          }
          cur = mid;
        }
        return cur;
      };
      // dropdown options: every group from the API (doona-style), the
      // synthetic Auto entry is added by qsOptionsSel()
      const out: QsGroup[] = [];
      for (const g of groups) {
        const gid = jStr(g, 'id');
        const q = new QsGroup();
        q.id = gid;
        const nm = map.get(gid);
        q.name = nm !== undefined ? nm : gid;
        const leaf = leafOf(gid);
        q.currentId = leaf;
        const ln = map.get(leaf);
        q.currentName = ln !== undefined ? ln : leaf;
        out.push(q);
      }
      this.qsGroups = out;
      // outbound mode from the config catch-all (the config text is
      // large: re-read at most every 12 s, our own writes set it first)
      if (Date.now() - this.modeLoadedAt > 12000) {
        this.modeLoadedAt = Date.now();
        try {
          const ms = await api.nModeState();
          this.qsModeTarget = ms.target;
          this.qsModeWritable = ms.writable;
        } catch (e) {
          // mode display is best-effort
        }
      }
      // displayed group: the forced group when a catch-all is set; in
      // auto mode the group carrying the most active connections, else
      // the first group with a live node, else the first group
      let disp = '';
      if (this.qsModeTarget !== '') {
        for (const q of out) {
          if (q.name === this.qsModeTarget) {
            disp = q.id;
          }
        }
      }
      if (disp === '') {
        let best = 0;
        for (const o of this.obs) {
          if (o.active > best) {
            for (const q of out) {
              if (q.name === o.name) {
                disp = q.id;
                best = o.active;
              }
            }
          }
        }
      }
      if (disp === '') {
        for (const q of out) {
          if (q.currentName !== '') {
            disp = q.id;
            break;
          }
        }
      }
      if (disp === '' && out.length > 0) {
        disp = out[0].id;
      }
      this.qsSelId = disp;
      for (const q of out) {
        if (q.id === disp) {
          this.qsLeafName = q.currentName;
        }
      }
    } catch (e) {
      // quick switch is best-effort
    }
  }

  /** Dropdown options: Auto first, then every group (doona-style). */
  private qsOptionsSel(): SelectOption[] {
    const opts: SelectOption[] = [];
    const auto: SelectOption = { value: t('honk_qs_auto') };
    opts.push(auto);
    for (const q of this.qsGroups) {
      const o: SelectOption = { value: q.name };
      opts.push(o);
    }
    return opts;
  }

  private qsSelIndex(): number {
    if (this.qsModeTarget === '') {
      return 0;
    }
    for (let i = 0; i < this.qsGroups.length; i++) {
      if (this.qsGroups[i].name === this.qsModeTarget) {
        return i + 1;
      }
    }
    return 0;
  }

  private qsSelName(): string {
    return this.qsModeTarget === '' ? t('honk_qs_auto') : this.qsModeTarget;
  }

  private qsSelLatSuffix(): string {
    const g = this.qsSelGroup();
    return g !== null ? this.qsLatSuffix(g) : '';
  }

  private qsSelGroup(): QsGroup | null {
    for (const q of this.qsGroups) {
      if (q.id === this.qsSelId) {
        return q;
      }
    }
    return this.qsGroups.length > 0 ? this.qsGroups[0] : null;
  }

  /** Dropdown pick: '' = auto (authored rules), a group name = force
   * all traffic through that group via the config catch-all rule.
   * Forcing rewrites the router's config, so it asks first (like doona);
   * returning to auto applies at once. */
  private pickMode(target: string): void {
    if (this.qsBusy || target === this.qsModeTarget) {
      return;
    }
    if (!this.qsModeWritable) {
      this.store.toast(t('honk_qs_readonly'));
      return;
    }
    if (target === '') {
      this.applyMode('');
      return;
    }
    this.getUIContext().showAlertDialog({
      title: t('honk_qs_global_title'),
      message: t('honk_qs_global_msg', target),
      autoCancel: true,
      primaryButton: {
        value: t('cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: t('honk_switch'),
        fontColor: this.store.palette().accent,
        action: () => {
          this.applyMode(target);
        }
      }
    });
  }

  private async applyMode(target: string): Promise<void> {
    const api = this.api();
    if (api === null || this.qsBusy) {
      return;
    }
    this.qsBusy = true;
    try {
      await api.nSetModeTarget(target);
      this.qsModeTarget = target;
      this.modeLoadedAt = Date.now();
      this.store.toast(t('act_ok', target === '' ? t('honk_qs_auto') : target));
      this.store.refreshProxies();
      await this.loadQs(api);
    } catch (e) {
      this.store.toast(errMsg(e as Object));
    }
    this.qsBusy = false;
  }

  /** Tapping a group on the outbound card jumps to the policy page with
   * that group open; picking a member there returns here automatically. */
  private jumpPick(g: QsGroup): void {
    this.store.honkPickGroup = g.id;
    this.store.tab = 1;
  }

  private latencyColor(ms: number): string {
    if (ms <= this.store.lowLatency) {
      return this.store.palette().good;
    }
    if (ms <= this.store.mediumLatency) {
      return this.store.palette().warn;
    }
    return this.store.palette().bad;
  }

  private qsLatSuffix(g: QsGroup): string {
    const ms = this.latByName.get(g.currentName);
    return ms !== undefined ? ' · ' + fmtMsInt(ms) + ' ms' : '';
  }

  private peak(): number {
    let p = 0;
    for (const x of this.store.trafficHistory) {
      p = Math.max(p, x.up, x.down);
    }
    return p;
  }

  @Builder
  kvCard(title: string, rows: KV[]) {
    Column() {
      Text(title).fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(this.store.palette().text)
        .margin({ bottom: 6 })
      ForEach(rows, (r: KV) => {
        Row() {
          Text(r.k).fontSize(13).fontColor(this.store.palette().subtle)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Blank()
          Text(r.v).fontSize(13).fontColor(this.store.palette().text)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 12 })
        }
        .width('100%')
        .padding({ top: 5, bottom: 5 })
      }, (r: KV) => r.k)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(18)
    .attributeModifier(this.store.glass('card'))
  }

  @Builder
  actExtra() {
    // group selections (all groups, with the selected node's latency)
    if (this.grpCur.length > 0) {
      Column() {
        Text(t('honk_group_current')).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().text)
          .margin({ bottom: 6 })
        ForEach(this.grpCur, (g: GrpCur) => {
          Row() {
            Text(g.name).fontSize(14).fontColor(this.store.palette().subtle)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Blank()
            Text(g.sel).fontSize(14).fontColor(this.store.palette().text)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ left: 12 })
            if (g.ms >= 0) {
              Text(fmtMsInt(g.ms) + ' ms').fontSize(12)
                .fontColor(this.latencyColor(g.ms))
                .margin({ left: 6 })
            }
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
        }, (g: GrpCur) => g.name)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(18)
      .attributeModifier(this.store.glass('card'))
    }

    // traffic ranking by device / domain, from the live connection list
    Column() {
      Row() {
        Text(t('honk_rank')).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().text).layoutWeight(1)
        SegTabs({
          pal: this.store.palette(),
          items: [t('honk_rank_device'), t('honk_rank_domain')],
          selected: this.rankTab,
          onSelect: (i: number) => {
            this.rankTab = i;
          }
        })
      }
      .width('100%')
      .margin({ bottom: 6 })
      if (this.rankList().length === 0) {
        Text(t('honk_no_rank')).fontSize(13).fontColor(this.store.palette().subtle)
          .padding({ top: 8, bottom: 8 })
      } else {
        ForEach(this.rankList(), (r: RankRow) => {
          Row() {
            Text(r.name).fontSize(14).fontColor(this.store.palette().text)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(fmtBytes(r.bytes)).fontSize(13).fontColor(this.store.palette().subtle)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
        }, (r: RankRow) => r.name)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(18)
    .attributeModifier(this.store.glass('card'))

    // node latency overview
    if (this.latOk.length > 0 || this.latDead.length > 0 || this.latUnknown.length > 0) {
      Column() {
        Text(t('honk_node_latency')).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().text)
          .margin({ bottom: 6 })
        if (this.latOk.length > 0) {
          Row() {
            Text(t('honk_lat_min')).fontSize(12).fontColor(this.store.palette().subtle)
              .layoutWeight(1)
            Text(fmtMsInt(this.latOk[0].ms) + ' ms').fontSize(13)
              .fontColor(this.latencyColor(this.latOk[0].ms))
          }
          .width('100%')
          Row() {
            Text(t('honk_lat_max')).fontSize(12).fontColor(this.store.palette().subtle)
              .layoutWeight(1)
            Text(fmtMsInt(this.latOk[this.latOk.length - 1].ms) + ' ms').fontSize(13)
              .fontColor(this.latencyColor(this.latOk[this.latOk.length - 1].ms))
          }
          .width('100%')
          .margin({ bottom: 4 })
          ForEach(this.showAllLat ? this.latOk : this.latOk.slice(0, 12), (r: LatRow) => {
            Row() {
              Text(r.name).fontSize(14).fontColor(this.store.palette().text)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              Text(fmtMsInt(r.ms) + ' ms').fontSize(13)
                .fontColor(this.latencyColor(r.ms))
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ top: 5, bottom: 5 })
          }, (r: LatRow) => r.name)
          if (this.latOk.length > 12) {
            Text(this.showAllLat ? t('honk_collapse') : t('honk_show_all', this.latOk.length.toString()))
              .fontSize(13)
              .fontColor(this.store.palette().accent)
              .padding({ top: 6, bottom: 2 })
              .onClick(() => {
                this.showAllLat = !this.showAllLat;
              })
          }
        }
        ForEach(this.latDead, (n: string) => {
          Text(n + ': ' + t('honk_unavail'))
            .fontSize(13)
            .fontColor(this.store.palette().bad)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ top: 3, bottom: 3 })
        }, (n: string) => n)
        ForEach(this.latUnknown, (n: string) => {
          Text(n + ': ' + t('honk_unknown'))
            .fontSize(13)
            .fontColor(this.store.palette().subtle)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ top: 3, bottom: 3 })
        }, (n: string) => n)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(18)
      .attributeModifier(this.store.glass('card'))
    }

    // per-outbound active connections
    Column() {
      Text(t('honk_conns')).fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(this.store.palette().text)
        .margin({ bottom: 6 })
      if (this.obActive === 0) {
        Text(t('honk_no_conn')).fontSize(13).fontColor(this.store.palette().subtle)
          .padding({ top: 6, bottom: 6 })
      } else {
        ForEach(this.obs.filter((o: ObRow) => o.active > 0), (o: ObRow) => {
          Row() {
            Text(o.name).fontSize(14).fontColor(this.store.palette().text)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(o.active.toString()).fontSize(13).fontColor(this.store.palette().subtle)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ top: 5, bottom: 5 })
        }, (o: ObRow) => o.name)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(18)
    .attributeModifier(this.store.glass('card'))

    // recent DNS queries
    Column() {
      Text(t('honk_dns_recent')).fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(this.store.palette().text)
        .margin({ bottom: 6 })
      if (this.dnsRows.length === 0) {
        Text(t('honk_no_dns')).fontSize(13).fontColor(this.store.palette().subtle)
          .padding({ top: 6, bottom: 6 })
      } else {
        ForEach(this.dnsRows, (r: string) => {
          Text(r).fontSize(13).fontColor(this.store.palette().text)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ top: 4, bottom: 4 })
        }, (r: string) => r)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(18)
    .attributeModifier(this.store.glass('card'))
  }

  @Builder
  sysCards() {
    this.kvCard(t('honk_sysstatus'), this.sysStatusRows)
    this.kvCard(t('honk_engine'), this.engineRows)
    this.kvCard(t('honk_traffic_count'), this.trafficRows)
    this.kvCard(t('honk_memory'), this.memRows)
    if (this.dpRows.length > 0) {
      this.kvCard(t('honk_datapath'), this.dpRows)
    }
    if (this.capOn.length > 0) {
      Column() {
        Text(t('honk_caps')).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().text)
          .margin({ bottom: 6 })
        ForEach(this.capOn, (c: string) => {
          Row({ space: 8 }) {
            Text('●').fontSize(10).fontColor(this.store.palette().good)
            Text(c).fontSize(14).fontColor(this.store.palette().text)
          }
          .padding({ top: 4, bottom: 4 })
        }, (c: string) => c)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(18)
      .attributeModifier(this.store.glass('card'))
    }
    Column() {
      Text(t('honk_disabled_feats')).fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(this.store.palette().text)
        .margin({ bottom: 6 })
      if (this.capOff.length === 0) {
        Text(t('honk_all_enabled')).fontSize(13).fontColor(this.store.palette().subtle)
          .padding({ top: 6, bottom: 6 })
      } else {
        ForEach(this.capOff, (c: string) => {
          Row({ space: 8 }) {
            Text('●').fontSize(10).fontColor(this.store.palette().subtle)
            Text(c).fontSize(14).fontColor(this.store.palette().subtle)
          }
          .padding({ top: 4, bottom: 4 })
        }, (c: string) => c)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(18)
    .attributeModifier(this.store.glass('card'))
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
            SegTabs({
              pal: this.store.palette(),
              items: [t('honk_activity'), t('honk_sysstatus')],
              selected: this.subTab,
              onSelect: (i: number) => {
                this.subTab = i;
              }
            })
            if (this.subTab === 0) {
            // status stats
            Column({ space: 14 }) {
              Row() {
                Column() {
                  Text(t('upload')).fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(fmtSpeed(this.rateUp > 0 ? this.rateUp : this.store.traffic.up)).fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor(this.store.palette().upText)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column() {
                  Text(t('download')).fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(fmtSpeed(this.rateDown > 0 ? this.rateDown : this.store.traffic.down)).fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor(this.store.palette().downText)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column() {
                  Text(t('honk_conns')).fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text((this.connTcp + this.connUdp).toString()).fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor(this.store.palette().text)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              Row() {
                Column() {
                  Text(t('honk_total_up')).fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(fmtBytes(this.totalUpL > 0 ? this.totalUpL : this.store.connTotalUp)).fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor(this.store.palette().text)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column() {
                  Text(t('honk_total_down')).fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(fmtBytes(this.totalDownL > 0 ? this.totalDownL : this.store.connTotalDown)).fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor(this.store.palette().text)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column() {
                  Text(t('honk_memory')).fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.memBytes > 0 ? fmtBytes(this.memBytes) : (this.store.memory > 0 ? fmtBytes(this.store.memory) : '-')).fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor(this.store.palette().text)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              Row() {
                Column() {
                  Text('CPU').fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.cpuText).fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor(this.store.palette().text)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column() {
                  Text(t('honk_uptime')).fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.uptimeSec > 0 ? fmtDuration(this.uptimeSec * 1000) : '-').fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor(this.store.palette().text)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column() {
                  Text(t('version')).fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.store.version.replace('honk ', '')).fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor(this.store.palette().text)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
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

            // outbound: Auto follows the authored rules; picking a
            // group forces all traffic through it (config catch-all).
            // Tap the node row to choose a node on the policy page.
            if (this.qsGroups.length > 0) {
              Column() {
                Text(t('honk_outbounds')).fontSize(16).fontWeight(FontWeight.Medium)
                  .fontColor(this.store.palette().text)
                  .margin({ bottom: 6 })
                Select(this.qsOptionsSel())
                  .selected(this.qsSelIndex())
                  .value(this.qsSelName())
                  .font({ size: 15 })
                  .fontColor(this.store.palette().text)
                  .backgroundColor(this.store.palette().chip)
                  .borderRadius(12)
                  .height(44)
                  .width('100%')
                  .onSelect((idx: number) => {
                    if (idx === 0) {
                      this.pickMode('');
                    } else if (idx > 0 && idx <= this.qsGroups.length) {
                      this.pickMode(this.qsGroups[idx - 1].name);
                    }
                  })
                Row() {
                  Text(this.qsLeafName + this.qsSelLatSuffix())
                    .fontSize(14)
                    .fontColor(this.store.palette().good)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  if (this.qsBusy) {
                    LoadingProgress().width(16).height(16).color(this.store.palette().accentUi)
                  } else {
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([this.store.palette().subtle])
                  }
                }
                .width('100%')
                .padding({ top: 10, bottom: 4 })
                .onClick(() => {
                  const g = this.qsSelGroup();
                  if (g !== null) {
                    this.jumpPick(g);
                  }
                })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .borderRadius(18)
              .attributeModifier(this.store.glass('card'))
            }

            // outbounds
            if (this.obs.length > 0) {
              Column() {
                Text(t('honk_out_traffic')).fontSize(16).fontWeight(FontWeight.Medium)
                  .fontColor(this.store.palette().text)
                  .margin({ bottom: 6 })
                ForEach(this.obs, (o: ObRow) => {
                  Column() {
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
                      if (o.down > 0) {
                        Text(o.pct.toString() + '%').fontSize(12).fontColor(this.store.palette().subtle)
                          .margin({ left: 6 })
                      }
                    }
                    .width('100%')
                    if (o.down > 0) {
                      Progress({ value: o.pct, total: 100, type: ProgressType.Linear })
                        .color(this.store.palette().down)
                        .backgroundColor(this.store.palette().chip)
                        .style({ strokeWidth: 4 })
                        .width('100%')
                        .margin({ top: 4 })
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

            this.actExtra()

            // degradations
            if (this.degs.length > 0) {
              Column() {
                Text(t('honk_notices') + ' (' + this.degs.length + ')')
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
            } else {
              this.sysCards()
            }
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
