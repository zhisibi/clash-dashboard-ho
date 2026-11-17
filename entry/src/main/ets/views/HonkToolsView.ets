import { Store } from '../common/Store';
import { JObj, asNum, jArr, jBool, jGet, jNum, jObj, jStr, parseIsoMillis } from '../common/Models';
import { fmtBytes, fmtClock } from '../common/Format';
import { HeaderStatus, SegTabs } from '../components/Widgets';
import { GlassHeader, headerGuess } from '../components/GlassHeader';
import { HonkCoreApi } from '../common/HonkCoreApi';
import { errMsg } from '../common/CoreApi';
import { t } from '../common/I18n';

const DNS_TYPES: string[] = ['A', 'AAAA', 'CNAME', 'TXT', 'NS', 'MX', 'HTTPS', 'PTR'];

class KvRow {
  k: string = '';
  v: string = '';
}

class RuleRow {
  idx: number = 0;
  type: string = '';
  payload: string = '';
  target: string = '';
}

class CacheRow {
  id: string = '';
  domain: string = '';
  answers: string = '';
  expires: string = '';
}

class GeoRow {
  name: string = '';
  meta: string = '';
}

function objArr(o: JObj | undefined, k: string): JObj[] {
  const out: JObj[] = [];
  if (o === undefined) {
    return out;
  }
  const a = jArr(o, k);
  if (a === undefined) {
    return out;
  }
  for (const e of a) {
    out.push(e as JObj);
  }
  return out;
}

function scalarText(v: Object | undefined): string {
  if (v === undefined) {
    return '';
  }
  if (typeof v === 'string') {
    return v as string;
  }
  if (typeof v === 'number' || typeof v === 'boolean') {
    return String(v);
  }
  return '';
}

/**
 * 1.5.0: honk-mode tools page (replaces the logs tab for honk backends) =
 * the standalone Honk panel's tools page (DNS / rules / routing trace /
 * geodata / runtime), drawn with this app's design system.
 */
