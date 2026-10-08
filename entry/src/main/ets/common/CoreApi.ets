import { http, webSocket } from '@kit.NetworkKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import {
  Backend, CoreConfig, JObj, ProxyItem, ProxyProvider, RuleItem, RuleProvider,
  asObj, asNum, jArr, jBool, jHas, jNum, jObj, jStr, parseJsonObj, parseProxy
} from './Models';
import { t } from './I18n';

/** HTTP status error (4xx/5xx) */
export class ApiError extends Error {
  code: number = 0;

  constructor(code: number, msg: string) {
    super(msg);
    this.name = 'ApiError';
    this.code = code;
  }
}

/** Network-level error (unreachable, timeout, ...) */
export class NetError extends Error {
  code: number = 0;

  constructor(code: number, msg: string) {
    super(msg);
    this.name = 'NetError';
    this.code = code;
  }
}

export class VersionInfo {
  version: string = '';
  meta: boolean = false;
}

function enc(s: string): string {
  return encodeURIComponent(s);
}

function toMethod(m: string): http.RequestMethod {
  switch (m) {
    case 'POST':
      return http.RequestMethod.POST;
    case 'PUT':
      return http.RequestMethod.PUT;
    case 'DELETE':
      return http.RequestMethod.DELETE;
    case 'HEAD':
      return http.RequestMethod.HEAD;
    default:
      return http.RequestMethod.GET;
  }
}

/** Turns a low-level error into a short, localized message */
export function errMsg(e: Object): string {
  if (e instanceof ApiError) {
    const ae = e as ApiError;
    if (ae.code === 401) {
      return t('err_401');
    }
    return ae.message.length > 0 ? ae.message : 'HTTP ' + ae.code;
  }
  if (e instanceof NetError) {
    const ne = e as NetError;
    // NetworkKit http error codes: 2300007 connect failed, 2300028 timeout, 2300006 can't resolve host
    // Remote Communication Kit uses the matching codes 10079000xx
    if (ne.code === 2300007 || ne.code === 1007900007) {
      return t('err_connect');
    }
    if (ne.code === 2300028 || ne.code === 1007900028) {
      return t('err_timeout');
    }
    if (ne.code === 2300006 || ne.code === 1007900006) {
      return t('err_dns');
    }
    if (ne.code === 2300997 || ne.code === 1007900201) {
      return t('err_cleartext');
    }
    return ne.message.length > 0 ? ne.message : t('err_net_code', ne.code);
  }
  if (e instanceof Error) {
    const er = e as Error;
    return er.message.length > 0 ? er.message : er.name;
  }
  return String(e);
}

export class CoreApi {
  backend: Backend;

  constructor(backend: Backend) {
    this.backend = backend;
  }

  private url(path: string): string {
    return this.backend.baseUrl() + path;
  }

  private headers(withBody: boolean): Record<string, string> {
    const h: Record<string, string> = {};
    if (this.backend.secret.length > 0) {
      h['Authorization'] = 'Bearer ' + this.backend.secret;
    }
    if (withBody) {
      h['Content-Type'] = 'application/json';
    }
    return h;
  }

  private static failure(code: number, text: string): ApiError {
    const o = parseJsonObj(text);
    const msg = jStr(o, 'message');
    return new ApiError(code, msg.length > 0 ? msg : 'HTTP ' + code);
  }

  /** Sends a request and returns the body; throws ApiError on non-2xx and NetError on network errors */
  async call(method: string, path: string, body: string | null, timeoutMs: number): Promise<string> {
    if (method === 'PATCH') {
      // NetworkKit http only has a PATCH enum since API 26; for HarmonyOS 6.0 (API 20) PATCH goes through Remote Communication Kit
      return this.callRcp(method, path, body, timeoutMs);
    }
    const req = http.createHttp();
    const hasBody = body !== null || (method !== 'GET' && method !== 'DELETE' && method !== 'HEAD');
    const opts: http.HttpRequestOptions = {
      method: toMethod(method),
      header: this.headers(hasBody),
      connectTimeout: 8000,
      readTimeout: timeoutMs > 0 ? timeoutMs : 30000,
      expectDataType: http.HttpDataType.STRING
    };
    if (hasBody) {
      opts.extraData = body !== null ? body : '';
    }
    try {
      const resp = await req.request(this.url(path), opts);
      const text = typeof resp.result === 'string' ? resp.result as string : '';
      const code = resp.responseCode as number;
      if (code < 200 || code >= 300) {
        throw CoreApi.failure(code, text);
      }
      return text;
    } catch (e) {
      if (e instanceof ApiError) {
        throw e as ApiError;
      }
      const be = e as BusinessError;
      throw new NetError(be.code !== undefined ? be.code : -1, be.message !== undefined ? be.message : t('err_net'));
    } finally {
      req.destroy();
    }
  }

