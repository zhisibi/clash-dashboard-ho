import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  WidgetSnapshot, readFormIds, readSnapshot, saveFormIds, snapshotToBinding
} from '../common/WidgetSync';

/**
 * Service widget (desktop / minus-one screen) ability (1.4.0). Display only: all data comes
 * from the snapshot the app writes into Preferences (see WidgetSync.ets) and pushes here via
 * formProvider. Card taps are handled elsewhere - the header opens the app (router), and the
 * mode / node buttons fire 'call' actions that EntryAbility's callee executes through the
 * app's Store (1.4.2). The 1.4.1 form-process executor is removed: its 'message' payload was
 * built in a format the system never delivered to onFormEvent, so every button was dead.
 */
export default class EntryFormAbility extends FormExtensionAbility {
  private binding(): formBindingData.FormBindingData {
    const snap: WidgetSnapshot = readSnapshot(this.context);
    return formBindingData.createFormBindingData(snapshotToBinding(snap));
  }

  private remember(formId: string): void {
    const ids = readFormIds(this.context);
    if (ids.indexOf(formId) < 0) {
      ids.push(formId);
      saveFormIds(this.context, ids);
    }
  }

  private forget(formId: string): void {
    const ids = readFormIds(this.context);
    const out: string[] = [];
    for (const id of ids) {
      if (id !== formId) {
        out.push(id);
      }
    }
    if (out.length !== ids.length) {
      saveFormIds(this.context, out);
    }
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const params = want.parameters;
    let fid: string = '';
    if (params !== undefined && params !== null) {
      const id = params[formInfo.FormParam.IDENTITY_KEY];
      if (typeof id === 'string' && (id as string).length > 0) {
        fid = id as string;
        this.remember(fid);
      }
    }
    const data = this.binding();
    if (fid.length > 0) {
      // belt and braces for the minus-one-screen host: push the current snapshot once more
      // instead of relying only on the returned binding being applied (1.4.6)
      formProvider.updateForm(fid, data).catch(() => {
      });
    }
    return data;
  }

  onCastToNormalForm(formId: string): void {
    this.remember(formId);
  }

  onUpdateForm(formId: string): void {
    this.remember(formId);
    formProvider.updateForm(formId, this.binding()).catch(() => {
    });
  }

  onFormEvent(formId: string, message: string): void {
    // No card sends message events since 1.4.2; log anything unexpected for diagnosis.
    hilog.info(0x0001, 'MimiWidget', 'unexpected form event: ' + message);
  }

  onRemoveForm(formId: string): void {
    this.forget(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
