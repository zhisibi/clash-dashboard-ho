import { WidgetBody } from './WidgetBody';

/** Wide service widget (2x4), the default form: speeds, connections, node and egress at a glance. */
let storage = new LocalStorage();

@Entry(storage)
@Component
struct WidgetCard {
  @LocalStorageProp('brand') brand: string = 'Mimi Panel';
  @LocalStorageProp('connected') connected: boolean = false;
  @LocalStorageProp('statusText') statusText: string = 'Not connected';
  @LocalStorageProp('labelText') labelText: string = '';
  @LocalStorageProp('upText') upText: string = '0 B/s';
  @LocalStorageProp('downText') downText: string = '0 B/s';
  @LocalStorageProp('connText') connText: string = '0';
  @LocalStorageProp('memText') memText: string = '-';
  @LocalStorageProp('totalText') totalText: string = '';
  @LocalStorageProp('modeText') modeText: string = '';
  @LocalStorageProp('nodeText') nodeText: string = '';
  @LocalStorageProp('modeKey') modeKey: string = '';
  @LocalStorageProp('modeRuleText') modeRuleText: string = 'Rule';
  @LocalStorageProp('modeGlobalText') modeGlobalText: string = 'Global';
  @LocalStorageProp('modeDirectText') modeDirectText: string = 'Direct';
  @LocalStorageProp('hasRule') hasRule: boolean = true;
  @LocalStorageProp('hasGlobal') hasGlobal: boolean = true;
  @LocalStorageProp('hasDirect') hasDirect: boolean = true;
  @LocalStorageProp('switchText') switchText: string = 'Switch';
  @LocalStorageProp('msgText') msgText: string = '';
  @LocalStorageProp('groupName') groupName: string = '';
  @LocalStorageProp('egressText') egressText: string = '';
  @LocalStorageProp('egressIp') egressIp: string = '';
  @LocalStorageProp('hasEgress') hasEgress: boolean = false;
  @LocalStorageProp('updatedText') updatedText: string = '';
  @LocalStorageProp('bgA') bgA: string = '#0A59F7';
  @LocalStorageProp('bgB') bgB: string = '#0646C8';

  build() {
    Stack() {
      WidgetBody({
      brand: this.brand,
      connected: this.connected,
      statusText: this.statusText,
      labelText: this.labelText,
      upText: this.upText,
      downText: this.downText,
      connText: this.connText,
      memText: this.memText,
      totalText: this.totalText,
      modeText: this.modeText,
      nodeText: this.nodeText,
      modeKey: this.modeKey,
      modeRuleText: this.modeRuleText,
      modeGlobalText: this.modeGlobalText,
      modeDirectText: this.modeDirectText,
      hasRule: this.hasRule,
      hasGlobal: this.hasGlobal,
      hasDirect: this.hasDirect,
      switchText: this.switchText,
      msgText: this.msgText,
      groupName: this.groupName,
      egressText: this.egressText,
      egressIp: this.egressIp,
      hasEgress: this.hasEgress,
      updatedText: this.updatedText,
      bgA: this.bgA,
      bgB: this.bgB,
        compact: false
      })
    }
  }
}
