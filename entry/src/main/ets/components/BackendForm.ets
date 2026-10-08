import { Store } from '../common/Store';
import { Backend } from '../common/Models';
import { errMsg } from '../common/CoreApi';
import { SegTabs } from './Widgets';
import { t } from '../common/I18n';

/** Backend form (Kotlin BackendForm), shared by first-run setup and Add/Edit Backend */
@ComponentV2
export struct BackendForm {
  private store: Store = Store.get();
  @Param initial: Backend = new Backend('');
  @Param showCancel: boolean = false;
  @Event onSaved: () => void = () => {
  };
  @Event onCancel: () => void = () => {
  };
  @Local protocol: string = 'http';
  @Local host: string = '127.0.0.1';
  @Local port: string = '9090';
  @Local path: string = '';
  @Local secret: string = '';
  @Local label: string = '';
  @Local status: string = '';
  @Local statusOk: boolean = false;
  @Local busy: boolean = false;
  /** Field that failed validation ('host' | 'port'), highlighted in red */
  @Local errField: string = '';

  aboutToAppear(): void {
    this.protocol = this.initial.protocol;
    this.host = this.initial.host;
    this.port = this.initial.port;
    this.path = this.initial.secondaryPath;
    this.secret = this.initial.secret;
    this.label = this.initial.label;
  }

  buildBackend(): Backend {
    const b = this.initial.copy();
    if (b.id.length === 0) {
      b.id = this.store.newBackendId();
    }
    b.protocol = this.protocol;
    b.host = this.host.trim();
    b.port = this.port.trim();
    b.secondaryPath = this.path.trim();
    b.secret = this.secret;
    b.label = this.label.trim();
    return b;
  }

  /**
   * 1.2.1: buttons stay enabled (a disabled button's 40% opacity failed the AppGallery contrast check);
   * validate on tap instead: toast the missing field and highlight it.
   */
  validate(): boolean {
    let key = '';
    let msg = '';
    const port = Number(this.port.trim());
    if (this.host.trim().length === 0) {
      key = 'host';
      msg = t('err_host_required');
    } else if (this.port.trim().length === 0) {
      key = 'port';
      msg = t('err_port_required');
    } else if (!Number.isInteger(port) || port < 1 || port > 65535) {
      key = 'port';
      msg = t('err_port_invalid');
    }
    this.errField = key;
    if (key.length > 0) {
      this.status = '✗ ' + msg;
      this.statusOk = false;
      this.store.toast(msg);
      return false;
    }
    return true;
  }

  clearErr(key: string): void {
    if (this.errField === key) {
      this.errField = '';
      this.status = '';
    }
  }

  @Builder
  field(label: string, value: string, placeholder: string, kind: number, err: boolean, onChange: (v: string) => void) {
    Column() {
      Text(label).fontSize(12).fontColor(err ? this.store.palette().bad : this.store.palette().subtle)
        .margin({ left: 4, bottom: 4 })
      TextInput({ text: value, placeholder: placeholder })
        .type(kind === 1 ? InputType.Number : (kind === 2 ? InputType.Password : InputType.Normal))
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor(this.store.palette().text)
        .placeholderColor(this.store.palette().subtle)
        .caretColor(this.store.palette().accent)
        .backgroundColor(this.store.palette().chip)
        .borderRadius(12)
        .border({ width: err ? 1.5 : 0, color: this.store.palette().bad, radius: 12 })
        .onChange((v: string) => {
          onChange(v);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 10 }) {
      SegTabs({
        pal: this.store.palette(),
        items: ['http', 'https'],
        selected: this.protocol === 'https' ? 1 : 0,
        onSelect: (i: number) => {
          this.protocol = i === 1 ? 'https' : 'http';
        }
      })
      Row({ space: 8 }) {
        Column() {
          this.field(t('f_host'), this.host, '127.0.0.1', 0, this.errField === 'host', (v: string) => {
            this.host = v;
            this.clearErr('host');
          })
        }
        .layoutWeight(1)

        Column() {
          this.field(t('f_port'), this.port, '9090', 1, this.errField === 'port', (v: string) => {
            this.port = v.replace(new RegExp('[^0-9]', 'g'), '').substring(0, 5);
            this.clearErr('port');
          })
        }
        .width(110)
      }
      .width('100%')

      this.field(t('f_path'), this.path, t('optional'), 0, false, (v: string) => {
        this.path = v;
      })
      this.field(t('f_secret'), this.secret, t('optional'), 2, false, (v: string) => {
        this.secret = v;
      })
      this.field(t('f_label'), this.label, t('optional'), 0, false, (v: string) => {
        this.label = v;
      })

      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(13)
          .fontColor(this.statusOk ? this.store.palette().good : this.store.palette().bad)
      }

      Button({ type: ButtonType.Capsule }) {
        Row() {
          if (this.busy) {
            LoadingProgress().width(18).height(18).color(this.store.palette().text).margin({ right: 8 })
          }
          Text(t('test_conn')).fontSize(15).fontColor(this.store.palette().text).maxLines(1)
        }
      }
      .width('100%')
      .height(44)
      .backgroundColor(this.store.palette().chip)
      .onClick(() => {
        if (this.busy || !this.validate()) {
          return;
        }
        this.busy = true;
        this.status = '';
        this.store.probe(this.buildBackend()).then((v: string) => {
          this.status = t('test_ok', v);
          this.statusOk = true;
        }).catch((e: Object) => {
          this.status = '✗ ' + errMsg(e);
          this.statusOk = false;
        }).finally(() => {
          this.busy = false;
        });
      })

      Row({ space: 8 }) {
        if (this.showCancel) {
          Button(t('cancel'), { type: ButtonType.Capsule })
            .layoutWeight(1)
            .height(44)
            .fontColor(this.store.palette().text)
            .backgroundColor(this.store.palette().chip)
            .onClick(() => {
              this.onCancel();
            })
        }
        Button(t('save_connect'), { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontColor(this.store.palette().onPrimary)
          .backgroundColor(this.store.palette().primary)
          .onClick(() => {
            if (!this.validate()) {
              return;
            }
            this.store.saveBackend(this.buildBackend(), true);
            this.onSaved();
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
