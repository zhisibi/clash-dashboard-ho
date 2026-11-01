import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import {
  WidgetSnapshot, readFormIds, readSnapshot, saveFormIds, snapshotToBinding
} from '../common/WidgetSync';

/**
 * Service widget (desktop / minus-one screen) ability (1.4.0).
 * All data comes from the snapshot the app writes into Preferences (see WidgetSync.ets);
 * this ability never touches the network or the backend secret.
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
    if (params !== undefined && params !== null) {
      const id = params[formInfo.FormParam.IDENTITY_KEY];
      if (typeof id === 'string' && (id as string).length > 0) {
        this.remember(id as string);
      }
    }
    return this.binding();
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
    // The card's refresh button posts {"action":"refresh"}; re-read the snapshot and re-render.
    if (message.indexOf('refresh') >= 0) {
      formProvider.updateForm(formId, this.binding()).catch(() => {
      });
    }
  }

  onRemoveForm(formId: string): void {
    this.forget(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
