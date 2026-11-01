import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * Desktop / minus-one-screen form (service widget) data bridge (1.4.0).
 * The app writes a pre-formatted snapshot into the shared Preferences store (key 'widget_snapshot')
 * whenever the live data moves; EntryFormAbility reads it in onAddForm / onUpdateForm / onFormEvent
 * and hands it to the card through FormBindingData. The app also pushes updates straight to every
 * registered form id (key 'widget_form_ids') so an open desktop stays close to real time while the
 * app is alive. The card itself does no network work.
 */

export const WIDGET_SNAPSHOT_KEY: string = 'widget_snapshot';
export const WIDGET_FORM_IDS_KEY: string = 'widget_form_ids';
export const WIDGET_PREFS_NAME: string = 'mimi_panel';

export class WidgetSnapshot {
  brand: string = 'Mimi Panel';
  connected: boolean = false;
  statusText: string = 'Not connected';
  labelText: string = '';
  upText: string = '0 B/s';
  downText: string = '0 B/s';
  connText: string = '0';
  memText: string = '-';
  totalText: string = '';
  /** Upload / download totals since the core started (1.4.11, replacing live speeds) */
  upTotalText: string = '';
  downTotalText: string = '';
  modeText: string = '';
  /** Raw mode key for the card's mode segment: rule | global | direct (1.4.1) */
  modeKey: string = '';
  /** Localized labels for the three mode chips + which modes the backend offers (1.4.1) */
  modeRuleText: string = 'Rule';
  modeGlobalText: string = 'Global';
  modeDirectText: string = 'Direct';
  hasRule: boolean = true;
  hasGlobal: boolean = true;
  hasDirect: boolean = true;
  /** Label of the node-cycle button (1.4.1) */
  switchText: string = 'Switch';
  /** Transient result of the last card action, shown until the next snapshot (1.4.1) */
  msgText: string = '';
  /** Main selectable group the card's node row switches (1.4.1) */
  groupName: string = '';
  nodeText: string = '';
  updatedText: string = '';
  /** Gradient stops for the card background, computed from the current accent by the app */
  bgA: string = '#0A59F7';
  bgB: string = '#0646C8';
  updatedAt: number = 0;
}

/** Binding object handed to the card; keys must match the @LocalStorageProp names in the card pages */
export function snapshotToBinding(s: WidgetSnapshot): Record<string, Object> {
  const o: Record<string, Object> = {};
  o['brand'] = s.brand;
  o['connected'] = s.connected;
  o['statusText'] = s.statusText;
  o['labelText'] = s.labelText;
  o['upText'] = s.upText;
  o['downText'] = s.downText;
  o['connText'] = s.connText;
  o['memText'] = s.memText;
  o['totalText'] = s.totalText;
  o['upTotalText'] = s.upTotalText;
  o['downTotalText'] = s.downTotalText;
  o['modeText'] = s.modeText;
  o['modeKey'] = s.modeKey;
  o['modeRuleText'] = s.modeRuleText;
  o['modeGlobalText'] = s.modeGlobalText;
  o['modeDirectText'] = s.modeDirectText;
  o['hasRule'] = s.hasRule;
  o['hasGlobal'] = s.hasGlobal;
  o['hasDirect'] = s.hasDirect;
  o['switchText'] = s.switchText;
  o['msgText'] = s.msgText;
  o['groupName'] = s.groupName;
  o['nodeText'] = s.nodeText;
  o['updatedText'] = s.updatedText;
  o['bgA'] = s.bgA;
  o['bgB'] = s.bgB;
  return o;
}

