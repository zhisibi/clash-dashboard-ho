import { http } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { CrashLog } from './CrashLog';
import { t } from './I18n';
import { Store } from './Store';

/** 1.2.7: About > Version checks the GitHub repo's latest release and offers to open it when it is newer. */
const LATEST_API: string = 'https://api.github.com/repos/zhisibi/clash-dashboard-ho/releases/latest';
export const RELEASES_URL: string = 'https://github.com/zhisibi/clash-dashboard-ho/releases/latest';

interface ReleaseJson {
  tag_name?: string;
  html_url?: string;
}

/** -1 a < b, 0 equal, 1 a > b; compares dotted numeric parts, ignores a leading v */
export function cmpVersion(a: string, b: string): number {
  const pa = a.replace(/^[vV]/, '').split(/[.\-+]/);
  const pb = b.replace(/^[vV]/, '').split(/[.\-+]/);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const x = parseInt(pa[i] ?? '0');
    const y = parseInt(pb[i] ?? '0');
    const xv = isNaN(x) ? 0 : x;
    const yv = isNaN(y) ? 0 : y;
    if (xv !== yv) {
      return xv < yv ? -1 : 1;
    }
  }
  return 0;
}

export class Updater {
  static async check(store: Store): Promise<void> {
    if (store.updateChecking) {
      return;
    }
    store.updateChecking = true;
    const req = http.createHttp();
    try {
      const res = await req.request(LATEST_API, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/vnd.github+json', 'User-Agent': 'MimiPanel' },
        connectTimeout: 10000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });
      if (res.responseCode !== 200) {
        throw new Error('HTTP ' + res.responseCode);
      }
      const j = JSON.parse(res.result as string) as ReleaseJson;
      const tag = j.tag_name ?? '';
      const cur = CrashLog.versionName();
      if (tag.length === 0) {
        throw new Error('no release');
      }
      if (cmpVersion(tag, cur) > 0) {
        Updater.prompt(store, tag.replace(/^[vV]/, ''), cur, j.html_url ?? RELEASES_URL);
      } else {
        store.toast(t('update_latest', cur));
      }
    } catch (e) {
      store.toast(t('update_failed'));
    } finally {
      req.destroy();
      store.updateChecking = false;
    }
  }

  private static prompt(store: Store, latest: string, cur: string, url: string): void {
    const ui = store.uiCtx;
    if (ui === null) {
      return;
    }
    ui.getPromptAction().showDialog({
      title: t('update_title'),
      message: t('update_msg', latest, cur),
      buttons: [
        { text: t('update_later'), color: store.palette().subtle },
        { text: t('update_go'), color: store.palette().accent }
      ]
    }).then((r) => {
      if (r.index === 1) {
        Updater.open(store, url);
      }
    }).catch(() => {
    });
  }

  static open(store: Store, url: string): void {
    const ctx = store.ctx;
    if (ctx === null) {
      return;
    }
    const want: Want = { action: 'ohos.want.action.viewData', entities: ['entity.system.browsable'], uri: url };
    ctx.startAbility(want).catch(() => {
      store.toast(t('update_failed'));
    });
  }
}
