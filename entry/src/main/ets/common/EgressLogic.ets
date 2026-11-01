/**
 * Pure parsing logic for the egress (exit IP) check (1.4.0). No imports on purpose, so
 * scripts/test-logic.mjs can exercise it under Node like MotionLogic / ReviewLogic.
 *
 * Sources:
 * - ipwho.is (https://ipwho.is/): JSON { success, ip, country, country_code, region, city,
 *   connection: { isp, org, asn } }
 * - Cloudflare trace (https://www.cloudflare.com/cdn-cgi/trace): plain text lines ip=, loc= (country code)
 * The check runs over this device's own network path: when the device's traffic goes through the
 * proxy core (the usual setup for this panel), the result IS the proxy egress; on a plain direct
 * connection it is the direct egress. The UI says so instead of pretending otherwise.
 */

export class EgressInfo {
  ip: string = '';
  country: string = '';
  /** ISO 3166-1 alpha-2, upper case; '' when unknown */
  countryCode: string = '';
  region: string = '';
  city: string = '';
  isp: string = '';
  /** Which service answered: 'ipwho' | 'cloudflare' */
  source: string = '';
  /** Round-trip of the successful request, ms */
  latencyMs: number = 0;
  /** When the check finished (epoch ms) */
  checkedAt: number = 0;
}

type JObj = Record<string, Object>;

function jGet(o: JObj | undefined, k: string): Object | undefined {
  if (o === undefined) {
    return undefined;
  }
  const v: Object | undefined = o[k];
  if (v === undefined || v === null) {
    return undefined;
  }
  return v;
}

function jStr(o: JObj | undefined, k: string): string {
  const v = jGet(o, k);
  if (typeof v === 'string') {
    return v as string;
  }
  if (typeof v === 'number' || typeof v === 'boolean') {
    return String(v);
  }
  return '';
}

function jObj(o: JObj | undefined, k: string): JObj | undefined {
  const v = jGet(o, k);
  if (v !== undefined && typeof v === 'object' && !Array.isArray(v)) {
    return v as JObj;
  }
  return undefined;
}

function parseObj(text: string): JObj | undefined {
  try {
    const v = JSON.parse(text) as Object;
    if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
      return v as JObj;
    }
  } catch (e) {
    // not JSON
  }
  return undefined;
}

/** Parses an ipwho.is response body; null when it is not a successful answer with an IP */
export function parseIpwho(text: string): EgressInfo | null {
  const o = parseObj(text);
  if (o === undefined) {
    return null;
  }
  const ok = jGet(o, 'success');
  if (typeof ok === 'boolean' && !(ok as boolean)) {
    return null;
  }
  const ip = jStr(o, 'ip');
  if (ip.length === 0) {
    return null;
  }
  const info = new EgressInfo();
  info.ip = ip;
  info.country = jStr(o, 'country');
  info.countryCode = jStr(o, 'country_code').toUpperCase();
  info.region = jStr(o, 'region');
  info.city = jStr(o, 'city');
  const conn = jObj(o, 'connection');
  info.isp = jStr(conn, 'isp');
  if (info.isp.length === 0) {
    info.isp = jStr(conn, 'org');
  }
  info.source = 'ipwho';
  return info;
}

/** Parses a Cloudflare /cdn-cgi/trace body (key=value lines); null when it carries no IP */
export function parseCfTrace(text: string): EgressInfo | null {
  let ip = '';
  let loc = '';
  const lines = text.split('\n');
  for (const line of lines) {
    const eq = line.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    const k = line.substring(0, eq).trim();
    const v = line.substring(eq + 1).trim();
    if (k === 'ip') {
      ip = v;
    } else if (k === 'loc') {
      loc = v;
    }
  }
  if (ip.length === 0) {
    return null;
  }
  const info = new EgressInfo();
  info.ip = ip;
  info.countryCode = loc.toUpperCase();
  info.source = 'cloudflare';
  return info;
}

/** Flag emoji for an ISO alpha-2 country code (regional indicator pair); '' for anything else */
export function flagEmoji(code: string): string {
  const c = code.trim().toUpperCase();
  if (c.length !== 2) {
    return '';
  }
  const a = c.charCodeAt(0);
  const b = c.charCodeAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) {
    return '';
  }
  const hi = 0xD83C;
  const loA = 0xDDE6 + (a - 65);
  const loB = 0xDDE6 + (b - 65);
  return String.fromCharCode(hi, loA, hi, loB);
}

/** "Country Region City" with duplicates and blanks dropped; falls back to the country code */
export function egressLocationText(info: EgressInfo): string {
  const parts: string[] = [];
  const raw: string[] = [info.country, info.region, info.city];
  for (const p of raw) {
    const v = p.trim();
    if (v.length > 0 && parts.indexOf(v) < 0) {
      parts.push(v);
    }
  }
  if (parts.length > 0) {
    return parts.join(' ');
  }
  return info.countryCode;
}

/** One-line widget text: flag + location, or just the IP when no location is known */
export function egressWidgetText(info: EgressInfo): string {
  const loc = egressLocationText(info);
  const flag = flagEmoji(info.countryCode);
  if (loc.length > 0) {
    return flag.length > 0 ? flag + ' ' + loc : loc;
  }
  return info.ip;
}
