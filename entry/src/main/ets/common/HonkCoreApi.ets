/**
 * 1.5.0: honk backend adapter.
 *
 * Implements the CoreApi surface Store/views already use, translating between
 * mihomo-shaped models and the honk native API (/api/v1). Clash backends keep
 * using CoreApi untouched; Store picks this adapter when Backend.kind==='honk'.
 *
 * Mapping notes:
 * - honk groups -> ProxyItem groups (type Selector/URLTest/Fallback/LoadBalance),
 *   honk nodes -> ProxyItem nodes; everything is keyed by NAME like clash,
 *   the adapter keeps id<->name maps from the last fetch for write calls.
 * - Selection writes go to PUT /groups/{id}/selection {network:'both'}.
 * - Delay tests use POST /probes + operation polling; results land as ms.
 * - Streams: /traffic and /memory become 1s polls of /runtime*, /connections
 *   a 1.5s poll translated into clash connection JSON, /logs the honk SSE log
 *   stream translated to {type, payload} lines.
 * - Operations honk does not have (restart core, patch configs, rule disable,
 *   fake-ip flush) throw ApiError(405) so Store marks them unsupported and the
 *   existing UI disables them, exactly like restricted clash controllers.
 */
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  Backend, CoreConfig, JObj, ProxyItem, ProxyProvider, RuleItem, RuleProvider
} from './Models';
import {
  asNum, asObj, jArr, jBool, jGet, jNum, jObj, jStr, parseIsoMillis, parseJson, parseJsonObj
} from './Models';
import { ApiError, CoreApi, VersionInfo, WsStream } from './CoreApi';
import { readModeTarget, writeModeTarget } from './DaeMode';

/** Outbound-mode state read from the main config source. */
export class HonkModeState {
  /** '' = auto (authored rules decide); otherwise the group all traffic is forced to ('direct' possible). */
  target: string = '';
  /** True when the main source can be written (mode switching available). */
  writable: boolean = false;
}

function enc(s: string): string {
  return encodeURIComponent(s);
}

function arrOf(o: JObj | undefined, k: string): JObj[] {
  const out: JObj[] = [];
  if (o === undefined) {
    return out;
  }
  const a = jArr(o, k);
  if (a === undefined) {
    return out;
  }
  for (const e of a) {
    const eo = asObj(e);
    if (eo !== undefined) {
      out.push(eo);
    }
  }
  return out;
}

