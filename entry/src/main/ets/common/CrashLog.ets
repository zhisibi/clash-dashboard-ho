import { common, errorManager, bundleManager } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { FileUtil } from './FileUtil';
import { fmtStamp, fmtDateTime } from './Format';
import { t } from './I18n';

/** Crash log (Kotlin CrashLog.kt). Uncaught JS exceptions go to filesDir/crash/*.txt and are offered on next launch */
export class CrashLog {
  private static dirPath: string = '';
  private static observerId: number = -1;

  static init(ctx: common.Context): void {
    CrashLog.dirPath = ctx.filesDir + '/crash';
    FileUtil.ensureDir(CrashLog.dirPath);
  }

  static install(appCtx: common.ApplicationContext): void {
    CrashLog.init(appCtx);
    try {
      const observer: errorManager.ErrorObserver = {
        onUnhandledException: (msg: string) => {
          try {
            CrashLog.write(t('crash_kind_js'), msg);
          } catch (e) {
            // ignore
          }
          // With an observer registered the app no longer exits by itself; exit as the docs recommend (same as Android)
          appCtx.killAllProcesses().catch(() => {
          });
        }
      };
      CrashLog.observerId = errorManager.on('error', observer);
    } catch (e) {
      console.error('errorManager.on failed');
    }
  }

  static versionName(): string {
    try {
      const bi = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return bi.versionName + ' (' + bi.versionCode + ')';
    } catch (e) {
      return '1.2.0';
    }
  }

  static write(kind: string, detail: string): void {
    if (CrashLog.dirPath.length === 0) {
      return;
    }
    const now = Date.now();
    let text = t('crash_header') + '\n';
    text += t('crash_time') + ': ' + fmtDateTime(now) + '\n';
    text += t('crash_app_ver') + ': ' + CrashLog.versionName() + '\n';
    text += t('crash_device') + ': ' + deviceInfo.manufacture + ' ' + deviceInfo.marketName + ' (' + deviceInfo.productModel + ')\n';
    text += t('crash_os') + ': ' + deviceInfo.osFullName + ' / ' + deviceInfo.displayVersion + ' / API ' + deviceInfo.sdkApiVersion + '\n';
    text += t('crash_kind') + ': ' + kind + '\n';
    text += '\n';
    text += detail;
    FileUtil.writeText(CrashLog.dirPath + '/crash-' + fmtStamp(now) + '.txt', text);
    const files = CrashLog.list();
    for (let i = 20; i < files.length; i++) {
      FileUtil.remove(CrashLog.dirPath + '/' + files[i]);
    }
    FileUtil.writeText(CrashLog.dirPath + '/.unseen', '1');
  }

  /** File names, newest first */
  static list(): string[] {
    const names = FileUtil.list(CrashLog.dirPath).filter((n: string) => n.endsWith('.txt'));
    names.sort((a: string, b: string) => b.localeCompare(a));
    return names;
  }

  static path(name: string): string {
    return CrashLog.dirPath + '/' + name;
  }

  static read(name: string): string {
    return FileUtil.readText(CrashLog.path(name));
  }

  static hasUnseen(): boolean {
    return FileUtil.exists(CrashLog.dirPath + '/.unseen') && CrashLog.list().length > 0;
  }

  static markSeen(): void {
    FileUtil.remove(CrashLog.dirPath + '/.unseen');
  }

  static clear(): void {
    for (const n of CrashLog.list()) {
      FileUtil.remove(CrashLog.path(n));
    }
    CrashLog.markSeen();
  }

  /** crash-20261007-123456.txt -> 2026-10-07 12:34:56 */
  static title(name: string): string {
    const s = name.replace('crash-', '').replace('.txt', '');
    if (s.length < 15) {
      return name;
    }
    return s.substring(0, 4) + '-' + s.substring(4, 6) + '-' + s.substring(6, 8) + ' ' +
      s.substring(9, 11) + ':' + s.substring(11, 13) + ':' + s.substring(13, 15);
  }

  static firstErrorLine(name: string): string {
    const lines = CrashLog.read(name).split('\n');
    let pastHeader = false;
    for (const l of lines) {
      if (!pastHeader) {
        if (l.trim().length === 0) {
          pastHeader = true;
        }
        continue;
      }
      if (l.trim().length > 0) {
        return l.trim();
      }
    }
    return '';
  }
}
