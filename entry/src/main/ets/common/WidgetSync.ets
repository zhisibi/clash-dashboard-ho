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
  modeText: string = '';
  nodeText: string = '';
  egressText: string = '';
  egressIp: string = '';
  hasEgress: boolean = false;
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
  o['modeText'] = s.modeText;
  o['nodeText'] = s.nodeText;
  o['egressText'] = s.egressText;
  o['egressIp'] = s.egressIp;
  o['hasEgress'] = s.hasEgress;
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
    s.modeText = str('modeText', '');
    s.nodeText = str('nodeText', '');
    s.egressText = str('egressText', '');
    s.egressIp = str('egressIp', '');
    s.hasEgress = bol('hasEgress', false);
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
    sp.flush().catch(() => {
    });
  } catch (e) {
    // ignore
  }
}

/** Pushes the snapshot to every live form; dead ids are dropped from the registry */
export async function pushSnapshotToForms(ctx: common.Context, snap: WidgetSnapshot): Promise<void> {
  const ids = readFormIds(ctx);
  if (ids.length === 0) {
    return;
  }
  const data = formBindingData.createFormBindingData(snapshotToBinding(snap));
  const alive: string[] = [];
  for (const id of ids) {
    try {
      await formProvider.updateForm(id, data);
      alive.push(id);
    } catch (e) {
      // form was removed from the desktop; forget it
    }
  }
  if (alive.length !== ids.length) {
    saveFormIds(ctx, alive);
  }
}
