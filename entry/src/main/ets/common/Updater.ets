import { updateManager } from '@kit.StoreKit';
import { CrashLog } from './CrashLog';
import { t } from './I18n';
import { Store } from './Store';

/**
 * 1.2.8: About > Version checks for updates through AppGallery (StoreKit updateManager) instead of GitHub.
 * The app is distributed on AppGallery, so the update comes from there and uses the system's own update dialog.
 */
export class Updater {
  static async check(store: Store): Promise<void> {
    const ctx = store.ctx;
    if (store.updateChecking || ctx === null) {
      return;
    }
    store.updateChecking = true;
    try {
      const r = await updateManager.checkAppUpdate(ctx);
      if (r.updateAvailable === updateManager.UpdateAvailableCode.LATER_VERSION_EXIST) {
        await updateManager.showUpdateDialog(ctx);
      } else {
        store.toast(t('update_latest', CrashLog.versionName()));
      }
    } catch (e) {
      store.toast(t('update_failed'));
    } finally {
      store.updateChecking = false;
    }
  }
}
