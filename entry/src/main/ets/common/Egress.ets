import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { NetError, errMsg } from './CoreApi';
import { EgressInfo, parseCfTrace, parseIpwho } from './EgressLogic';
import { t } from './I18n';

/**
 * Egress (exit IP) check (1.4.0): a plain HTTPS GET from THIS app, over this device's own network
 * path - no backend address and no backend secret are ever sent to these services.
 * Primary: ipwho.is (IP + geolocation + ISP). Fallback: Cloudflare trace (IP + country code only).
 */

const IPWHO_URL: string = 'https://ipwho.is/';
const CF_TRACE_URL: string = 'https://www.cloudflare.com/cdn-cgi/trace';

async function getText(url: string, timeoutMs: number): Promise<string> {
  const req = http.createHttp();
  const opts: http.HttpRequestOptions = {
    method: http.RequestMethod.GET,
    header: { 'Accept': 'application/json, text/plain' },
    connectTimeout: 8000,
    readTimeout: timeoutMs,
    expectDataType: http.HttpDataType.STRING
  };
  try {
    const resp = await req.request(url, opts);
    const code = resp.responseCode as number;
    if (code < 200 || code >= 300) {
      throw new NetError(code, 'HTTP ' + code);
    }
    return typeof resp.result === 'string' ? resp.result as string : '';
  } catch (e) {
    if (e instanceof NetError) {
      throw e as NetError;
    }
    const be = e as BusinessError;
    throw new NetError(be.code !== undefined ? be.code : -1, be.message !== undefined ? be.message : t('err_net'));
  } finally {
    req.destroy();
  }
}

/** Runs the check; resolves with the first source that answers, rejects with the last error otherwise */
export async function fetchEgress(): Promise<EgressInfo> {
  let lastErr: NetError | null = null;
  const start1 = Date.now();
  try {
    const body = await getText(IPWHO_URL, 10000);
    const info = parseIpwho(body);
    if (info !== null) {
      info.latencyMs = Date.now() - start1;
      info.checkedAt = Date.now();
      return info;
    }
    lastErr = new NetError(-1, 'ipwho.is: bad response');
  } catch (e) {
    lastErr = new NetError(-1, errMsg(e as Object));
  }
  const start2 = Date.now();
  try {
    const body = await getText(CF_TRACE_URL, 10000);
    const info = parseCfTrace(body);
    if (info !== null) {
      info.latencyMs = Date.now() - start2;
      info.checkedAt = Date.now();
      return info;
    }
  } catch (e) {
    lastErr = new NetError(-1, errMsg(e as Object));
  }
  if (lastErr !== null) {
    throw lastErr;
  }
  throw new NetError(-1, t('err_net'));
}