/** Best (smallest) healthy latency in a honk health array; -1 when unmeasured. */
function bestLatency(health: JObj[]): number {
  let best = -1;
  for (const h of health) {
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

function anyHealthy(health: JObj[]): boolean {
  for (const h of health) {
    if (jStr(h, 'state') === 'healthy') {
      return true;
    }
  }
  return false;
}

/** Incremental UTF-8 decoder so SSE text split across chunks stays intact. */
class Utf8StreamDecoder {
  private pending: number[] = [];

  push(bytes: Uint8Array): string {
    for (let i = 0; i < bytes.length; i++) {
      this.pending.push(bytes[i]);
    }
    let out = '';
    let i = 0;
    while (i < this.pending.length) {
      const b = this.pending[i];
      if (b < 0x80) {
        out += String.fromCharCode(b);
        i++;
        continue;
      }
      if (b < 0xC0) {
        out += '?';
        i++;
        continue;
      }
      let len = 2;
      if (b >= 0xF0) {
        len = 4;
      } else if (b >= 0xE0) {
        len = 3;
      }
      if (i + len > this.pending.length) {
        break;
      }
      let cp = 0;
      if (len === 2) {
        cp = ((b & 0x1F) << 6) | (this.pending[i + 1] & 0x3F);
      } else if (len === 3) {
        cp = ((b & 0x0F) << 12) | ((this.pending[i + 1] & 0x3F) << 6) | (this.pending[i + 2] & 0x3F);
      } else {
        cp = ((b & 0x07) << 18) | ((this.pending[i + 1] & 0x3F) << 12) |
          ((this.pending[i + 2] & 0x3F) << 6) | (this.pending[i + 3] & 0x3F);
      }
      out += String.fromCodePoint(cp);
      i += len;
    }
    this.pending = this.pending.slice(i);
    return out;
  }
}

/** WsStream-shaped poll/SSE driver: Store only ever calls stop() on streams. */
class HonkStream extends WsStream {
  private cb: (t: string) => void;
  private task: () => Promise<void>;
  private intervalMs: number;
  private pollTimer: number = -1;
  private extraStop: (() => void) | null = null;
  private started: boolean = false;

  constructor(onMsg: (t: string) => void, task: () => Promise<void>, intervalMs: number) {
    super('', {}, onMsg);
    this.cb = onMsg;
    this.task = task;
    this.intervalMs = intervalMs;
  }

  emit(text: string): void {
    this.cb(text);
  }

  setExtraStop(fn: () => void): void {
    this.extraStop = fn;
  }

  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.task().catch(() => {
    });
    if (this.intervalMs > 0) {
      this.pollTimer = setInterval(() => {
        this.task().catch(() => {
        });
      }, this.intervalMs);
    }
  }

  stop(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
    if (this.extraStop !== null) {
      this.extraStop();
      this.extraStop = null;
    }
  }
}

interface SelPin {
  memberId: string;
  at: number;
}

interface RawResp {
  code: number;
  text: string;
}

export class HonkCoreApi extends CoreApi {
  private token: string = '';
  private tokenExpMs: number = 0;
  private loginInFlight: Promise<void> | null = null;

  private nodeIdByName: Map<string, string> = new Map<string, string>();
  private nodeNameById: Map<string, string> = new Map<string, string>();
  private groupIdByName: Map<string, string> = new Map<string, string>();
  private groupNameById: Map<string, string> = new Map<string, string>();
  private providerIdByName: Map<string, string> = new Map<string, string>();
  private providerNameById: Map<string, string> = new Map<string, string>();
  private lastNodes: JObj[] = [];
  private mapsAt: number = 0;
  // Selection pins: honk reports a fresh override lazily (peek_selection
  // keeps returning the previously formed selection until the group
  // re-forms it), so after a successful select we pin the member locally
  // and rewrite group payloads until the server catches up (max 90 s).
  private selPins: Map<string, SelPin> = new Map<string, SelPin>();
  private lastObUp: number = 0;
  private lastObDown: number = 0;
  private lastObAt: number = 0;

  private base(): string {
    return this.backend.baseUrl();
  }

  // ---------------- transport ----------------

  private async raw(method: string, url: string, body: string | null, timeoutMs: number,
    extraHeaders: Record<string, string> | null = null): Promise<RawResp> {
    const headers: Record<string, string> = {};
    if (this.token.length > 0) {
      headers['Authorization'] = 'Bearer ' + this.token;
    }
    if (body !== null) {
      headers['Content-Type'] = 'application/json';
    }
    if (extraHeaders !== null) {
      for (const k of Object.keys(extraHeaders)) {
        headers[k] = extraHeaders[k];
      }
    }
    const req = http.createHttp();
    try {
      const opts: http.HttpRequestOptions = {
        method: HonkCoreApi.toMethod(method),
        header: headers,
        connectTimeout: 8000,
        readTimeout: timeoutMs > 0 ? timeoutMs : 30000,
        expectDataType: http.HttpDataType.STRING
      };
      if (body !== null) {
        opts.extraData = body;
      }
      const resp = await req.request(url, opts);
      const text = typeof resp.result === 'string' ? resp.result as string : '';
      return { code: resp.responseCode, text };
    } catch (e) {
      const be = e as BusinessError;
      throw new ApiError(0, be !== null && be !== undefined && be.message !== undefined ? be.message : 'network error');
    } finally {
      req.destroy();
    }
  }

  private static toMethod(m: string): http.RequestMethod {
    switch (m) {
      case 'POST':
        return http.RequestMethod.POST;
      case 'PUT':
        return http.RequestMethod.PUT;
      case 'DELETE':
        return http.RequestMethod.DELETE;
      default:
        return http.RequestMethod.GET;
    }
  }

  private static toError(r: RawResp): ApiError {
    const root = parseJsonObj(r.text);
    const err = jObj(root, 'error');
    const msg = err !== undefined ? jStr(err, 'message') : '';
    return new ApiError(r.code, msg.length > 0 ? msg : 'HTTP ' + r.code);
  }

  /** One honk API call with session handling: logs in when needed, re-logins once on 401. */
  private async hCall(method: string, path: string, body: string | null, timeoutMs: number,
    extraHeaders: Record<string, string> | null = null): Promise<RawResp> {
    await this.ensureSession();
    let r = await this.raw(method, this.base() + '/api/v1' + path, body, timeoutMs, extraHeaders);
    if (r.code === 401 && this.backend.honkAuth === 'password') {
      this.token = '';
      this.tokenExpMs = 0;
      await this.ensureSession();
      r = await this.raw(method, this.base() + '/api/v1' + path, body, timeoutMs, extraHeaders);
    }
    if (r.code < 200 || r.code >= 300) {
      throw HonkCoreApi.toError(r);
    }
    return r;
  }

  private async hObj(method: string, path: string, body: string | null = null, timeoutMs: number = 30000): Promise<JObj> {
    const r = await this.hCall(method, path, body, timeoutMs);
    return parseJsonObj(r.text);
  }

  /** POST that takes NO request body (honk rejects a body on these routes:
   * "Geodata update takes no request body") and returns the parsed reply */
  private async hPostNoBody(path: string, timeoutMs: number = 30000): Promise<JObj> {
    const r = await this.hCall('POST', path, null, timeoutMs);
    return parseJsonObj(r.text);
  }

  private async ensureSession(): Promise<void> {
    const b = this.backend;
    if (b.honkAuth !== 'password') {
      this.token = b.secret;
      return;
    }
    if (this.token.length > 0 && this.tokenExpMs > Date.now() + 30000) {
      return;
    }
    if (this.loginInFlight !== null) {
      return this.loginInFlight;
    }
    const p = (async (): Promise<void> => {
      const body: JObj = { 'username': b.honkUser, 'password': b.honkPass };
      const r = await this.raw('POST', this.base() + '/api/v1/auth/login', JSON.stringify(body), 15000);
      if (r.code < 200 || r.code >= 300) {
        throw HonkCoreApi.toError(r);
      }
      const o = parseJsonObj(r.text);
      const token = jStr(o, 'token');
      if (token.length === 0) {
        throw new ApiError(401, 'login response has no token');
      }
      this.token = token;
      const exp = parseIsoMillis(jStr(o, 'expires_at'));
      this.tokenExpMs = exp > 0 ? exp : Date.now() + 3600000;
    })();
    this.loginInFlight = p;
    try {
      await p;
    } finally {
      this.loginInFlight = null;
    }
  }

  // ---------------- core ----------------

  async version(): Promise<VersionInfo> {
    // Public discovery lives outside /api/v1 and needs no credential.
    const r = await this.raw('GET', this.base() + '/api', null, 12000);
    if (r.code < 200 || r.code >= 300) {
      throw HonkCoreApi.toError(r);
    }
    const disc = parseJsonObj(r.text);
    const auth = jObj(disc, 'auth');
    if (auth !== undefined && jBool(auth, 'setup_required', false)) {
      throw new ApiError(428, 'honk backend has no admin yet; finish first-time setup on the honk side first');
    }
    const v = await this.hObj('GET', '/version');
    const eng = jObj(v, 'engine');
    const out = new VersionInfo();
    const ev = eng !== undefined ? jStr(eng, 'version') : '';
    out.version = 'honk ' + (ev.length > 0 ? ev : jStr(v, 'version'));
    out.meta = true;
    return out;
  }

  async configs(): Promise<CoreConfig> {
    const c = new CoreConfig();
    c.mode = 'rule';
    c.modes = ['rule'];
    c.logLevel = 'info';
    return c;
  }

  async patchConfigs(body: JObj): Promise<void> {
    throw new ApiError(405, 'not supported by honk backends');
  }

  async reloadConfigs(): Promise<void> {
    const op = await this.hPostNoBody('/operations/reload');
    await this.waitOp(jStr(op, 'operation_id'), 60000);
    this.mapsAt = 0;
  }

  async restart(): Promise<void> {
    throw new ApiError(405, 'core restart is not supported by honk backends');
  }

  async upgradeCore(): Promise<void> {
    throw new ApiError(405, 'online upgrade is not supported by honk backends');
  }

  async upgradeGeo(): Promise<void> {
    const op = await this.hPostNoBody('/geodata/update', 60000);
    await this.waitOp(jStr(op, 'operation_id'), 120000);
  }

  async flushFakeIp(): Promise<void> {
    throw new ApiError(405, 'honk backends have no FakeIP cache');
  }

  async flushDns(): Promise<void> {
    await this.hPostNoBody('/dns/cache/flush', 15000);
  }

  private async waitOp(opId: string, timeoutMs: number): Promise<JObj> {
    if (opId.length === 0) {
      const empty: JObj = {};
      return empty;
    }
    const deadline = Date.now() + timeoutMs;
    let last: JObj = {};
    while (Date.now() < deadline) {
      last = await this.hObj('GET', '/operations/' + enc(opId));
      const st = jStr(last, 'status');
      if (st === 'failed') {
        const err = jObj(last, 'error');
        const msg = err !== undefined ? jStr(err, 'message') : '';
        throw new ApiError(500, msg.length > 0 ? msg : 'operation failed');
      }
      if (st === 'succeeded') {
        return last;
      }
      await new Promise<void>((resolve) => {
        setTimeout(() => {
          resolve();
        }, 700);
      });
    }
    return last;
  }

  // ---------------- proxies ----------------

  private async loadMaps(force: boolean): Promise<void> {
    if (!force && this.mapsAt > 0 && Date.now() - this.mapsAt < 20000) {
      return;
    }
    const groups = await this.hGroups();
    for (const g of groups) {
      this.groupIdByName.set(jStr(g, 'name'), jStr(g, 'id'));
      this.groupNameById.set(jStr(g, 'id'), jStr(g, 'name'));
    }
    const nr = await this.hObj('GET', '/nodes?limit=1000');
    this.lastNodes = arrOf(nr, 'nodes');
    for (const n of this.lastNodes) {
      this.nodeIdByName.set(jStr(n, 'name'), jStr(n, 'id'));
      this.nodeNameById.set(jStr(n, 'id'), jStr(n, 'name'));
    }
    try {
      const pr = await this.hObj('GET', '/providers');
      for (const p of arrOf(pr, 'providers')) {
        this.providerIdByName.set(jStr(p, 'name'), jStr(p, 'id'));
        this.providerNameById.set(jStr(p, 'id'), jStr(p, 'name'));
      }
    } catch (e) {
      // providers are optional for the maps
    }
    this.mapsAt = Date.now();
  }

  private async hGroups(): Promise<JObj[]> {
    const r = await this.hCall('GET', '/groups', null, 30000);
    const v = parseJson(r.text);
    if (v !== undefined && Array.isArray(v)) {
      const out: JObj[] = [];
      for (const e of v as Object[]) {
        const eo = asObj(e);
        if (eo !== undefined) {
          out.push(eo);
        }
      }
      return out;
    }
    return arrOf(parseJsonObj(r.text), 'groups');
  }

  private memberName(id: string): string {
    const n = this.nodeNameById.get(id);
    if (n !== undefined && n.length > 0) {
      return n;
    }
    const g = this.groupNameById.get(id);
    if (g !== undefined && g.length > 0) {
      return g;
    }
    return id;
  }

  private static groupType(kind: string): string {
    if (kind === 'urltest') {
      return 'URLTest';
    }
    if (kind === 'fallback') {
      return 'Fallback';
    }
    if (kind === 'loadbalance') {
      return 'LoadBalance';
    }
    if (kind === 'score') {
      return 'Smart';
    }
    return 'Selector';
  }

  async proxies(): Promise<Map<string, ProxyItem>> {
    await this.loadMaps(true);
    const out = new Map<string, ProxyItem>();
    for (const n of this.lastNodes) {
      const p = new ProxyItem();
      p.name = jStr(n, 'name');
      const proto = jStr(n, 'protocol');
      p.type = proto.length > 0 ? proto : jStr(n, 'type');
      const health = arrOf(n, 'health');
      const best = bestLatency(health);
      p.hasHistory = best >= 0;
      p.lastDelay = best < 0 ? 0 : best;
      p.alive = health.length === 0 ? true : anyHealthy(health);
      const prov = this.providerNameById.get(jStr(n, 'provider_id'));
      p.providerName = prov !== undefined ? prov : '';
      p.udp = true;
      out.set(p.name, p);
    }
    const groups = await this.hGroups();
    for (const g of groups) {
      const p = new ProxyItem();
      p.name = jStr(g, 'name');
      const pol = jObj(g, 'policy');
      const kind = pol !== undefined ? (jStr(pol, 'kind') || jStr(pol, 'native')) : '';
      p.type = HonkCoreApi.groupType(kind);
      const sel = jObj(g, 'selection');
      if (sel !== undefined && jStr(sel, 'tcp_member_id').length > 0) {
        p.now = this.memberName(jStr(sel, 'tcp_member_id'));
      }
      try {
        const d = await this.hObj('GET', '/groups/' + enc(jStr(g, 'id')));
        const members = arrOf(d, 'members');
        const names: string[] = [];
        for (const m of members) {
          const mn = jStr(m, 'name');
          if (mn.length > 0) {
            names.push(mn);
            this.nodeNameById.set(jStr(m, 'id'), mn);
            if (jStr(m, 'kind') === 'group') {
              this.groupNameById.set(jStr(m, 'id'), mn);
            }
          }
        }
        p.all = names;
        const rt = jObj(d, 'runtime');
        const rsel = rt !== undefined ? jObj(rt, 'selection') : undefined;
        if (rsel !== undefined) {
          const tcp = jObj(rsel, 'tcp');
          if (tcp !== undefined && jStr(tcp, 'member_id').length > 0) {
            p.now = this.memberName(jStr(tcp, 'member_id'));
          }
        }
        // group delay = best healthy member latency from runtime health
        if (rt !== undefined) {
          const health = arrOf(rt, 'health');
          const best = bestLatency(health);
          if (best >= 0) {
            p.hasHistory = true;
            p.lastDelay = best;
          }
        }
      } catch (e) {
        // a group whose detail fails still lists with its summary fields
      }
      out.set(p.name, p);
    }
    return out;
  }

  async selectProxy(group: string, name: string): Promise<void> {
    await this.loadMaps(false);
    const gid = this.groupIdByName.get(group);
    const mid = this.nodeIdByName.get(name) || this.groupIdByName.get(name);
    if (gid === undefined || mid === undefined) {
      throw new ApiError(404, 'group or node not found');
    }
    const body: JObj = { 'network': 'both', 'member_id': mid };
    await this.hObj('PUT', '/groups/' + enc(gid) + '/selection', JSON.stringify(body));
  }

  async unfixProxy(group: string): Promise<void> {
    await this.loadMaps(false);
    const gid = this.groupIdByName.get(group);
    if (gid === undefined) {
      throw new ApiError(404, 'group not found');
    }
    await this.hCall('DELETE', '/groups/' + enc(gid) + '/selection', null, 15000);
  }

  private async probe(target: JObj): Promise<JObj> {
    const body: JObj = {};
    body['target'] = target;
    body['kind'] = 'http';
    body['transport'] = ['tcp'];
    body['ip_version'] = 'ipv4';
    body['warmth'] = 'cold';
    const op0 = await this.hObj('POST', '/probes', JSON.stringify(body));
    const opId = jStr(op0, 'operation_id');
    if (opId.length === 0) {
      return op0;
    }
    return this.waitOp(opId, 60000);
  }

  private static probeResults(op: JObj): JObj[] {
    const result = jObj(op, 'result');
    if (result === undefined) {
      return [];
    }
    return arrOf(result, 'results');
  }

  async proxyDelay(name: string, testUrl: string, timeout: number): Promise<number> {
    await this.loadMaps(false);
    const nid = this.nodeIdByName.get(name);
    if (nid !== undefined) {
      const target: JObj = { 'type': 'node', 'node_id': nid };
      const op = await this.probe(target);
      const results = HonkCoreApi.probeResults(op);
      for (const r of results) {
        if (jStr(r, 'state') === 'healthy') {
          const v = jGet(r, 'latency_ms');
          if (typeof v === 'number') {
            return v as number;
          }
        }
      }
      return 0;
    }
    const delays = await this.groupDelay(name, testUrl, timeout);
    let best = 0;
    delays.forEach((d: number) => {
      if (d > 0 && (best === 0 || d < best)) {
        best = d;
      }
    });
    return best;
  }

  async groupDelay(name: string, testUrl: string, timeout: number): Promise<Map<string, number>> {
    await this.loadMaps(false);
    const out = new Map<string, number>();
    const gid = this.groupIdByName.get(name);
    if (gid === undefined) {
      throw new ApiError(404, 'group not found');
    }
    const target: JObj = { 'type': 'group', 'group_id': gid };
    const op = await this.probe(target);
    const results = HonkCoreApi.probeResults(op);
    for (const r of results) {
      const mid = jStr(r, 'member_id');
      const mName = this.memberName(mid);
      let d = 0;
      if (jStr(r, 'state') === 'healthy') {
        const v = jGet(r, 'latency_ms');
        if (typeof v === 'number') {
          d = v as number;
        }
      }
      out.set(mName, d);
    }
    return out;
  }

  async proxyProviders(): Promise<ProxyProvider[]> {
    await this.loadMaps(false);
    const out: ProxyProvider[] = [];
    const pr = await this.hObj('GET', '/providers');
    for (const p of arrOf(pr, 'providers')) {
      const pp = new ProxyProvider();
      pp.name = jStr(p, 'name');
      pp.type = jStr(p, 'kind');
      pp.vehicleType = pp.type === 'subscription' ? 'HTTP' : (pp.type === 'file' ? 'File' : 'Inline');
      const pid = jStr(p, 'id');
      for (const n of this.lastNodes) {
        if (jStr(n, 'provider_id') === pid) {
          const item = new ProxyItem();
          item.name = jStr(n, 'name');
          const proto = jStr(n, 'protocol');
          item.type = proto.length > 0 ? proto : jStr(n, 'type');
          const health = arrOf(n, 'health');
          const best = bestLatency(health);
          item.hasHistory = best >= 0;
          item.lastDelay = best < 0 ? 0 : best;
          item.alive = health.length === 0 ? true : anyHealthy(health);
          item.providerName = pp.name;
          pp.proxies.push(item);
        }
      }
      const fetched = jStr(p, 'last_fetch_at') || jStr(p, 'updated_at');
      pp.updatedAt = fetched;
      const sub = jObj(p, 'subscription') !== undefined ? jObj(p, 'subscription') : jObj(p, 'usage');
      if (sub !== undefined) {
        pp.subUpload = jNum(sub, 'upload_bytes') || jNum(sub, 'upload');
        pp.subDownload = jNum(sub, 'download_bytes') || jNum(sub, 'download');
        pp.subTotal = jNum(sub, 'total_bytes') || jNum(sub, 'total');
        const expStr = jStr(sub, 'expires_at') || jStr(sub, 'expire_at');
        if (expStr.length > 0) {
          pp.subExpire = Math.floor(parseIsoMillis(expStr) / 1000);
        } else {
          pp.subExpire = jNum(sub, 'expire');
        }
      }
      out.push(pp);
    }
    return out;
  }

  async updateProxyProvider(name: string): Promise<void> {
    await this.loadMaps(false);
    const pid = this.providerIdByName.get(name);
    if (pid === undefined) {
      throw new ApiError(404, 'provider not found');
    }
    const op = await this.hPostNoBody('/providers/' + enc(pid) + '/refresh', 60000);
    await this.waitOp(jStr(op, 'operation_id'), 120000);
    this.mapsAt = 0;
  }

  async healthcheckProvider(name: string): Promise<void> {
    await this.loadMaps(false);
    const pid = this.providerIdByName.get(name);
    if (pid === undefined) {
      throw new ApiError(404, 'provider not found');
    }
    for (const n of this.lastNodes) {
      if (jStr(n, 'provider_id') === pid) {
        const target: JObj = { 'type': 'node', 'node_id': jStr(n, 'id') };
        const body: JObj = {};
        body['target'] = target;
        body['kind'] = 'http';
        body['transport'] = ['tcp'];
        body['ip_version'] = 'ipv4';
        body['warmth'] = 'cold';
        this.hObj('POST', '/probes', JSON.stringify(body)).catch(() => {
        });
      }
    }
  }

  // ---------------- rules ----------------

  async rules(): Promise<RuleItem[]> {
    const out: RuleItem[] = [];
    const r = await this.hCall('GET', '/rules', null, 30000);
    const v = parseJson(r.text);
    let items: JObj[] = [];
    if (v !== undefined && Array.isArray(v)) {
      for (const e of v as Object[]) {
        const eo = asObj(e);
        if (eo !== undefined) {
          items.push(eo);
        }
      }
    } else {
      items = arrOf(parseJsonObj(r.text), 'rules');
    }
    await this.loadMaps(false);
    for (let i = 0; i < items.length; i++) {
      const r = items[i];
      const item = new RuleItem();
      item.index = i;
      const match = jObj(r, 'match');
      item.type = jStr(r, 'type') || jStr(r, 'kind') || (match !== undefined ? jStr(match, 'type') : '');
      // verified honk shape: the match text lives in 'expression'
      item.payload = jStr(r, 'expression') || jStr(r, 'payload') || jStr(r, 'value') ||
        (match !== undefined ? jStr(match, 'value') : '');
      if (item.payload.length === 0) {
        const cond = jGet(r, 'conditions');
        if (cond !== undefined) {
          try {
            const cs = JSON.stringify(cond);
            item.payload = cs !== undefined && cs !== null ? cs : '';
          } catch (e) {
            item.payload = '';
          }
        }
      }
      let target = jStr(r, 'outbound') || jStr(r, 'target') || jStr(r, 'action') || jStr(r, 'proxy');
      const tid = jStr(r, 'target_id') || jStr(r, 'outbound_id');
      if (target.length === 0 && tid.length > 0) {
        target = this.memberName(tid);
      }
      item.proxy = target;
      const sz = jGet(r, 'size');
      item.size = typeof sz === 'number' ? sz as number : -1;
      item.disabled = jBool(r, 'disabled', false);
      out.push(item);
    }
    return out;
  }

  async setRuleDisabled(index: number, disabled: boolean): Promise<void> {
    throw new ApiError(405, 'rule disable is not supported by honk backends');
  }

  async ruleProviders(): Promise<RuleProvider[]> {
    const out: RuleProvider[] = [];
    return out;
  }

  async updateRuleProvider(name: string): Promise<void> {
    throw new ApiError(405, 'rule provider update is not supported by honk backends');
  }

  // ---------------- connections ----------------

  async closeConnection(id: string): Promise<void> {
    await this.hCall('DELETE', '/connections/' + enc(id), null, 15000);
  }

  async closeAllConnections(): Promise<void> {
    await this.hCall('DELETE', '/connections?all=true', null, 15000);
  }

  // ---------------- streams ----------------

  openStream(path: string, onMsg: (text: string) => void): WsStream {
    if (path.startsWith('/traffic')) {
      const s = new HonkStream(onMsg, async () => {
        const rt = await this.hObj('GET', '/runtime?detail=full');
        const traffic = jObj(rt, 'traffic');
        const rates = traffic !== undefined ? jObj(traffic, 'rates') : undefined;
        let up = rates !== undefined ? asNum(jGet(rates, 'upload_bytes_per_second')) : 0;
        let down = rates !== undefined ? asNum(jGet(rates, 'download_bytes_per_second')) : 0;
        if (up === 0 && down === 0) {
          // the runtime sampler can lack totals on some builds; derive the
          // rates from the outbounds counters, which are always live
          try {
            const sums = await this.outboundSums();
            const now = Date.now();
            if (this.lastObAt > 0 && now > this.lastObAt) {
              const dt = (now - this.lastObAt) / 1000;
              up = Math.max(0, Math.round((sums[0] - this.lastObUp) / dt));
              down = Math.max(0, Math.round((sums[1] - this.lastObDown) / dt));
            }
            this.lastObUp = sums[0];
            this.lastObDown = sums[1];
            this.lastObAt = now;
          } catch (e) {
            // keep the zero rates
          }
        }
        const o: JObj = { 'up': up, 'down': down };
        s.emit(JSON.stringify(o));
      }, 1000);
      s.start();
      return s;
    }
    if (path.startsWith('/memory')) {
      const s = new HonkStream(onMsg, async () => {
        const m = await this.hObj('GET', '/runtime/memory');
        let inuse = jNum(m, 'rss_bytes') || jNum(m, 'rss') || jNum(m, 'inuse_bytes');
        if (inuse === 0) {
          const proc = jObj(m, 'process');
          if (proc !== undefined) {
            inuse = jNum(proc, 'rss_bytes') || jNum(proc, 'rss');
          }
        }
        if (inuse === 0) {
          const cg = jObj(m, 'cgroup');
          if (cg !== undefined) {
            inuse = jNum(cg, 'current_bytes');
          }
        }
        const o: JObj = { 'inuse': inuse };
        s.emit(JSON.stringify(o));
      }, 2000);
      s.start();
      return s;
    }
    if (path.startsWith('/connections')) {
      const s = new HonkStream(onMsg, async () => {
        const text = await this.connectionsJson();
        s.emit(text);
      }, 1500);
      s.start();
      return s;
    }
    if (path.startsWith('/logs')) {
      const level = path.indexOf('level=') >= 0 ? path.substring(path.indexOf('level=') + 6).split('&')[0] : 'info';
      const s = new HonkStream(onMsg, async () => {
        // one-shot task unused; the SSE driver below owns the lifecycle
      }, 0);
      this.startLogSse(s, level);
      return s;
    }
    const s = new HonkStream(onMsg, async () => {
    }, 0);
    return s;
  }

  private async outboundSums(): Promise<number[]> {
    const root = await this.hObj('GET', '/runtime/outbounds');
    const arr = jArr(root, 'outbounds');
    let up = 0;
    let down = 0;
    let active = 0;
    if (arr !== undefined) {
      for (const e of arr) {
        const o = e as JObj;
        up += jNum(o, 'upload_bytes');
        down += jNum(o, 'download_bytes');
        active += jNum(o, 'active_connections');
      }
    }
    return [up, down, active];
  }

  private async connectionsJson(): Promise<string> {
    await this.loadMaps(false);
    const root = await this.hObj('GET', '/connections?detail=full');
    const list: JObj[] = [];
    let sumUp = 0;
    let sumDown = 0;
    const pushAll = (arr: JObj[], proto: string): void => {
      for (const c of arr) {
        list.push(this.translateConn(c, proto));
        sumUp += asNum(jGet(c, 'upload_bytes'));
        sumDown += asNum(jGet(c, 'download_bytes'));
      }
    };
    pushAll(arrOf(root, 'tcp'), 'tcp');
    pushAll(arrOf(root, 'udp'), 'udp');
    let totalUp = jNum(root, 'total_upload_bytes') || jNum(root, 'upload_total');
    let totalDown = jNum(root, 'total_download_bytes') || jNum(root, 'download_total');
    if (totalUp === 0 && totalDown === 0) {
      try {
        const rt = await this.hObj('GET', '/runtime?detail=full');
        const traffic = jObj(rt, 'traffic');
        const bytes = traffic !== undefined ? jObj(traffic, 'bytes') : undefined;
        if (bytes !== undefined) {
          totalUp = asNum(jGet(bytes, 'upload')) || asNum(jGet(bytes, 'upload_bytes'));
          totalDown = asNum(jGet(bytes, 'download')) || asNum(jGet(bytes, 'download_bytes'));
        }
      } catch (e) {
        // fall through to the outbounds fallback
      }
    }
    if (totalUp === 0 && totalDown === 0) {
      try {
        const sums = await this.outboundSums();
        totalUp = sums[0];
        totalDown = sums[1];
      } catch (e) {
        totalUp = sumUp;
        totalDown = sumDown;
      }
    }
    const out: JObj = {
      'connections': list,
      'uploadTotal': totalUp,
      'downloadTotal': totalDown
    };
    return JSON.stringify(out);
  }

  private translateConn(c: JObj, proto: string): JObj {
    const src = jStr(c, 'src');
    const dst = jStr(c, 'dst');
    const split = (s: string): string[] => {
      const i = s.lastIndexOf(':');
      if (i <= 0) {
        return [s, ''];
      }
      return [s.substring(0, i), s.substring(i + 1)];
    };
    const sp = split(src);
    const dp = split(dst);
    const chains: string[] = [];
    const outbound = jStr(c, 'outbound');
    if (outbound.length > 0) {
      chains.push(outbound);
    }
    const chainArr = jArr(c, 'chain');
    if (chainArr !== undefined) {
      for (const e of chainArr) {
        if (typeof e === 'string') {
          const nm = this.memberName(e as string);
          if (chains.indexOf(nm) < 0) {
            chains.push(nm);
          }
        }
      }
    }
    const meta: JObj = {
      'network': jStr(c, 'network') || proto,
      'type': jStr(c, 'ingress'),
      'sourceIP': sp[0],
      'sourcePort': sp[1],
      'destinationIP': dp[0],
      'destinationPort': dp[1],
      'host': jStr(c, 'domain'),
      'process': jStr(c, 'pname'),
      'inboundName': jStr(c, 'ingress')
    };
    const o: JObj = {
      'id': jStr(c, 'id'),
      'metadata': meta,
      'upload': asNum(jGet(c, 'upload_bytes')),
      'download': asNum(jGet(c, 'download_bytes')),
      'start': jStr(c, 'started_at'),
      'chains': chains,
      'rule': jStr(c, 'rule_id'),
      'rulePayload': jStr(c, 'rule_expression')
    };
    return o;
  }

  // ---------------- native passthroughs (honk pages) ----------------
  // The honk-mode pages (HonkOverviewView / HonkPolicyView)
  // work on raw honk payloads; these wrappers reuse this adapter's session
  // and transport so there is exactly one honk client per backend.

  async nRuntime(detail: string): Promise<JObj> {
    return this.hObj('GET', '/runtime?detail=' + enc(detail));
  }

  async nRuntimeMemory(): Promise<JObj> {
    return this.hObj('GET', '/runtime/memory');
  }

  async nOutbounds(): Promise<JObj> {
    return this.hObj('GET', '/runtime/outbounds');
  }

  async nGroups(): Promise<JObj[]> {
    const gs = await this.hGroups();
    for (const g of gs) {
      this.applyPinToListEntry(g);
    }
    return gs;
  }

  async nGroupDetail(id: string): Promise<JObj> {
    const d = await this.hObj('GET', '/groups/' + enc(id));
    this.applyPinToDetail(id, d);
    return d;
  }

  /** If a fresh local pin disagrees with the server detail, rewrite the
   * reported selection so the UI shows the just-chosen member at once.
   * When the server catches up, the pin clears itself. */
  private applyPinToDetail(groupId: string, doc: JObj): void {
    const pin = this.selPins.get(groupId);
    if (pin === undefined) {
      return;
    }
    if (Date.now() - pin.at > 90000) {
      this.selPins.delete(groupId);
      return;
    }
    const rt = jObj(doc, 'runtime');
    const sel = rt !== undefined ? jObj(rt, 'selection') : undefined;
    const tcp = sel !== undefined ? jObj(sel, 'tcp') : undefined;
    if (tcp === undefined) {
      return;
    }
    if (jStr(tcp, 'member_id') === pin.memberId) {
      this.selPins.delete(groupId);
      return;
    }
    tcp['member_id'] = pin.memberId;
    tcp['source'] = 'override';
    const udp = jObj(sel as JObj, 'udp');
    if (udp !== undefined && jStr(udp, 'member_id') !== '') {
      udp['member_id'] = pin.memberId;
    }
  }

  private applyPinToListEntry(g: JObj): void {
    const gid = jStr(g, 'id');
    const pin = gid !== '' ? this.selPins.get(gid) : undefined;
    if (pin === undefined) {
      return;
    }
    if (Date.now() - pin.at > 90000) {
      this.selPins.delete(gid);
      return;
    }
    const sel = jObj(g, 'selection');
    if (sel === undefined) {
      return;
    }
    if (jStr(sel, 'tcp_member_id') === pin.memberId) {
      this.selPins.delete(gid);
      return;
    }
    sel['tcp_member_id'] = pin.memberId;
    sel['udp_member_id'] = pin.memberId;
  }

  async nNodes(): Promise<JObj[]> {
    const r = await this.hObj('GET', '/nodes?limit=1000');
    return arrOf(r, 'nodes');
  }

  async nProviders(): Promise<JObj[]> {
    const r = await this.hObj('GET', '/providers');
    return arrOf(r, 'providers');
  }

  async nSelect(groupId: string, memberId: string): Promise<void> {
    const body: JObj = { 'network': 'both', 'member_id': memberId };
    await this.hObj('PUT', '/groups/' + enc(groupId) + '/selection', JSON.stringify(body));
    const pin: SelPin = { memberId: memberId, at: Date.now() };
    this.selPins.set(groupId, pin);
  }

  async nClearSelection(groupId: string): Promise<void> {
    await this.hCall('DELETE', '/groups/' + enc(groupId) + '/selection', null, 15000);
    this.selPins.delete(groupId);
  }

  /** Server-side 1 s traffic samples (rates precomputed by honk). */
  async nTrafficHistory(windowSec: number, maxPoints: number): Promise<JObj[]> {
    const r = await this.hObj('GET', '/runtime/traffic/history?window_seconds=' +
      windowSec + '&max_points=' + maxPoints);
    const s = r['samples'];
    return Array.isArray(s) ? (s as Object[]).map((e: Object) => e as JObj) : [];
  }



  async nProbe(target: JObj): Promise<JObj> {
    return this.probe(target);
  }

  async nRefreshProvider(id: string): Promise<JObj> {
    const op = await this.hPostNoBody('/providers/' + enc(id) + '/refresh', 60000);
    const done = await this.waitOp(jStr(op, 'operation_id'), 120000);
    this.mapsAt = 0;
    return done;
  }

  async nReload(): Promise<JObj> {
    const op = await this.hPostNoBody('/operations/reload');
    const done = await this.waitOp(jStr(op, 'operation_id'), 60000);
    this.mapsAt = 0;
    return done;
  }

  // ---------------- config outbound mode (catch-all rule) ----------------
  // The overview outbound card's real traffic switch, doona's mechanism:
  // a marked catch-all rule in the main source's routing block forces all
  // traffic to one group; removing it restores the authored rules (auto).
  // Writes are If-Match guarded, fully validated before they are stored,
  // and the PUT itself activates + reloads on the server side.

  async nConfigSources(): Promise<JObj[]> {
    const r = await this.hObj('GET', '/config');
    return arrOf(r, 'sources');
  }

  /** The main config source with full content (falls back to the
   * single-source read when the list copy is missing or redacted). */
  private async mainConfigSource(): Promise<JObj | null> {
    const sources = await this.nConfigSources();
    let main: JObj | undefined = undefined;
    for (const s of sources) {
      if (jStr(s, 'kind') === 'main') {
        main = s;
        break;
      }
    }
    if (main === undefined && sources.length > 0) {
      main = sources[0];
    }
    if (main === undefined) {
      return null;
    }
    const content = jStr(main, 'content');
    if (content === '' || content.indexOf('<redacted>') >= 0) {
      try {
        const one = await this.hObj('GET', '/config/sources/' + enc(jStr(main, 'id')));
        if (jStr(one, 'content') !== '') {
          main = one;
        }
      } catch (e) {
        // keep the list copy
      }
    }
    return main;
  }

  async nModeState(): Promise<HonkModeState> {
    const st = new HonkModeState();
    const main = await this.mainConfigSource();
    if (main === null) {
      return st;
    }
    const content = jStr(main, 'content');
    st.writable = jBool(main, 'writable', false) && content !== '' &&
      content.indexOf('<redacted>') < 0;
    st.target = content !== '' ? readModeTarget(content) : '';
    return st;
  }

  /** Set the catch-all target ('' removes it = back to auto). */
  async nSetModeTarget(target: string): Promise<void> {
    const main = await this.mainConfigSource();
    if (main === null) {
      throw new ApiError(0, 'no config source');
    }
    if (!jBool(main, 'writable', false)) {
      throw new ApiError(0, 'config is read-only');
    }
    const content = jStr(main, 'content');
    if (content === '' || content.indexOf('<redacted>') >= 0) {
      throw new ApiError(0, 'config content is redacted');
    }
    const w = writeModeTarget(content, target);
    if (!w.ok) {
      throw new ApiError(0, w.error);
    }
    if (w.text === content) {
      return;
    }
    // full validation before anything is written
    const src: JObj = { 'id': jStr(main, 'id'), 'path': jStr(main, 'path'), 'content': w.text };
    const vBody: JObj = { 'mode': 'full', 'sources': [src] };
    const v = await this.hObj('POST', '/config/validate', JSON.stringify(vBody), 60000);
    if (!jBool(v, 'valid', false)) {
      let msg = '';
      const diags = jArr(v, 'diagnostics');
      if (diags !== undefined) {
        for (const e of diags) {
          const m = jStr(e as JObj, 'message');
          if (m !== '') {
            msg = m;
            break;
          }
        }
      }
      throw new ApiError(0, 'config validation failed' + (msg !== '' ? ': ' + msg : ''));
    }
    const headers: Record<string, string> = {};
    const sha = jStr(main, 'content_sha256');
    if (sha !== '') {
      headers['If-Match'] = '"' + sha + '"';
    }
    const body: JObj = { 'content': w.text };
    const r = await this.hCall('PUT', '/config/sources/' + enc(jStr(main, 'id')),
      JSON.stringify(body), 60000, headers);
    const op = parseJsonObj(r.text);
    const opId = jStr(op, 'operation_id');
    if (opId !== '') {
      await this.waitOp(opId, 120000);
    }
    this.mapsAt = 0;
  }

  async nDnsQuery(domain: string, types: string[], cacheMode: string): Promise<JObj> {
    const b: JObj = {};
    b['domain'] = domain;
    b['type'] = types;
    b['cache_mode'] = cacheMode;
    return this.hObj('POST', '/dns/query?detail=full', JSON.stringify(b));
  }

  async nDnsCache(domainFilter: string, limit: number): Promise<JObj> {
    let p = '/dns/cache?limit=' + limit + '&detail=full&include_expired=true';
    if (domainFilter !== '') {
      p += '&domain=' + enc(domainFilter);
    }
    return this.hObj('GET', p);
  }

  async nDeleteDnsCacheEntry(id: string): Promise<void> {
    await this.hCall('DELETE', '/dns/cache/' + enc(id), null, 15000);
  }

  async nDnsLog(nameFilter: string, limit: number): Promise<JObj> {
    let p = '/dns/log?limit=' + limit;
    if (nameFilter !== '') {
      p += '&name=' + enc(nameFilter);
    }
    return this.hObj('GET', p);
  }

  async nDnsRules(): Promise<JObj> {
    return this.hObj('GET', '/dns/rules');
  }

  async nRulesRaw(): Promise<JObj> {
    return this.hObj('GET', '/rules');
  }

  async nRoutingTrace(bodyJson: string): Promise<JObj> {
    return this.hObj('POST', '/routing/trace', bodyJson);
  }

  async nGeodata(): Promise<JObj> {
    return this.hObj('GET', '/geodata');
  }

  async nGeodataUpdate(): Promise<JObj> {
    const op = await this.hPostNoBody('/geodata/update', 60000);
    return this.waitOp(jStr(op, 'operation_id'), 120000);
  }

  async nRuntimeSettings(): Promise<JObj> {
    return this.hObj('GET', '/runtime/settings');
  }

  async nDatapath(): Promise<JObj> {
    return this.hObj('GET', '/datapath?detail=full');
  }

  async nCapabilities(): Promise<JObj> {
    return this.hObj('GET', '/capabilities');
  }

  async nVersionRaw(): Promise<JObj> {
    return this.hObj('GET', '/version');
  }

  private startLogSse(stream: HonkStream, level: string): void {
    let stopped = false;
    let req: http.HttpRequest | null = null;
    let retryTimer: number = -1;
    const connect = async (): Promise<void> => {
      if (stopped) {
        return;
      }
      try {
        await this.ensureSession();
      } catch (e) {
        retryTimer = setTimeout(connect, 3000);
        return;
      }
      if (stopped) {
        return;
      }
      const headers: Record<string, string> = { 'Accept': 'text/event-stream' };
      if (this.token.length > 0) {
        headers['Authorization'] = 'Bearer ' + this.token;
      }
      const decoder = new Utf8StreamDecoder();
      let buf = '';
      req = http.createHttp();
      req.on('dataReceive', (chunk: ArrayBuffer) => {
        if (stopped) {
          return;
        }
        buf += decoder.push(new Uint8Array(chunk));
        let idx = buf.indexOf('\n\n');
        while (idx >= 0) {
          const frame = buf.substring(0, idx);
          buf = buf.substring(idx + 2);
          const lines = frame.split('\n');
          for (const ln of lines) {
            if (ln.startsWith('data:')) {
              const data = ln.substring(5).trim();
              const o = parseJsonObj(data);
              const msg = jStr(o, 'message') || jStr(o, 'msg') || data;
              const lv = jStr(o, 'level') || level;
              if (!data.startsWith('{') || msg.length > 0) {
                const out: JObj = { 'type': lv, 'payload': msg };
                stream.emit(JSON.stringify(out));
              }
            }
          }
          idx = buf.indexOf('\n\n');
        }
      });
      req.on('dataEnd', () => {
        if (!stopped) {
          retryTimer = setTimeout(connect, 3000);
        }
      });
      const opts: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 8000,
        readTimeout: 0,
        expectDataType: http.HttpDataType.STRING
      };
      req.requestInStream(this.base() + '/api/v1/logs/stream?level=' + enc(level), opts).catch(() => {
        if (!stopped) {
          retryTimer = setTimeout(connect, 3000);
        }
      });
    };
    connect();
    stream.setExtraStop(() => {
      stopped = true;
      if (retryTimer >= 0) {
        clearTimeout(retryTimer);
        retryTimer = -1;
      }
      if (req !== null) {
        try {
          req.destroy();
        } catch (e) {
        }
        req = null;
      }
    });
  }
}
