import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Store } from '../common/Store';
import { CrashLog } from '../common/CrashLog';
import { Motion } from '../common/Motion';
import { ReviewPrompt } from '../common/ReviewPrompt';
import { onSystemLangChanged } from '../common/I18n';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    CrashLog.install(this.context.getApplicationContext());
    const store = Store.get();
    store.systemDark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    store.init(this.context);
    // 1.3.0: global motion reads the system animation scales; the gentle review prompt counts this launch
    Motion.readSystem(this.context);
    ReviewPrompt.get().init();
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    Store.get().systemDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    Store.get().applySystemBar();
    onSystemLangChanged();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        console.error('loadContent failed: ' + err.code);
        return;
      }
      try {
        const win = windowStage.getMainWindowSync();
        const store = Store.get();
        store.win = win;
        store.uiCtx = win.getUIContext();
        store.setupImmersive(win);
        store.applySystemBar();
      } catch (e) {
        console.error('window init failed');
      }
    });
  }

  onForeground(): void {
    Motion.readSystem(this.context);
    Store.get().setForeground(true);
  }

  onBackground(): void {
    Store.get().setForeground(false);
  }

  onDestroy(): void {
    Store.get().shutdown();
  }
}