  private async callRcp(method: string, path: string, body: string | null, timeoutMs: number): Promise<string> {
    const headers: rcp.RequestHeaders = {};
    if (this.backend.secret.length > 0) {
      headers['authorization'] = 'Bearer ' + this.backend.secret;
    }
    headers['content-type'] = 'application/json';
    const cfg: rcp.SessionConfiguration = {
      requestConfiguration: {
        transfer: {
          timeout: {
            connectMs: 8000,
            transferMs: timeoutMs > 0 ? timeoutMs : 30000
          }
        }
      }
    };
    const session = rcp.createSession(cfg);
    try {
      const req = new rcp.Request(this.url(path), method, headers, body !== null ? body : '');
      const resp = await session.fetch(req);
      const rs = resp.toString();
      const text = rs !== null ? rs : '';
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw CoreApi.failure(resp.statusCode, text);
      }
      return text;
    } catch (e) {
      if (e instanceof ApiError) {
        throw e as ApiError;
      }
      const be = e as BusinessError;
      throw new NetError(be.code !== undefined ? be.code : -1, be.message !== undefined ? be.message : t('err_net'));
    } finally {
      session.close();
    }
  }

  private async getObj(path: string): Promise<JObj> {
    const t = await this.call('GET', path, null, 0);
    return parseJsonObj(t);
  }

  // ---------- core ----------
  async version(): Promise<VersionInfo> {
    const o = await this.getObj('/version');
    const v = new VersionInfo();
    v.version = jStr(o, 'version');
    v.meta = jBool(o, 'meta', false);
    return v;
  }

  async configs(): Promise<CoreConfig> {
    const o = await this.getObj('/configs');
    const tun = jObj(o, 'tun');
    const c = new CoreConfig();
    c.mode = jStr(o, 'mode').toLowerCase() || 'rule';
    c.logLevel = jStr(o, 'log-level') || 'info';
    c.allowLan = jBool(o, 'allow-lan', false);
    c.ipv6 = jBool(o, 'ipv6', false);
    c.tunEnable = jBool(tun, 'enable', false);
    c.tunStack = jStr(tun, 'stack');
    c.mixedPort = jNum(o, 'mixed-port');
    c.port = jNum(o, 'port');
    c.socksPort = jNum(o, 'socks-port');
    c.redirPort = jNum(o, 'redir-port');
    c.tproxyPort = jNum(o, 'tproxy-port');
    c.bindAddress = jStr(o, 'bind-address');
    const modes: string[] = [];
    const ma = jArr(o, 'modes');
    if (ma !== undefined) {
      for (const m of ma) {
        if (typeof m === 'string') {
          modes.push((m as string).toLowerCase());
        }
      }
    }
    if (modes.length > 0) {
      c.modes = modes;
    }
    return c;
  }

  async patchConfigs(body: JObj): Promise<void> {
    await this.call('PATCH', '/configs', JSON.stringify(body), 0);
  }

  async reloadConfigs(): Promise<void> {
    const b: JObj = { 'path': '', 'payload': '' };
    await this.call('PUT', '/configs?force=true', JSON.stringify(b), 0);
  }

  async restart(): Promise<void> {
    await this.call('POST', '/restart', '{}', 0);
  }

  async upgradeCore(): Promise<void> {
    await this.call('POST', '/upgrade', '{}', 120000);
  }

  async upgradeGeo(): Promise<void> {
    try {
      const b: JObj = { 'path': '', 'payload': '' };
      await this.call('POST', '/configs/geo', JSON.stringify(b), 120000);
    } catch (e) {
      if (e instanceof ApiError) {
        const ae = e as ApiError;
        if (ae.code !== 404 && ae.code !== 405) {
          throw ae;
        }
        await this.call('POST', '/upgrade/geo', '{}', 120000);
        return;
      }
      throw e as Error;
    }
  }

  async flushFakeIp(): Promise<void> {
    await this.call('POST', '/cache/fakeip/flush', null, 0);
  }

  async flushDns(): Promise<void> {
    await this.call('POST', '/cache/dns/flush', null, 0);
  }

  // ---------- proxies ----------
  async proxies(): Promise<Map<string, ProxyItem>> {
    const out = new Map<string, ProxyItem>();
    const root = await this.getObj('/proxies');
    const o = jObj(root, 'proxies');
    if (o === undefined) {
      return out;
    }
    for (const k of Object.keys(o)) {
      const v = asObj(o[k]);
      if (v !== undefined) {
        out.set(k, parseProxy(k, v));
      }
    }
    return out;
  }

  async selectProxy(group: string, name: string): Promise<void> {
    const b: JObj = { 'name': name };
    await this.call('PUT', '/proxies/' + enc(group), JSON.stringify(b), 0);
  }

  async unfixProxy(group: string): Promise<void> {
    await this.call('DELETE', '/proxies/' + enc(group), null, 0);
  }

  async proxyDelay(name: string, testUrl: string, timeout: number): Promise<number> {
    const t = await this.call('GET', '/proxies/' + enc(name) + '/delay?url=' + enc(testUrl) + '&timeout=' + timeout, null,
      timeout + 5000);
    return jNum(parseJsonObj(t), 'delay');
  }

  /** mihomo: GET /group/{name}/delay returns {node name: delay} */
  async groupDelay(name: string, testUrl: string, timeout: number): Promise<Map<string, number>> {
    const t = await this.call('GET', '/group/' + enc(name) + '/delay?url=' + enc(testUrl) + '&timeout=' + timeout, null,
      timeout + 30000);
    const o = parseJsonObj(t);
    const out = new Map<string, number>();
    for (const k of Object.keys(o)) {
      out.set(k, asNum(o[k]));
    }
    return out;
  }

  async proxyProviders(): Promise<ProxyProvider[]> {
    const out: ProxyProvider[] = [];
    const root = await this.getObj('/providers/proxies');
    const o = jObj(root, 'providers');
    if (o === undefined) {
      return out;
    }
    for (const k of Object.keys(o)) {
      const p = asObj(o[k]);
      if (p === undefined) {
        continue;
      }
      const vt = jStr(p, 'vehicleType');
      if (vt.toLowerCase() === 'compatible') {
        continue;
      }
      const pp = new ProxyProvider();
      pp.name = jStr(p, 'name') || k;
      pp.type = jStr(p, 'type');
      pp.vehicleType = vt;
      const arr = jArr(p, 'proxies');
      if (arr !== undefined) {
        for (const e of arr) {
          const eo = asObj(e);
          if (eo !== undefined) {
            pp.proxies.push(parseProxy(jStr(eo, 'name'), eo));
          }
        }
      }
      pp.updatedAt = jStr(p, 'updatedAt');
      pp.testUrl = jStr(p, 'testUrl');
      const sub = jObj(p, 'subscriptionInfo');
      pp.subUpload = jNum(sub, 'Upload');
      pp.subDownload = jNum(sub, 'Download');
      pp.subTotal = jNum(sub, 'Total');
      pp.subExpire = jNum(sub, 'Expire');
      out.push(pp);
    }
    return out;
  }

  async updateProxyProvider(name: string): Promise<void> {
    await this.call('PUT', '/providers/proxies/' + enc(name), null, 60000);
  }

  async healthcheckProvider(name: string): Promise<void> {
    await this.call('GET', '/providers/proxies/' + enc(name) + '/healthcheck', null, 60000);
  }

  // ---------- rules ----------
  async rules(): Promise<RuleItem[]> {
    const out: RuleItem[] = [];
    const root = await this.getObj('/rules');
    const a = jArr(root, 'rules');
    if (a === undefined) {
      return out;
    }
    for (let idx = 0; idx < a.length; idx++) {
      const o = asObj(a[idx]);
      if (o === undefined) {
        continue;
      }
      const extra = jObj(o, 'extra');
      const r = new RuleItem();
      r.index = jHas(o, 'index') ? jNum(o, 'index') : idx;
      r.type = jStr(o, 'type');
      r.payload = jStr(o, 'payload');
      r.proxy = jStr(o, 'proxy');
      r.size = jHas(o, 'size') ? jNum(o, 'size') : -1;
      r.disabled = jBool(extra, 'disabled', false);
      r.hitCount = jNum(extra, 'hitCount');
      out.push(r);
    }
    return out;
  }

  /** mihomo >= 1.19.x: PATCH /rules/disable {"index": true|false} */
  async setRuleDisabled(index: number, disabled: boolean): Promise<void> {
    const b: JObj = {};
    b[index.toString()] = disabled;
    await this.call('PATCH', '/rules/disable', JSON.stringify(b), 0);
  }

  async ruleProviders(): Promise<RuleProvider[]> {
    const out: RuleProvider[] = [];
    const root = await this.getObj('/providers/rules');
    const o = jObj(root, 'providers');
    if (o === undefined) {
      return out;
    }
    for (const k of Object.keys(o)) {
      const p = asObj(o[k]);
      if (p === undefined) {
        continue;
      }
      const rp = new RuleProvider();
      rp.name = jStr(p, 'name') || k;
      rp.behavior = jStr(p, 'behavior');
      rp.format = jStr(p, 'format');
      rp.vehicleType = jStr(p, 'vehicleType');
      rp.ruleCount = jNum(p, 'ruleCount');
      rp.updatedAt = jStr(p, 'updatedAt');
      out.push(rp);
    }
    out.sort((a: RuleProvider, b: RuleProvider) => a.name.localeCompare(b.name));
    return out;
  }

  async updateRuleProvider(name: string): Promise<void> {
    await this.call('PUT', '/providers/rules/' + enc(name), null, 60000);
  }

  // ---------- connections ----------
  async closeConnection(id: string): Promise<void> {
    await this.call('DELETE', '/connections/' + enc(id), null, 0);
  }

  async closeAllConnections(): Promise<void> {
    await this.call('DELETE', '/connections', null, 0);
  }

  // ---------- websocket ----------
  wsUrl(path: string): string {
    let u = this.url(path);
    if (u.startsWith('https://')) {
      u = 'wss://' + u.substring(8);
    } else if (u.startsWith('http://')) {
      u = 'ws://' + u.substring(7);
    }
    if (this.backend.secret.length > 0) {
      u += (u.indexOf('?') >= 0 ? '&' : '?') + 'token=' + enc(this.backend.secret);
    }
    return u;
  }

  openStream(path: string, onMsg: (text: string) => void): WsStream {
    const s = new WsStream(this.wsUrl(path), this.headers(false), onMsg);
    s.start();
    return s;
  }

  static validate(b: Backend): boolean {
    if (b.host.trim().length === 0) {
      return false;
    }
    const p = Number(b.port);
    return !isNaN(p) && p > 0 && p < 65536;
  }
}

