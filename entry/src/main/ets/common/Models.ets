/**
 * Data models and JSON helpers (Kotlin data/Models.kt)
 * ArkTS has no any/unknown, so JSON objects are Record<string, Object>.
 */

export type JObj = Record<string, Object>;

// ---------------- JSON helpers ----------------

export function jGet(o: JObj | undefined | null, k: string): Object | undefined {
  if (o === undefined || o === null) {
    return undefined;
  }
  const v: Object | undefined = o[k];
  if (v === undefined || v === null) {
    return undefined;
  }
  return v;
}

export function jHas(o: JObj | undefined | null, k: string): boolean {
  return jGet(o, k) !== undefined;
}

export function asStr(v: Object | undefined | null): string {
  if (v === undefined || v === null) {
    return '';
  }
  if (typeof v === 'string') {
    return v as string;
  }
  if (typeof v === 'number' || typeof v === 'boolean') {
    return String(v);
  }
  return '';
}

export function jStr(o: JObj | undefined | null, k: string): string {
  return asStr(jGet(o, k));
}

export function asNum(v: Object | undefined | null): number {
  if (v === undefined || v === null) {
    return 0;
  }
  if (typeof v === 'number') {
    return v as number;
  }
  if (typeof v === 'string') {
    const n = Number(v as string);
    return isNaN(n) ? 0 : n;
  }
  return 0;
}

export function jNum(o: JObj | undefined | null, k: string): number {
  return asNum(jGet(o, k));
}

export function jBool(o: JObj | undefined | null, k: string, def: boolean): boolean {
  const v = jGet(o, k);
  if (v === undefined) {
    return def;
  }
  if (typeof v === 'boolean') {
    return v as boolean;
  }
  return def;
}

export function asObj(v: Object | undefined | null): JObj | undefined {
  if (v === undefined || v === null) {
    return undefined;
  }
  if (typeof v === 'object' && !Array.isArray(v)) {
    return v as JObj;
  }
  return undefined;
}

export function jObj(o: JObj | undefined | null, k: string): JObj | undefined {
  return asObj(jGet(o, k));
}

export function jArr(o: JObj | undefined | null, k: string): Object[] | undefined {
  const v = jGet(o, k);
  if (v !== undefined && Array.isArray(v)) {
    return v as Object[];
  }
  return undefined;
}

export function jStrArr(o: JObj | undefined | null, k: string): string[] {
  const a = jArr(o, k);
  const out: string[] = [];
  if (a === undefined) {
    return out;
  }
  for (const e of a) {
    if (typeof e === 'string') {
      out.push(e as string);
    }
  }
  return out;
}

export function parseJson(text: string): Object | undefined {
  if (text === undefined || text === null || text.trim().length === 0) {
    return undefined;
  }
  try {
    const v = JSON.parse(text) as Object;
    return v;
  } catch (e) {
    return undefined;
  }
}

export function parseJsonObj(text: string): JObj {
  const o = asObj(parseJson(text));
  if (o === undefined) {
    const empty: JObj = {};
    return empty;
  }
  return o;
}

// ---------------- models ----------------

export class Backend {
  id: string = '';
  protocol: string = 'http';
  host: string = '127.0.0.1';
  port: string = '9090';
  secondaryPath: string = '';
  secret: string = '';
  label: string = '';

  constructor(id: string) {
    this.id = id;
  }

  baseUrl(): string {
    let path = this.secondaryPath.trim();
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    const p = path.length === 0 ? '' : '/' + path;
    const h = (this.host.indexOf(':') >= 0 && !this.host.startsWith('[')) ? '[' + this.host + ']' : this.host;
    return this.protocol + '://' + h + ':' + this.port + p;
  }

  display(): string {
    return this.label.trim().length > 0 ? this.label : this.host + ':' + this.port;
  }

  copy(): Backend {
    const b = new Backend(this.id);
    b.protocol = this.protocol;
    b.host = this.host;
    b.port = this.port;
    b.secondaryPath = this.secondaryPath;
    b.secret = this.secret;
    b.label = this.label;
    return b;
  }

  toJson(): JObj {
    const o: JObj = {
      'id': this.id,
      'protocol': this.protocol,
      'host': this.host,
      'port': this.port,
      'secondaryPath': this.secondaryPath,
      'secret': this.secret,
      'label': this.label
    };
    return o;
  }

  static fromJson(o: JObj): Backend {
    const b = new Backend(jStr(o, 'id'));
    b.protocol = jStr(o, 'protocol') || 'http';
    b.host = jStr(o, 'host') || '127.0.0.1';
    b.port = jStr(o, 'port') || '9090';
    b.secondaryPath = jStr(o, 'secondaryPath');
    b.secret = jStr(o, 'secret');
    b.label = jStr(o, 'label');
    return b;
  }
}

export const GROUP_TYPES: string[] = ['selector', 'urltest', 'fallback', 'loadbalance', 'relay', 'smart'];

