import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { rpc } from '@kit.IPCKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Store } from '../common/Store';
import { CrashLog } from '../common/CrashLog';
import { Motion } from '../common/Motion';
import { ReviewPrompt } from '../common/ReviewPrompt';
import { onSystemLangChanged } from '../common/I18n';
import { JObj, jObj, jStr, parseJsonObj } from '../common/Models';

/** Empty reply for widget 'call' events; the result reaches the card via formProvider pushes */
class WidgetCallReply implements rpc.Parcelable {
  marshalling(dataOut: rpc.MessageSequence): boolean {
    return true;
  }

  unmarshalling(dataIn: rpc.MessageSequence): boolean {
    return true;
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    CrashLog.install(this.context.getApplicationContext());
    const store = Store.get();
    store.systemDark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    store.init(this.context);
    // 1.3.0: global motion reads the system animation scales; the gentle review prompt counts this launch
    Motion.readSystem(this.context);
    ReviewPrompt.get().init();
    // 1.4.2: widget cards fire 'call' actions (mode switch / node cycle); the callee runs them
    // in this main process through Store.widgetAction and the result is pushed back to the card
    this.callee.on('widgetAction', (data: rpc.MessageSequence): rpc.Parcelable => {
      this.handleWidgetCall(data);
      return new WidgetCallReply();
    });
  }

  /**
   * Unwraps a widget call payload ({action, mode}, possibly nested under a stringified params)
   * and hands it to the store. The callee callback itself must answer synchronously, so the
   * action runs fire-and-forget; its result reaches the card via the snapshot push.
   */
  private handleWidgetCall(data: rpc.MessageSequence): void {
    let action: string = '';
    let mode: string = '';
    try {
      const raw = data.readString();
      hilog.info(0x0001, 'MimiWidget', 'call payload: ' + raw);
      let o: JObj = parseJsonObj(raw);
      const inner = jStr(o, 'params');
      if (inner.length > 0) {
        o = parseJsonObj(inner);
      } else {
        const po = jObj(o, 'params');
        if (po !== undefined) {
          o = po;
        }
      }
      action = jStr(o, 'action');
      mode = jStr(o, 'mode');
    } catch (e) {
      hilog.error(0x0001, 'MimiWidget', 'call payload parse failed');
    }
    if (action.length > 0) {
      Store.get().widgetAction(action, mode).catch(() => {
      });
    }
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
    // 1.4.1: the widget card may have switched mode / node while the app was away - refetch so the
    // in-app view and the next snapshot agree with the backend again
    const store = Store.get();
    if (store.connState === 'connected') {
      store.refreshConfig();
      store.refreshProxies();
    }
  }

  onBackground(): void {
    Store.get().setForeground(false);
  }

  onDestroy(): void {
    this.callee.off('widgetAction');
    Store.get().shutdown();
  }
}
