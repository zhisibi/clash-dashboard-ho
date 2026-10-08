import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Backend, asObj, parseJson } from './Models';

/** Local settings storage (Kotlin data/Prefs.kt, using @ohos.data.preferences) */
export class Prefs {
  private sp: preferences.Preferences;

  constructor(ctx: common.Context) {
    const opts: preferences.Options = { name: 'mimi_panel' };
    this.sp = preferences.getPreferencesSync(ctx, opts);
  }

  str(key: string, def: string): string {
    const v = this.sp.getSync(key, def);
    return typeof v === 'string' ? v as string : def;
  }

  num(key: string, def: number): number {
    const v = this.sp.getSync(key, def);
    return typeof v === 'number' ? v as number : def;
  }

  bool(key: string, def: boolean): boolean {
    const v = this.sp.getSync(key, def);
    return typeof v === 'boolean' ? v as boolean : def;
  }

  put(key: string, v: string | number | boolean): void {
    try {
      this.sp.putSync(key, v);
      this.sp.flush().catch(() => {
      });
    } catch (e) {
      // ignore
    }
  }

  remove(key: string): void {
    try {
      this.sp.deleteSync(key);
      this.sp.flush().catch(() => {
      });
    } catch (e) {
      // ignore
    }
  }

  getBackends(): Backend[] {
    const out: Backend[] = [];
    const v = parseJson(this.str('backends', '[]'));
    if (v === undefined || !Array.isArray(v)) {
      return out;
    }
    const arr = v as Object[];
    for (const e of arr) {
      const o = asObj(e);
      if (o !== undefined) {
        const b = Backend.fromJson(o);
        if (b.id.length > 0) {
          out.push(b);
        }
      }
    }
    return out;
  }

  setBackends(list: Backend[]): void {
    const arr: Object[] = [];
    for (const b of list) {
      arr.push(b.toJson());
    }
    this.put('backends', JSON.stringify(arr));
  }
}