export function snapshotFromJson(text: string): WidgetSnapshot {
  const s = new WidgetSnapshot();
  if (text.trim().length === 0) {
    return s;
  }
  try {
    const o = JSON.parse(text) as Record<string, Object>;
    const str = (k: string, def: string): string => {
      const v = o[k];
      return typeof v === 'string' ? v as string : def;
    };
    const bol = (k: string, def: boolean): boolean => {
      const v = o[k];
      return typeof v === 'boolean' ? v as boolean : def;
    };
    const num = (k: string, def: number): number => {
      const v = o[k];
      return typeof v === 'number' ? v as number : def;
    };
    s.brand = str('brand', s.brand);
    s.connected = bol('connected', false);
    s.statusText = str('statusText', s.statusText);
    s.labelText = str('labelText', '');
    s.upText = str('upText', s.upText);
    s.downText = str('downText', s.downText);
    s.connText = str('connText', '0');
    s.memText = str('memText', '-');
    s.totalText = str('totalText', '');
    s.upTotalText = str('upTotalText', '');
    s.downTotalText = str('downTotalText', '');
    s.modeText = str('modeText', '');
    s.modeKey = str('modeKey', '');
    s.modeRuleText = str('modeRuleText', s.modeRuleText);
    s.modeGlobalText = str('modeGlobalText', s.modeGlobalText);
    s.modeDirectText = str('modeDirectText', s.modeDirectText);
    s.hasRule = bol('hasRule', true);
    s.hasGlobal = bol('hasGlobal', true);
    s.hasDirect = bol('hasDirect', true);
    s.switchText = str('switchText', s.switchText);
    s.msgText = str('msgText', '');
    s.groupName = str('groupName', '');
    s.nodeText = str('nodeText', '');
    s.updatedText = str('updatedText', '');
    s.bgA = str('bgA', s.bgA);
    s.bgB = str('bgB', s.bgB);
    s.updatedAt = num('updatedAt', 0);
  } catch (e) {
    // a torn write reads as the default snapshot; the next app update replaces it
  }
  return s;
}

export function readSnapshot(ctx: common.Context): WidgetSnapshot {
  try {
    const opts: preferences.Options = { name: WIDGET_PREFS_NAME };
    const sp = preferences.getPreferencesSync(ctx, opts);
    const v = sp.getSync(WIDGET_SNAPSHOT_KEY, '');
    return snapshotFromJson(typeof v === 'string' ? v as string : '');
  } catch (e) {
    return new WidgetSnapshot();
  }
}

export function writeSnapshot(ctx: common.Context, snap: WidgetSnapshot): void {
  try {
    const opts: preferences.Options = { name: WIDGET_PREFS_NAME };
    const sp = preferences.getPreferencesSync(ctx, opts);
    sp.putSync(WIDGET_SNAPSHOT_KEY, JSON.stringify(snap));
    sp.flush().catch(() => {
    });
  } catch (e) {
    // ignore
  }
}

export function readFormIds(ctx: common.Context): string[] {
  try {
    const opts: preferences.Options = { name: WIDGET_PREFS_NAME };
    const sp = preferences.getPreferencesSync(ctx, opts);
    const v = sp.getSync(WIDGET_FORM_IDS_KEY, '');
    const text = typeof v === 'string' ? v as string : '';
    if (text.trim().length === 0) {
      return [];
    }
    const arr = JSON.parse(text) as Object[];
    const out: string[] = [];
    for (const e of arr) {
      if (typeof e === 'string' && (e as string).length > 0) {
        out.push(e as string);
      }
    }
    return out;
  } catch (e) {
    return [];
  }
}

export function saveFormIds(ctx: common.Context, ids: string[]): void {
  try {
    const opts: preferences.Options = { name: WIDGET_PREFS_NAME };
    const sp = preferences.getPreferencesSync(ctx, opts);
    sp.putSync(WIDGET_FORM_IDS_KEY, JSON.stringify(ids));
    // the form process is short-lived: an async flush can be lost when it dies, and with it
    // the registration of a card added on the minus-one screen (1.4.6 diagnosis)
    sp.flushSync();
  } catch (e) {
    // ignore
  }
}

/**
 * Pushes the snapshot to every registered form. Ids are NEVER dropped here: updateForm can
 * fail transiently (host busy, form still being created on the minus-one screen), and the
 * 1.4.0-1.4.5 behaviour of forgetting the id on any failure left that card frozen forever -
 * it kept its initial (default, English-labelled) binding and never refreshed after a tap.
 * Only onRemoveForm unregisters a form.
 */
export async function pushSnapshotToForms(ctx: common.Context, snap: WidgetSnapshot): Promise<void> {
  const ids = readFormIds(ctx);
  if (ids.length === 0) {
    return;
  }
  const data = formBindingData.createFormBindingData(snapshotToBinding(snap));
  // Push to all forms concurrently (1.4.10): the registry accumulates ids across re-added
  // cards, and a sequential loop lets one slow or hanging updateForm (e.g. a stale
  // minus-one-screen id) starve every live card behind it - the visible symptom was card
  // speeds freezing while the app itself showed live traffic.
  const jobs: Promise<void>[] = [];
  for (const id of ids) {
    jobs.push(formProvider.updateForm(id, data).then(() => {
    }).catch(() => {
      // transient or dead id: keep it registered; the next push retries
    }));
  }
  await Promise.all(jobs);
}