export class ProxyItem {
  name: string = '';
  type: string = '';
  now: string = '';
  all: string[] = [];
  lastDelay: number = 0;
  hasHistory: boolean = false;
  extraDelay: Map<string, number> = new Map<string, number>();
  icon: string = '';
  udp: boolean = false;
  xudp: boolean = false;
  tfo: boolean = false;
  hidden: boolean = false;
  testUrl: string = '';
  alive: boolean = true;
  providerName: string = '';
  fixed: string = '';

  isGroup(): boolean {
    return this.all.length > 0 || GROUP_TYPES.indexOf(this.type.toLowerCase()) >= 0;
  }

  delayFor(url: string): number {
    if (url.length > 0) {
      const d = this.extraDelay.get(url);
      if (d !== undefined) {
        return d;
      }
    }
    return this.lastDelay;
  }

  copy(): ProxyItem {
    const p = new ProxyItem();
    p.name = this.name;
    p.type = this.type;
    p.now = this.now;
    p.all = this.all;
    p.lastDelay = this.lastDelay;
    p.hasHistory = this.hasHistory;
    p.extraDelay = this.extraDelay;
    p.icon = this.icon;
    p.udp = this.udp;
    p.xudp = this.xudp;
    p.tfo = this.tfo;
    p.hidden = this.hidden;
    p.testUrl = this.testUrl;
    p.alive = this.alive;
    p.providerName = this.providerName;
    p.fixed = this.fixed;
    return p;
  }
}

function lastHistoryDelay(a: Object[] | undefined): number {
  if (a === undefined || a.length === 0) {
    return -1;
  }
  const last = asObj(a[a.length - 1]);
  return jNum(last, 'delay');
}

export function parseProxy(name: string, o: JObj): ProxyItem {
  const p = new ProxyItem();
  p.name = jStr(o, 'name') || name;
  p.type = jStr(o, 'type');
  p.now = jStr(o, 'now');
  p.all = jStrArr(o, 'all');
  const h = jArr(o, 'history');
  const d = lastHistoryDelay(h);
  p.hasHistory = d >= 0;
  p.lastDelay = d < 0 ? 0 : d;
  const extra = jObj(o, 'extra');
  if (extra !== undefined) {
    for (const url of Object.keys(extra)) {
      const eo = asObj(extra[url]);
      const ed = lastHistoryDelay(jArr(eo, 'history'));
      if (ed >= 0) {
        p.extraDelay.set(url, ed);
      }
    }
  }
  p.icon = jStr(o, 'icon').trim();
  p.udp = jBool(o, 'udp', false);
  p.xudp = jBool(o, 'xudp', false);
  p.tfo = jBool(o, 'tfo', false);
  p.hidden = jBool(o, 'hidden', false);
  p.testUrl = jStr(o, 'testUrl').trim();
  p.alive = jBool(o, 'alive', true);
  p.providerName = jStr(o, 'provider-name');
  p.fixed = jStr(o, 'fixed').trim();
  return p;
}

export class ProxyProvider {
  name: string = '';
  type: string = '';
  vehicleType: string = '';
  proxies: ProxyItem[] = [];
  updatedAt: string = '';
  testUrl: string = '';
  subUpload: number = 0;
  subDownload: number = 0;
  subTotal: number = 0;
  subExpire: number = 0;
}

export class RuleItem {
  index: number = 0;
  type: string = '';
  payload: string = '';
  proxy: string = '';
  size: number = -1;
  disabled: boolean = false;
  hitCount: number = 0;

  copy(): RuleItem {
    const r = new RuleItem();
    r.index = this.index;
    r.type = this.type;
    r.payload = this.payload;
    r.proxy = this.proxy;
    r.size = this.size;
    r.disabled = this.disabled;
    r.hitCount = this.hitCount;
    return r;
  }
}

export class RuleProvider {
  name: string = '';
  behavior: string = '';
  format: string = '';
  vehicleType: string = '';
  ruleCount: number = 0;
  updatedAt: string = '';
}

export class ConnMeta {
  network: string = '';
  type: string = '';
  sourceIP: string = '';
  destinationIP: string = '';
  sourcePort: string = '';
  destinationPort: string = '';
  inboundName: string = '';
  inboundUser: string = '';
  host: string = '';
  sniffHost: string = '';
  process: string = '';
  processPath: string = '';
  remoteDestination: string = '';
  dnsMode: string = '';
  uid: string = '';

  displayHost(): string {
    if (this.host.trim().length > 0) {
      return this.host;
    }
    if (this.sniffHost.trim().length > 0) {
      return this.sniffHost;
    }
    return this.destinationIP;
  }
}

export class ConnItem {
  id: string = '';
  meta: ConnMeta = new ConnMeta();
  upload: number = 0;
  download: number = 0;
  start: string = '';
  startMillis: number = 0;
  chains: string[] = [];
  rule: string = '';
  rulePayload: string = '';
  uploadSpeed: number = 0;
  downloadSpeed: number = 0;
  closedAt: number = 0;