@ComponentV2({ freezeWhenInactive: true })
export struct HonkToolsView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(1);
  private sc: Scroller = new Scroller();

  @Local tab: number = 0;
  @Local busy: boolean = false;
  @Local errText: string = '';

  // DNS
  @Local dnsSub: number = 0;
  @Local qDomain: string = '';
  @Local qTypes: string[] = ['A', 'AAAA'];
  @Local qMode: string = 'normal';
  @Local qResults: JObj[] = [];
  @Local qRaw: string = '';
  @Local cacheFilter: string = '';
  @Local cacheRows: CacheRow[] = [];
  @Local cacheMsg: string = '';
  @Local logRows: string[] = [];

  // rules
  @Local rules: RuleRow[] = [];
  @Local dnsRules: string[] = [];
  @Local rulesLoaded: boolean = false;

  // trace
  @Local tDomain: string = '';
  @Local tIp: string = '';
  @Local tPort: string = '443';
  @Local tNetwork: string = 'tcp';
  @Local traceOutbound: string = '';
  @Local traceEvals: JObj[] = [];
  @Local traceRaw: string = '';

  // geodata
  @Local geoRows: GeoRow[] = [];
  @Local geoMeta: string = '';

  // runtime
  @Local rtSettings: KvRow[] = [];
  @Local rtDatapath: KvRow[] = [];
  @Local rtCaps: KvRow[] = [];
  @Local rtLoaded: boolean = false;

  private api(): HonkCoreApi | null {
    return this.store.honkApi();
  }

  private toastErr(e: Object): void {
    this.store.toast(errMsg(e));
  }

  // ---------------- DNS ----------------

  private toggleType(ty: string): void {
    const next: string[] = [];
    let found = false;
    for (const x of this.qTypes) {
      if (x === ty) {
        found = true;
      } else {
        next.push(x);
      }
    }
    if (!found) {
      next.push(ty);
    }
    this.qTypes = next;
  }

  private async doQuery(): Promise<void> {
    const api = this.api();
    if (api === null || this.busy) {
      return;
    }
    const domain = this.qDomain.trim();
    if (domain === '' || this.qTypes.length === 0) {
      return;
    }
    this.busy = true;
    try {
      const res = await api.nDnsQuery(domain, this.qTypes, this.qMode);
      let list = objArr(res, 'results');
      if (list.length === 0 && jArr(res, 'answers') !== undefined) {
        list = [res];
      }
      this.qResults = list;
      this.qRaw = list.length === 0 ? JSON.stringify(res).substring(0, 2000) : '';
    } catch (e) {
      this.toastErr(e as Object);
    }
    this.busy = false;
  }

  private async loadCache(): Promise<void> {
    const api = this.api();
    if (api === null || this.busy) {
      return;
    }
    this.busy = true;
    try {
      const res = await api.nDnsCache(this.cacheFilter.trim(), 200);
      let entries = objArr(res, 'entries');
      if (entries.length === 0) {
        entries = objArr(res, 'records');
      }
      const rows: CacheRow[] = [];
      for (const e of entries) {
        const r = new CacheRow();
        r.id = jStr(e, 'id');
        r.domain = jStr(e, 'domain') || jStr(e, 'name');
        const ans = jArr(e, 'answers');
        const parts: string[] = [];
        if (ans !== undefined) {
          for (const a of ans) {
            const ao = a as JObj;
            parts.push(jStr(ao, 'type') + ' ' + jStr(ao, 'data'));
          }
        }
        r.answers = parts.join(' · ');
        const exp = jStr(e, 'expires_at');
        r.expires = exp !== '' ? fmtClock(parseIsoMillis(exp)) : '';
        rows.push(r);
      }
      this.cacheRows = rows;
      const usage = jObj(res, 'usage');
      this.cacheMsg = usage !== undefined ? JSON.stringify(usage).substring(0, 120) : '';
    } catch (e) {
      this.toastErr(e as Object);
    }
    this.busy = false;
  }

  private async loadDnsLog(): Promise<void> {
    const api = this.api();
    if (api === null || this.busy) {
      return;
    }
    this.busy = true;
    try {
      const res = await api.nDnsLog('', 100);
      let entries = objArr(res, 'entries');
      if (entries.length === 0) {
        entries = objArr(res, 'logs');
      }
      if (entries.length === 0) {
        entries = objArr(res, 'records');
      }
      const rows: string[] = [];
      for (const e of entries) {
        const name = jStr(e, 'name') || jStr(e, 'domain') || jStr(e, 'question');
        const ty = jStr(e, 'type');
        const ans = jStr(e, 'answer') || jStr(e, 'result') || jStr(e, 'status');
        const at = jStr(e, 'time') || jStr(e, 'at') || jStr(e, 'timestamp');
        rows.push((at !== '' ? at + '  ' : '') + name + (ty !== '' ? ' ' + ty : '') +
          (ans !== '' ? ' → ' + ans : ''));
      }
      this.logRows = rows;
    } catch (e) {
      this.toastErr(e as Object);
    }
    this.busy = false;
  }

  // ---------------- rules ----------------

  private async loadRules(): Promise<void> {
    const api = this.api();
    if (api === null || this.busy) {
      return;
    }
    this.busy = true;
    try {
      const root = await api.nRulesRaw();
      let items = objArr(root, 'rules');
      const rows: RuleRow[] = [];
      for (let i = 0; i < items.length; i++) {
        const r = items[i];
        const row = new RuleRow();
        row.idx = i;
        const match = jObj(r, 'match');
        row.type = jStr(r, 'type') || jStr(r, 'kind') || (match !== undefined ? jStr(match, 'type') : '');
        row.payload = jStr(r, 'payload') || jStr(r, 'value') || (match !== undefined ? jStr(match, 'value') : '');
        row.target = jStr(r, 'target') || jStr(r, 'outbound') || jStr(r, 'action') || jStr(r, 'proxy');
        rows.push(row);
      }
      this.rules = rows;
      try {
        const dr = await api.nDnsRules();
        let dItems = objArr(dr, 'rules');
        const dRows: string[] = [];
        for (const r of dItems) {
          const name = jStr(r, 'domain') || jStr(r, 'name') || jStr(r, 'pattern');
          const act = jStr(r, 'action') || jStr(r, 'target') || jStr(r, 'outbound') || jStr(r, 'server');
          dRows.push(name + (act !== '' ? ' → ' + act : ''));
        }
        this.dnsRules = dRows;
      } catch (e) {
        this.dnsRules = [];
      }
      this.rulesLoaded = true;
    } catch (e) {
      this.toastErr(e as Object);
    }
    this.busy = false;
  }

  // ---------------- trace ----------------

  private async doTrace(): Promise<void> {
    const api = this.api();
    if (api === null || this.busy) {
      return;
    }
    const port = Number(this.tPort.trim());
    if (isNaN(port) || port < 1 || port > 65535) {
      this.store.toast(t('err_port_invalid'));
      return;
    }
    if (this.tDomain.trim() === '' && this.tIp.trim() === '') {
      return;
    }
    this.busy = true;
    try {
      const input: JObj = {};
      input['network'] = this.tNetwork;
      if (this.tDomain.trim() !== '') {
        input['domain'] = this.tDomain.trim();
      }
      if (this.tIp.trim() !== '') {
        input['dst_ip'] = this.tIp.trim();
      }
      input['dst_port'] = port;
      const body: JObj = {};
      body['input'] = input;
      const res = await api.nRoutingTrace(JSON.stringify(body));
      const dec = jObj(res, 'decision');
      let out = jStr(res, 'outbound');
      if (out === '' && dec !== undefined) {
        out = jStr(dec, 'outbound') || jStr(dec, 'action');
      }
      this.traceOutbound = out;
      this.traceEvals = objArr(res, 'evaluations');
      this.traceRaw = this.traceEvals.length === 0 ? JSON.stringify(res).substring(0, 2500) : '';
    } catch (e) {
      this.toastErr(e as Object);
    }
    this.busy = false;
  }

  // ---------------- geodata ----------------

  private async loadGeo(): Promise<void> {
    const api = this.api();
    if (api === null || this.busy) {
      return;
    }
    this.busy = true;
    try {
      const res = await api.nGeodata();
      const rows: GeoRow[] = [];
      for (const a of objArr(res, 'assets')) {
        const r = new GeoRow();
        r.name = jStr(a, 'name') || jStr(a, 'kind') || jStr(a, 'id');
        const size = jNum(a, 'size_bytes') || jNum(a, 'size');
        const upd = jStr(a, 'updated_at') || jStr(a, 'last_updated_at');
        r.meta = (size > 0 ? fmtBytes(size) : '') +
          (upd !== '' ? ' · ' + fmtClock(parseIsoMillis(upd)) : '');
        rows.push(r);
      }
      this.geoRows = rows;
      const lc = jStr(res, 'last_checked_at');
      this.geoMeta = lc !== '' ? fmtClock(parseIsoMillis(lc)) : '';
    } catch (e) {
      this.toastErr(e as Object);
    }
    this.busy = false;
  }

  // ---------------- runtime ----------------

  private flatten(o: JObj | undefined, out: KvRow[], prefix: string): void {
    if (o === undefined) {
      return;
    }
    for (const k of Object.keys(o)) {
      const v = jGet(o, k);
      const s = scalarText(v);
      if (s !== '') {
        const row = new KvRow();
        row.k = prefix + k;
        row.v = s;
        out.push(row);
      } else {
        const child = jObj(o, k);
        if (child !== undefined) {
          this.flatten(child, out, prefix + k + '.');
        }
      }
    }
  }

  private async loadRuntime(): Promise<void> {
    const api = this.api();
    if (api === null || this.busy) {
      return;
    }
    this.busy = true;
    try {
      const s = await api.nRuntimeSettings();
      const sRows: KvRow[] = [];
      this.flatten(s, sRows, '');
      this.rtSettings = sRows.slice(0, 60);
      const dp = await api.nDatapath();
      const dRows: KvRow[] = [];
      this.flatten(dp, dRows, '');
      this.rtDatapath = dRows.slice(0, 40);
      try {
        const caps = await api.nCapabilities();
        const cRows: KvRow[] = [];
        this.flatten(caps, cRows, '');
        this.rtCaps = cRows.slice(0, 40);
      } catch (e) {
        this.rtCaps = [];
      }
      this.rtLoaded = true;
    } catch (e) {
      this.toastErr(e as Object);
    }
    this.busy = false;
  }

  private evalText(e: JObj): string {
    let v = jGet(e, 'rule');
    if (v === undefined) {
      v = jGet(e, 'match');
    }
    if (v === undefined) {
      v = jGet(e, 'description');
    }
    if (v === undefined) {
      return '';
    }
    try {
      const s = JSON.stringify(v);
      return s !== undefined && s !== null ? s.substring(0, 160) : '';
    } catch (err) {
      return '';
    }
  }

  private onTab(i: number): void {
    this.tab = i;
    if (i === 1 && !this.rulesLoaded) {
      this.loadRules();
    }
    if (i === 3 && this.geoRows.length === 0) {
      this.loadGeo();
    }
    if (i === 4 && !this.rtLoaded) {
      this.loadRuntime();
    }
  }

  // ---------------- builders ----------------

  @Builder
  kvList(rows: KvRow[]) {
    ForEach(rows, (r: KvRow) => {
      Row() {
        Text(r.k).fontSize(13).fontColor(this.store.palette().subtle)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(r.v).fontSize(13).fontColor(this.store.palette().text)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ top: 5, bottom: 5 })
    }, (r: KvRow) => r.k)
  }

  @Builder
  cardTitle(title: string) {
    Text(title).fontSize(16).fontWeight(FontWeight.Medium)
      .fontColor(this.store.palette().text)
      .margin({ bottom: 8 })
  }

  @Builder
  dnsSection() {
    Column({ space: 12 }) {
      SegTabs({
        pal: this.store.palette(),
        items: [t('honk_dns_query'), t('honk_dns_cache'), t('honk_dns_log')],
        selected: this.dnsSub,
        onSelect: (i: number) => {
          this.dnsSub = i;
          if (i === 1 && this.cacheRows.length === 0) {
            this.loadCache();
          }
          if (i === 2 && this.logRows.length === 0) {
            this.loadDnsLog();
          }
        }
      })

      if (this.dnsSub === 0) {
        Column() {
          this.cardTitle(t('honk_dns_query'))
          TextInput({ text: this.qDomain, placeholder: 'example.com' })
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontColor(this.store.palette().text)
            .placeholderColor(this.store.palette().subtle)
            .backgroundColor(this.store.palette().chip)
            .borderRadius(12)
            .onChange((v: string) => {
              this.qDomain = v;
            })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(DNS_TYPES, (ty: string) => {
              Text(ty)
                .fontSize(12)
                .fontColor(this.qTypes.indexOf(ty) >= 0 ? this.store.palette().onPrimary :
                  this.store.palette().text)
                .backgroundColor(this.qTypes.indexOf(ty) >= 0 ? this.store.palette().primary :
                  this.store.palette().chip)
                .borderRadius(14)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .margin({ right: 6, bottom: 6 })
                .onClick(() => {
                  this.toggleType(ty);
                })
            }, (ty: string) => ty)
          }
          .margin({ top: 10 })
          Row({ space: 6 }) {
            Text('normal')
              .fontSize(12)
              .fontColor(this.qMode === 'normal' ? this.store.palette().onPrimary : this.store.palette().text)
              .backgroundColor(this.qMode === 'normal' ? this.store.palette().primary : this.store.palette().chip)
              .borderRadius(14)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => {
                this.qMode = 'normal';
              })
            Text('bypass')
              .fontSize(12)
              .fontColor(this.qMode === 'bypass' ? this.store.palette().onPrimary : this.store.palette().text)
              .backgroundColor(this.qMode === 'bypass' ? this.store.palette().primary : this.store.palette().chip)
              .borderRadius(14)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => {
                this.qMode = 'bypass';
              })
          }
          Button(this.busy ? '…' : t('honk_query'))
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontColor(this.store.palette().onPrimary)
            .backgroundColor(this.store.palette().primary)
            .margin({ top: 10 })
            .onClick(() => {
              this.doQuery();
            })
          ForEach(this.qResults, (r: JObj) => {
            Column() {
              Row() {
                Text(jStr(r, 'type')).fontSize(13).fontWeight(FontWeight.Bold)
                  .fontColor(this.store.palette().accent)
                Text(jStr(r, 'status')).fontSize(12).fontColor(this.store.palette().subtle)
                  .margin({ left: 8 })
                Blank()
                Text(jNum(r, 'elapsed_ms').toString() + ' ms').fontSize(12)
                  .fontColor(this.store.palette().subtle)
              }
              .width('100%')
              Text((jBool(r, 'cached', false) ? 'cached · ' : '') + jStr(r, 'upstream'))
                .fontSize(12)
                .fontColor(this.store.palette().subtle)
                .margin({ top: 3 })
              ForEach(objArr(r, 'answers'), (a: JObj) => {
                Text(jStr(a, 'name') + '  ' + jStr(a, 'type') + '  TTL ' + jStr(a, 'ttl') + '  ' + jStr(a, 'data'))
                  .fontSize(12)
                  .fontColor(this.store.palette().text)
                  .margin({ top: 3 })
              }, (a: JObj) => jStr(a, 'name') + jStr(a, 'type') + jStr(a, 'data'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 12 })
          }, (r: JObj) => jStr(r, 'type') + jStr(r, 'status'))
          if (this.qRaw !== '') {
            Text(this.qRaw).fontSize(11).fontColor(this.store.palette().subtle)
              .margin({ top: 10 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .borderRadius(18)
        .attributeModifier(this.store.glass('card'))
      } else if (this.dnsSub === 1) {
        Column() {
          Row() {
            Text(t('honk_dns_cache')).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(this.store.palette().text).layoutWeight(1)
            Button(t('act_refresh'))
              .height(38)
              .fontSize(13)
              .fontColor(this.store.palette().text)
              .backgroundColor(this.store.palette().chip)
              .onClick(() => {
                this.loadCache();
              })
            Button(t('honk_flush'))
              .height(38)
              .fontSize(13)
              .fontColor(this.store.palette().bad)
              .backgroundColor(this.store.palette().chip)
              .margin({ left: 6 })
              .onClick(() => {
                const api = this.api();
                if (api !== null) {
                  api.flushDns().then(() => {
                    this.store.toast(t('act_ok', t('honk_flush')));
                    this.loadCache();
                  }).catch((e: Object) => {
                    this.toastErr(e);
                  });
                }
              })
          }
          .width('100%')
          if (this.cacheMsg !== '') {
            Text(this.cacheMsg).fontSize(11).fontColor(this.store.palette().subtle)
              .margin({ top: 4, bottom: 4 })
          }
          ForEach(this.cacheRows, (r: CacheRow) => {
            Row() {
              Column() {
                Text(r.domain).fontSize(14).fontColor(this.store.palette().text)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                if (r.answers !== '') {
                  Text(r.answers).fontSize(12).fontColor(this.store.palette().subtle)
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 2 })
                }
                if (r.expires !== '') {
                  Text(r.expires).fontSize(11).fontColor(this.store.palette().subtle)
                    .margin({ top: 2 })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (r.id !== '') {
                SymbolGlyph($r('sys.symbol.trash'))
                  .fontSize(18)
                  .fontColor([this.store.palette().subtle])
                  .onClick(() => {
                    const api = this.api();
                    if (api !== null) {
                      api.nDeleteDnsCacheEntry(r.id).then(() => {
                        this.loadCache();
                      }).catch((e: Object) => {
                        this.toastErr(e);
                      });
                    }
                  })
              }
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
          }, (r: CacheRow) => r.domain + r.answers)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .borderRadius(18)
        .attributeModifier(this.store.glass('card'))
      } else {
        Column() {
          Row() {
            Text(t('honk_dns_log')).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(this.store.palette().text).layoutWeight(1)
            Button(t('act_refresh'))
              .height(38)
              .fontSize(13)
              .fontColor(this.store.palette().text)
              .backgroundColor(this.store.palette().chip)
              .onClick(() => {
                this.loadDnsLog();
              })
          }
          .width('100%')
          if (this.logRows.length === 0) {
            Text('-').fontSize(13).fontColor(this.store.palette().subtle)
              .margin({ top: 8 })
          }
          ForEach(this.logRows, (line: string) => {
            Text(line).fontSize(12).fontColor(this.store.palette().text)
              .padding({ top: 3, bottom: 3 })
          }, (line: string) => line)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .borderRadius(18)
        .attributeModifier(this.store.glass('card'))
      }
    }
    .width('100%')
  }

  @Builder
  rulesSection() {
    Column({ space: 12 }) {
      Column() {
        this.cardTitle(t('rules'))
        ForEach(this.rules, (r: RuleRow) => {
          Row() {
            Text(r.type).fontSize(12).fontColor(this.store.palette().accent)
              .maxLines(1)
            Text(r.payload).fontSize(13).fontColor(this.store.palette().text)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ left: 8 })
            Text(r.target).fontSize(12).fontColor(this.store.palette().good)
              .maxLines(1)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
        }, (r: RuleRow) => r.idx.toString())
        if (this.rules.length === 0) {
          Text('-').fontSize(13).fontColor(this.store.palette().subtle)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(18)
      .attributeModifier(this.store.glass('card'))

      if (this.dnsRules.length > 0) {
        Column() {
          this.cardTitle(t('honk_dns_rules'))
          ForEach(this.dnsRules, (line: string) => {
            Text(line).fontSize(13).fontColor(this.store.palette().text)
              .padding({ top: 3, bottom: 3 })
          }, (line: string) => line)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .borderRadius(18)
        .attributeModifier(this.store.glass('card'))
      }
    }
    .width('100%')
  }

  @Builder
  traceSection() {
    Column() {
      this.cardTitle(t('honk_trace'))
      TextInput({ text: this.tDomain, placeholder: t('honk_domain') })
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor(this.store.palette().text)
        .placeholderColor(this.store.palette().subtle)
        .backgroundColor(this.store.palette().chip)
        .borderRadius(12)
        .onChange((v: string) => {
          this.tDomain = v;
        })
      Row({ space: 8 }) {
        TextInput({ text: this.tIp, placeholder: 'IP' })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(this.store.palette().text)
          .placeholderColor(this.store.palette().subtle)
          .backgroundColor(this.store.palette().chip)
          .borderRadius(12)
          .onChange((v: string) => {
            this.tIp = v;
          })
        TextInput({ text: this.tPort, placeholder: '443' })
          .width(90)
          .height(44)
          .type(InputType.Number)
          .fontSize(14)
          .fontColor(this.store.palette().text)
          .placeholderColor(this.store.palette().subtle)
          .backgroundColor(this.store.palette().chip)
          .borderRadius(12)
          .onChange((v: string) => {
            this.tPort = v;
          })
      }
      .width('100%')
      .margin({ top: 8 })
      Row({ space: 6 }) {
        Text('tcp')
          .fontSize(12)
          .fontColor(this.tNetwork === 'tcp' ? this.store.palette().onPrimary : this.store.palette().text)
          .backgroundColor(this.tNetwork === 'tcp' ? this.store.palette().primary : this.store.palette().chip)
          .borderRadius(14)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .onClick(() => {
            this.tNetwork = 'tcp';
          })
        Text('udp')
          .fontSize(12)
          .fontColor(this.tNetwork === 'udp' ? this.store.palette().onPrimary : this.store.palette().text)
          .backgroundColor(this.tNetwork === 'udp' ? this.store.palette().primary : this.store.palette().chip)
          .borderRadius(14)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .onClick(() => {
            this.tNetwork = 'udp';
          })
      }
      .margin({ top: 10 })
      Button(this.busy ? '…' : t('honk_trace'))
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor(this.store.palette().onPrimary)
        .backgroundColor(this.store.palette().primary)
        .margin({ top: 10 })
        .onClick(() => {
          this.doTrace();
        })
      if (this.traceOutbound !== '') {
        Text('→ ' + this.traceOutbound)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().good)
          .margin({ top: 12 })
      }
      ForEach(this.traceEvals, (e: JObj) => {
        Row() {
          Text(jStr(e, 'result'))
            .fontSize(12)
            .fontColor(jStr(e, 'result') === 'matched' ? this.store.palette().good : this.store.palette().subtle)
          Text(this.evalText(e))
            .fontSize(12)
            .fontColor(this.store.palette().text)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width('100%')
        .padding({ top: 5, bottom: 5 })
      }, (e: JObj) => JSON.stringify(e).substring(0, 60))
      if (this.traceRaw !== '') {
        Text(this.traceRaw).fontSize(11).fontColor(this.store.palette().subtle)
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(18)
    .attributeModifier(this.store.glass('card'))
  }

  @Builder
  geoSection() {
    Column() {
      Row() {
        Text(t('honk_geo')).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.store.palette().text).layoutWeight(1)
        Button(t('honk_update'))
          .height(38)
          .fontSize(13)
          .fontColor(this.store.palette().text)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            const api = this.api();
            if (api === null || this.busy) {
              return;
            }
            this.busy = true;
            api.nGeodataUpdate().then(() => {
              this.store.toast(t('act_ok', t('honk_update')));
              this.busy = false;
              this.loadGeo();
            }).catch((e: Object) => {
              this.toastErr(e);
              this.busy = false;
            });
          })
      }
      .width('100%')
      if (this.geoMeta !== '') {
        Text(this.geoMeta).fontSize(12).fontColor(this.store.palette().subtle)
          .margin({ bottom: 4 })
      }
      ForEach(this.geoRows, (r: GeoRow) => {
        Row() {
          Text(r.name).fontSize(14).fontColor(this.store.palette().text)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(r.meta).fontSize(12).fontColor(this.store.palette().subtle)
        }
        .width('100%')
        .padding({ top: 7, bottom: 7 })
      }, (r: GeoRow) => r.name)
      if (this.geoRows.length === 0) {
        Text('-').fontSize(13).fontColor(this.store.palette().subtle)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(18)
    .attributeModifier(this.store.glass('card'))
  }

  @Builder
  runtimeSection() {
    Column({ space: 12 }) {
      Column() {
        this.cardTitle(t('honk_runtime_settings'))
        this.kvList(this.rtSettings)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(18)
      .attributeModifier(this.store.glass('card'))
      Column() {
        this.cardTitle(t('honk_datapath'))
        this.kvList(this.rtDatapath)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(18)
      .attributeModifier(this.store.glass('card'))
      if (this.rtCaps.length > 0) {
        Column() {
          this.cardTitle(t('honk_capabilities'))
          this.kvList(this.rtCaps)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .borderRadius(18)
        .attributeModifier(this.store.glass('card'))
      }
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.sc) {
        Column({ space: 12 }) {
          SegTabs({
            pal: this.store.palette(),
            items: ['DNS', t('rules'), t('honk_trace'), t('honk_geo'), t('honk_runtime')],
            selected: this.tab,
            onSelect: (i: number) => {
              this.onTab(i);
            }
          })
          if (this.tab === 0) {
            this.dnsSection()
          } else if (this.tab === 1) {
            this.rulesSection()
          } else if (this.tab === 2) {
            this.traceSection()
          } else if (this.tab === 3) {
            this.geoSection()
          } else {
            this.runtimeSection()
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: this.headerH + 8, bottom: this.bottomPad })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onDidScroll((x: number, y: number, st: ScrollState) => {
        this.store.navScroll(this.sc, y, st);
      })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })

      GlassHeader({
        hPad: 20, onHeight: (h: number) => {
          this.headerH = h;
        }
      }) {
        HeaderStatus({
          pal: this.store.palette(),
          title: t('tab_tools'),
          connState: this.store.connState,
          address: this.store.active !== null ? this.store.active.display() : t('not_connected'),
          tag: this.store.version
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.store.palette().bg)
  }
}