/** Auto-reconnecting WebSocket stream (Kotlin ws() + stream() with backoff) */
export class WsStream {
  private url: string;
  private headers: Record<string, string>;
  private onMsg: (text: string) => void;
  private ws: webSocket.WebSocket | null = null;
  private stopped: boolean = false;
  private backoff: number = 1000;
  private timer: number = -1;
  private gen: number = 0;
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  constructor(url: string, headers: Record<string, string>, onMsg: (text: string) => void) {
    this.url = url;
    this.headers = headers;
    this.onMsg = onMsg;
  }

  start(): void {
    if (this.stopped) {
      return;
    }
    this.gen++;
    const myGen = this.gen;
    const ws = webSocket.createWebSocket();
    this.ws = ws;
    ws.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
      if (myGen !== this.gen || this.stopped) {
        return;
      }
      this.backoff = 1000;
      if (typeof data === 'string') {
        this.deliver(data as string);
      } else {
        try {
          const t = this.decoder.decodeToString(new Uint8Array(data as ArrayBuffer));
          this.deliver(t);
        } catch (e) {
          // ignore
        }
      }
    });
    ws.on('close', () => {
      this.onDrop(myGen);
    });
    ws.on('error', () => {
      this.onDrop(myGen);
    });
    const opts: webSocket.WebSocketRequestOptions = { header: this.headers };
    ws.connect(this.url, opts).catch(() => {
      this.onDrop(myGen);
    });
  }

  private deliver(t: string): void {
    // mihomo may send several JSON lines in one message
    if (t.indexOf('\n') >= 0) {
      const lines = t.split('\n');
      for (const l of lines) {
        if (l.trim().length > 0) {
          this.onMsg(l);
        }
      }
    } else {
      this.onMsg(t);
    }
  }

  private onDrop(myGen: number): void {
    if (myGen !== this.gen || this.stopped) {
      return;
    }
    this.gen++;
    this.dispose();
    const delay = this.backoff;
    this.backoff = Math.min(this.backoff * 2, 10000);
    this.timer = setTimeout(() => {
      this.timer = -1;
      this.start();
    }, delay);
  }

  private dispose(): void {
    const ws = this.ws;
    this.ws = null;
    if (ws !== null) {
      try {
        ws.off('message');
        ws.off('close');
        ws.off('error');
        ws.close().catch(() => {
        });
      } catch (e) {
        // ignore
      }
    }
  }

  stop(): void {
    this.stopped = true;
    this.gen++;
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
    this.dispose();
  }
}