  copy(): ConnItem {
    const c = new ConnItem();
    c.id = this.id;
    c.meta = this.meta;
    c.upload = this.upload;
    c.download = this.download;
    c.start = this.start;
    c.startMillis = this.startMillis;
    c.chains = this.chains;
    c.rule = this.rule;
    c.rulePayload = this.rulePayload;
    c.uploadSpeed = this.uploadSpeed;
    c.downloadSpeed = this.downloadSpeed;
    c.closedAt = this.closedAt;
    return c;
  }
}

export function parseConnection(o: JObj): ConnItem {
  const m = jObj(o, 'metadata');
  const meta = new ConnMeta();
  meta.network = jStr(m, 'network');
  meta.type = jStr(m, 'type');
  meta.sourceIP = jStr(m, 'sourceIP');
  meta.destinationIP = jStr(m, 'destinationIP');
  meta.sourcePort = jStr(m, 'sourcePort');
  meta.destinationPort = jStr(m, 'destinationPort');
  meta.inboundName = jStr(m, 'inboundName');
  meta.inboundUser = jStr(m, 'inboundUser');
  meta.host = jStr(m, 'host');
  meta.sniffHost = jStr(m, 'sniffHost');
  meta.process = jStr(m, 'process');
  meta.processPath = jStr(m, 'processPath');
  meta.remoteDestination = jStr(m, 'remoteDestination');
  meta.dnsMode = jStr(m, 'dnsMode');
  meta.uid = jHas(m, 'uid') ? jStr(m, 'uid') : '';
  const c = new ConnItem();
  c.id = jStr(o, 'id');
  c.meta = meta;
  c.upload = jNum(o, 'upload');
  c.download = jNum(o, 'download');
  c.start = jStr(o, 'start');
  c.startMillis = parseIsoMillis(c.start);
  c.chains = jStrArr(o, 'chains');
  c.rule = jStr(o, 'rule');
  c.rulePayload = jStr(o, 'rulePayload');
  return c;
}

export class LogEntry {
  seq: number = 0;
  type: string = '';
  payload: string = '';
  time: number = 0;

  constructor(seq: number, type: string, payload: string, time: number) {
    this.seq = seq;
    this.type = type;
    this.payload = payload;
    this.time = time;
  }
}

export class Traffic {
  up: number = 0;
  down: number = 0;

  constructor(up: number, down: number) {
    this.up = up;
    this.down = down;
  }
}

export class CoreConfig {
  mode: string = 'rule';
  logLevel: string = 'info';
  allowLan: boolean = false;
  ipv6: boolean = false;
  tunEnable: boolean = false;
  tunStack: string = '';
  mixedPort: number = 0;
  port: number = 0;
  socksPort: number = 0;
  redirPort: number = 0;
  tproxyPort: number = 0;
  bindAddress: string = '';
  modes: string[] = ['rule', 'global', 'direct'];

  copy(): CoreConfig {
    const c = new CoreConfig();
    c.mode = this.mode;
    c.logLevel = this.logLevel;
    c.allowLan = this.allowLan;
    c.ipv6 = this.ipv6;
    c.tunEnable = this.tunEnable;
    c.tunStack = this.tunStack;
    c.mixedPort = this.mixedPort;
    c.port = this.port;
    c.socksPort = this.socksPort;
    c.redirPort = this.redirPort;
    c.tproxyPort = this.tproxyPort;
    c.bindAddress = this.bindAddress;
    c.modes = this.modes;
    return c;
  }
}

// ---------------- time ----------------

const ISO_RE: RegExp = new RegExp('(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})(\\.\\d+)?(Z|[+-]\\d{2}:?\\d{2})?');

/** Parses mihomo's RFC3339 time (may include nanoseconds) to epoch millis; 0 on failure */
export function parseIsoMillis(s: string): number {
  if (s === undefined || s === null || s.trim().length === 0) {
    return 0;
  }
  const m = ISO_RE.exec(s);
  if (m === null) {
    return 0;
  }
  const y = Number(m[1]);
  const mo = Number(m[2]) - 1;
  const d = Number(m[3]);
  const hh = Number(m[4]);
  const mi = Number(m[5]);
  const ss = Number(m[6]);
  let ms = 0;
  const frac: string | undefined = m[7];
  if (frac !== undefined && frac.length > 1) {
    ms = Number((frac.substring(1) + '000').substring(0, 3));
  }
  let offsetMin = 0;
  const zone: string | undefined = m[8];
  if (zone !== undefined && zone !== 'Z' && zone.length >= 3) {
    const sign = zone.charAt(0) === '-' ? -1 : 1;
    const digits = zone.substring(1).replace(':', '');
    const zh = Number(digits.substring(0, 2));
    const zm = digits.length >= 4 ? Number(digits.substring(2, 4)) : 0;
    offsetMin = sign * (zh * 60 + zm);
  }
  const utc = Date.UTC(y, mo, d, hh, mi, ss, ms);
  return utc - offsetMin * 60000;
}
