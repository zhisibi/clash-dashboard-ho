import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import {
  WidgetSnapshot, readFormIds, readSnapshot, saveFormIds, snapshotToBinding, writeSnapshot
} from '../common/WidgetSync';
import { Prefs } from '../common/Prefs';
import { Backend, JObj, ProxyItem } from '../common/Models';
import { CoreApi } from '../common/CoreApi';
import { initLang, t } from '../common/I18n';
import { fmtClock, modeName } from '../common/Format';

/**
 * Service widget (desktop / minus-one screen) ability (1.4.0, interactive since 1.4.1).
 * Display data comes from the snapshot the app writes into Preferences (see WidgetSync.ets).
 * Card actions (message postCardAction) run right here in the form process: the active backend is
 * read from the same Preferences store and driven through the same CoreApi the app uses - mode
 * switches PATCH /configs, the node button cycles the main group to its next leaf node via
 * PUT /proxies/{group}. Results are written back into the snapshot so every card re-renders with
 * the new state; failures surface as a short line on the card instead of failing silently.
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
    this.handleAction(formId, message).catch(() => {
    });
  }

  onRemoveForm(formId: string): void {
    this.forget(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  // ---------------- card actions (1.4.1) ----------------

  private activeApi(prefs: Prefs): CoreApi | null {
    const backends = prefs.getBackends();
    if (backends.length === 0) {
      return null;
    }
    const activeId = prefs.str('active_backend', '');
    let act: Backend | null = null;
    for (const b of backends) {
      if (b.id === activeId) {
        act = b;
      }
    }
    if (act === null) {
      act = backends[0];
    }
    if (!CoreApi.validate(act)) {
      return null;
    }
    return new CoreApi(act);
  }

  /** Applies `mutate` to the stored snapshot, stamps it and re-renders this form */
  private async finish(formId: string, snap: WidgetSnapshot): Promise<void> {
    snap.updatedAt = Date.now();
    snap.updatedText = fmtClock(snap.updatedAt);
    writeSnapshot(this.context, snap);
    await formProvider.updateForm(formId, formBindingData.createFormBindingData(snapshotToBinding(snap)));
  }

  private async handleAction(formId: string, message: string): Promise<void> {
    let action = '';
    let mode = '';
    let group = '';
    try {
      const o = JSON.parse(message) as JObj;
      const a = o['action'];
      const m = o['mode'];
      const g = o['group'];
      action = typeof a === 'string' ? a as string : '';
      mode = typeof m === 'string' ? m as string : '';
      group = typeof g === 'string' ? g as string : '';
    } catch (e) {
      return;
    }
    if (action !== 'setMode' && action !== 'cycleNode') {
      return;
    }
    const prefs = new Prefs(this.context);
    initLang(prefs.str('lang', 'system'));
    const snap = readSnapshot(this.context);
    const api = this.activeApi(prefs);
    if (api === null || !snap.connected) {
      snap.msgText = t('widget_action_failed');
      await this.finish(formId, snap);
      return;
    }
    try {
      if (action === 'setMode') {
        if (mode !== 'rule' && mode !== 'global' && mode !== 'direct') {
          return;
        }
        const body: JObj = { 'mode': mode };
        await api.patchConfigs(body);
        snap.modeKey = mode;
        snap.modeText = modeName(mode);
        snap.msgText = '';
      } else {
        const target = group.length > 0 ? group : snap.groupName;
        if (target.length === 0) {
          return;
        }
        const next = await this.nextNode(api, target);
        if (next.length === 0) {
          snap.msgText = t('widget_action_failed');
          await this.finish(formId, snap);
          return;
        }
        await api.selectProxy(target, next);
        snap.groupName = target;
        snap.nodeText = next;
        snap.msgText = '';
      }
    } catch (e) {
      snap.msgText = t('widget_action_failed');
    }
    await this.finish(formId, snap);
  }

  /**
   * Next leaf node of the group after its current selection (wraps around). Nested groups are
   * skipped: the button is for switching the actual exit node. '' when nothing can be picked.
   */
  private async nextNode(api: CoreApi, groupName: string): Promise<string> {
    const all = await api.proxies();
    const g = all.get(groupName);
    if (g === undefined || g.all.length === 0) {
      return '';
    }
    const leaves: string[] = [];
    for (const name of g.all) {
      const p = all.get(name);
      if (p !== undefined && !p.isGroup()) {
        leaves.push(name);
      } else if (p === undefined) {
        leaves.push(name);
      }
    }
    if (leaves.length === 0) {
      return '';
    }
    // current leaf: resolve the group's selection down to the final node
    let cur: ProxyItem | undefined = g;
    const seen = new Set<string>();
    while (cur !== undefined && cur.isGroup() && cur.now.length > 0 && !seen.has(cur.name)) {
      seen.add(cur.name);
      cur = all.get(cur.now);
    }
    const curName = cur !== undefined ? cur.name : g.now;
    const idx = leaves.indexOf(curName);
    if (idx < 0) {
      return leaves[0] === curName && leaves.length > 1 ? leaves[1] : leaves[0];
    }
    return leaves[(idx + 1) % leaves.length];
  }
}
