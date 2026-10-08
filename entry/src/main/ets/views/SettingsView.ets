import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileUri } from '@kit.CoreFileKit';
import { Store } from '../common/Store';
import { GlassHeader, headerGuess } from '../components/GlassHeader';
import { ACCENTS, AccentDef } from '../common/Theme';
import { Backend } from '../common/Models';
import { CoreApi } from '../common/CoreApi';
import { CrashLog } from '../common/CrashLog';
import { LEGAL_CONTACT, LEGAL_DEVELOPER } from '../common/Legal';
import { FileUtil } from '../common/FileUtil';
import { modeName } from '../common/Format';
import { DropdownChip, HeaderStatus, SearchBox, SegTabs } from '../components/Widgets';
import { Group, NumberRow, RowItem, SliderRow, SwitchRow } from '../components/SettingRows';
import { BackendForm } from '../components/BackendForm';
import { bothLangs, isEn, langOptionLabel, LANG_KEYS, systemLang, t } from '../common/I18n';

class Section {
  key: string = '';
  title: string = '';
  desc: string = '';
  icon: Resource;
  keywords: string = '';

  constructor(key: string, title: string, desc: string, icon: Resource, keywords: string) {
    this.key = key;
    this.title = title;
    this.desc = desc;
    this.icon = icon;
    this.keywords = keywords;
  }
}

/** title / desc / keywords are i18n keys; search matches the keywords in both languages */
const SECTIONS: Section[] = [
  new Section('lang', 'lang_title', 'lang_desc', $r('sys.symbol.translate'), 'lang_keywords'),
  new Section('backend', 'sec_backend', 'sec_backend_desc', $r('sys.symbol.externaldrive'), 'sec_backend_kw'),
  new Section('panel', 'sec_panel', 'sec_panel_desc', $r('sys.symbol.house'), 'sec_panel_kw'),
  new Section('proxy', 'sec_proxy', 'sec_proxy_desc', $r('sys.symbol.paperplane'), 'sec_proxy_kw'),
  new Section('conn', 'sec_conn', 'sec_conn_desc', $r('sys.symbol.arrow_left_arrow_right'), 'sec_conn_kw'),
  new Section('crash', 'sec_crash', 'sec_crash_desc', $r('sys.symbol.exclamationmark_magnifyingglass'), 'sec_crash_kw'),
  new Section('about', 'sec_about', 'sec_about_desc', $r('sys.symbol.info_circle'), 'sec_about_kw')
];

const LOG_LEVELS: string[] = ['debug', 'info', 'warning', 'error', 'silent'];
const THEME_KEYS: string[] = ['system', 'light', 'dark'];
const THEME_LABELS: string[] = ['theme_system', 'theme_light', 'theme_dark'];
const GLASS_KEYS: string[] = ['custom', 'thin', 'regular', 'thick'];
const GLASS_LABELS: string[] = ['glass_custom', 'glass_thin', 'glass_regular', 'glass_thick'];
const SORT_KEYS: string[] = ['default', 'latency', 'name'];
const SORT_LABELS: string[] = ['psort_default', 'psort_latency', 'psort_name'];

function tr(keys: string[]): string[] {
  return keys.map((k: string) => t(k));
}

class OpDef {
  title: string = '';
  key: string = '';
  icon: Resource;
  danger: boolean = false;
  confirm: string = '';

  constructor(title: string, key: string, icon: Resource, danger: boolean, confirm: string) {
    this.title = title;
    this.key = key;
    this.icon = icon;
    this.danger = danger;
    this.confirm = confirm;
  }
}

/** title and confirm are i18n keys; key identifies the op (Store.coreAction) */
const OPS: OpDef[] = [
  new OpDef('op_reload', 'reload', $r('sys.symbol.arrow_counterclockwise'), false, ''),
  new OpDef('op_geo', 'geo', $r('sys.symbol.paperplane'), false, ''),
  new OpDef('op_fakeip', 'fakeip', $r('sys.symbol.trash'), false, ''),
  new OpDef('op_dns', 'dns', $r('sys.symbol.trash'), false, ''),
  new OpDef('op_upgrade', 'upgrade', $r('sys.symbol.square_and_arrow_down'), false, 'op_upgrade_confirm'),
  new OpDef('op_restart', 'restart', $r('sys.symbol.power'), true, 'op_restart_confirm')
];

function runOp(store: Store, key: string): void {
  switch (key) {
    case 'reload':
      store.coreAction(key, (a: CoreApi) => a.reloadConfigs());
      break;
    case 'geo':
      store.coreAction(key, (a: CoreApi) => a.upgradeGeo());
      break;
    case 'fakeip':
      store.coreAction(key, (a: CoreApi) => a.flushFakeIp());
      break;
    case 'dns':
      store.coreAction(key, (a: CoreApi) => a.flushDns());
      break;
    case 'upgrade':
      store.coreAction(key, (a: CoreApi) => a.upgradeCore());
      break;
    case 'restart':
      store.coreAction(key, (a: CoreApi) => a.restart());
      break;
    default:
      break;
  }
}

// ---------------- Language (1.2.0) ----------------
@ComponentV2
struct LanguagePage {
  private store: Store = Store.get();

  desc(key: string): string {
    if (key === 'system') {
      return t('lang_current_system', langOptionLabel(systemLang()));
    }
    return '';
  }

  build() {
    Column() {
      Group({ pal: this.store.palette(), title: t('lang_title') }) {
        ForEach(LANG_KEYS, (k: string) => {
          RowItem({
            pal: this.store.palette(),
            title: langOptionLabel(k),
            desc: this.desc(k),
            clickable: true,
            onTap: () => {
              if (this.store.langPref() !== k) {
                this.store.setLanguage(k);
              }
            }
          }) {
            if (this.store.langPref() === k) {
              SymbolGlyph($r('sys.symbol.checkmark')).fontSize(20).fontColor([this.store.palette().accentUi])
            }
          }
        }, (k: string) => k)
      }

      Text(t('lang_note'))
        .fontSize(13)
        .fontColor(this.store.palette().subtle)
        .width('100%')
        .padding({ left: 6, right: 6, top: 10 })
    }
    .width('100%')
  }
}

// ---------------- Backend page ----------------
@ComponentV2
struct BackendPage {
  private store: Store = Store.get();
  @Local editing: Backend = new Backend('');
  @Local editingNew: boolean = true;
  @Local showEditor: boolean = false;
  @Local editorGen: number = 0;

  confirm(msg: string, action: () => void): void {
    this.getUIContext().showAlertDialog({
      title: msg,
      message: '',
      autoCancel: true,
      primaryButton: {
        value: t('cancel'), action: () => {
        }
      },
      secondaryButton: {
        value: t('ok'), fontColor: this.store.palette().bad, action: () => {
          action();
        }
      }
    });
  }

  openEditor(b: Backend, isNew: boolean): void {
    this.editing = b;
    this.editingNew = isNew;
    this.editorGen++;
    this.showEditor = true;
  }

  @Builder
  editorSheet() {
    Column() {
      Text(this.editingNew ? t('add_backend') : t('edit_backend'))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.store.palette().text)
        .margin({ bottom: 12 })
      Scroll() {
        Column() {
          ForEach([this.editorGen], (g: number) => {
            BackendForm({
              initial: this.editing,
              showCancel: true,
              onSaved: () => {
                this.showEditor = false;
              },
              onCancel: () => {
                this.showEditor = false;
              }
            })
          }, (g: number) => 'editor_' + g)
        }
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .attributeModifier(Store.get().glass('card'))
  }

  portValue(key: string): number {
    const c = this.store.config;
    if (key === 'mixed-port') {
      return c.mixedPort;
    }
    if (key === 'port') {
      return c.port;
    }
    if (key === 'socks-port') {
      return c.socksPort;
    }
    if (key === 'redir-port') {
      return c.redirPort;
    }
    return c.tproxyPort;
  }

  build() {
    Column() {
      Group({ pal: this.store.palette(), title: t('backend_list') }) {
        ForEach(this.store.backends, (b: Backend) => {
          Row() {
            Radio({ value: b.id, group: 'backends' })
              .checked(this.store.active !== null && this.store.active.id === b.id)
              .radioStyle({ checkedBackgroundColor: this.store.palette().accentUi })
              .onChange((on: boolean) => {
                if (on && (this.store.active === null || this.store.active.id !== b.id)) {
                  this.store.connect(b);
                }
              })
            Column() {
              Text(b.display()).fontSize(16).fontColor(this.store.palette().text)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(b.baseUrl() + (b.secret.length > 0 ? ' · 🔑' : ''))
                .fontSize(12)
                .fontColor(this.store.palette().subtle)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 6 })

            SymbolGlyph($r('sys.symbol.square_and_pencil'))
              .fontSize(20)
              .fontColor([this.store.palette().text])
              .margin({ left: 8, right: 16 })
              .onClick(() => {
                this.openEditor(b.copy(), false);
              })
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(20)
              .fontColor([this.store.palette().text])
              .onClick(() => {
                this.confirm(t('delete_backend_q', b.display()), () => {
                  this.store.deleteBackend(b);
                });
              })
          }
          .width('100%')
          .padding({ left: 12, right: 16, top: 10, bottom: 10 })
          .onClick(() => {
            if (this.store.active === null || this.store.active.id !== b.id) {
              this.store.connect(b);
            }
          })
        }, (b: Backend) => b.id + '_' + b.baseUrl() + '_' + b.label + '_' + b.secret.length)
        RowItem({
          pal: this.store.palette(), title: t('add_backend'), clickable: true, onTap: () => {
            this.openEditor(new Backend(''), true);
          }
        }) {
          SymbolGlyph($r('sys.symbol.plus')).fontSize(20).fontColor([this.store.palette().text])
        }
      }

      if (this.store.connState === 'failed') {
        Row() {
          SymbolGlyph($r('sys.symbol.exclamationmark')).fontSize(20).fontColor([this.store.palette().bad])
          Text(t('conn_failed', this.store.connError))
            .fontSize(14)
            .fontColor(this.store.palette().bad)
            .layoutWeight(1)
            .margin({ left: 10 })
          Button(t('retry'), { type: ButtonType.Capsule })
            .fontSize(14)
            .height(32)
            .fontColor(this.store.palette().text)
            .backgroundColor(this.store.palette().chip)
            .onClick(() => {
              this.store.retry();
            })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 10 })
        .borderRadius(18)
        .attributeModifier(Store.get().glass('card'))
      }

      if (this.store.connState === 'connected') {
        Group({ pal: this.store.palette(), title: t('core') }) {
          RowItem({
            pal: this.store.palette(),
            title: t('version'),
            desc: (this.store.version.length > 0 ? this.store.version : t('version_unknown')) +
              (this.store.isMeta ? ' · Meta' : '')
          })
          RowItem({ pal: this.store.palette(), title: t('proxy_mode') }) {
            SegTabs({
              pal: this.store.palette(),
              dense: isEn(),
              items: this.store.config.modes.map((m: string) => modeName(m)),
              selected: Math.max(0, this.store.config.modes.indexOf(this.store.config.mode)),
              onSelect: (i: number) => {
                this.store.setMode(this.store.config.modes[i]);
              }
            })
          }
          RowItem({ pal: this.store.palette(), title: t('core_log_level') }) {
            DropdownChip({
              pal: this.store.palette(),
              label: this.store.config.logLevel,
              options: LOG_LEVELS,
              chipWidth: 130,
              onSelect: (i: number) => {
                this.store.setCoreLogLevel(LOG_LEVELS[i]);
              }
            })
          }
        }

        Group({ pal: this.store.palette(), title: t('network') }) {
          if (this.store.unsupported.has('patch')) {
            Text(t('patch_unsupported', this.store.unsupported.get('patch') ?? 0))
              .fontSize(13)
              .fontColor(this.store.palette().bad)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          }
          SwitchRow({
            pal: this.store.palette(),
            title: t('tun_mode'),
            desc: this.store.config.tunStack.length > 0 ? t('tun_stack', this.store.config.tunStack) : '',
            checked: this.store.config.tunEnable,
            onChange: (v: boolean) => {
              this.store.setTun(v);
            }
          })
          SwitchRow({
            pal: this.store.palette(), title: t('allow_lan'), checked: this.store.config.allowLan,
            onChange: (v: boolean) => {
              this.store.setAllowLan(v);
            }
          })
          SwitchRow({
            pal: this.store.palette(), title: 'IPv6', checked: this.store.config.ipv6, onChange: (v: boolean) => {
              this.store.setIpv6(v);
            }
          })
          if (this.store.config.bindAddress.length > 0) {
            RowItem({ pal: this.store.palette(), title: t('bind_address'), desc: this.store.config.bindAddress })
          }
          ForEach(['mixed-port', 'port', 'socks-port', 'redir-port', 'tproxy-port'], (k: string) => {
            NumberRow({
              pal: this.store.palette(),
              title: k === 'mixed-port' ? t('port_mixed') : (k === 'port' ? t('port_http') :
                (k === 'socks-port' ? t('port_socks') : (k === 'redir-port' ? t('port_redir') : t('port_tproxy')))),
              value: this.portValue(k),
              placeholder: t('off'),
              zeroAsEmpty: true,
              live: false,
              onValue: (v: number) => {
                this.store.setPort(k, v);
              }
            })
          }, (k: string) => k)
        }

        Group({ pal: this.store.palette(), title: t('maintenance') }) {
          ForEach(OPS, (op: OpDef) => {
            RowItem({
              pal: this.store.palette(),
              title: t(op.title),
              desc: this.store.unsupported.has(op.key) ? t('unsupported_http', this.store.unsupported.get(op.key) ?? 0) :
                '',
              clickable: true,
              onTap: () => {
                if (op.confirm.length > 0) {
                  this.confirm(t(op.confirm), () => {
                    runOp(this.store, op.key);
                  });
                } else {
                  runOp(this.store, op.key);
                }
              }
            }) {
              SymbolGlyph(op.icon)
                .fontSize(20)
                .fontColor([this.store.unsupported.has(op.key) ? this.store.palette().subtle :
                  (op.danger ? this.store.palette().bad : this.store.palette().text)])
            }
          }, (op: OpDef) => op.key)
        }
      }
    }
    .width('100%')
    .bindSheet(this.showEditor, this.editorSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      // 1.2.3: sheet color (opaque without glass, >= 0.88 over the blur with glass); card is translucent with a wallpaper
      backgroundColor: this.store.palette().sheet,
      blurStyle: this.store.sheetBlur(),
      onDisappear: () => {
        this.showEditor = false;
      }
    })
  }
}

// ---------------- Panel page ----------------
@ComponentV2
struct PanelPage {
  private store: Store = Store.get();
  @Local showAccent: boolean = false;

  /** Accent color popup menu */
  @Builder
  accentMenu() {
    Column() {
      Text(t('accent_color'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.store.palette().text)
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 8 })
      ForEach(ACCENTS, (a: AccentDef) => {
        Row() {
          Row()
            .width(20)
            .height(20)
            .borderRadius(10)
            .backgroundColor(this.store.isDark() ? a.dark : a.light)
          Text(t(a.nameKey))
            .fontSize(16)
            .maxLines(1)
            .fontColor(this.store.accent === a.key ? this.store.palette().accent : this.store.palette().text)
            .fontWeight(this.store.accent === a.key ? FontWeight.Medium : FontWeight.Normal)
            .layoutWeight(1)
            .margin({ left: 12 })
          if (this.store.accent === a.key) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([this.store.palette().accentUi])
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.store.setAccent(a.key);
          this.showAccent = false;
        })
      }, (a: AccentDef) => a.key)
    }
    .width(isEn() ? 240 : 220)
    .padding({ bottom: 8 })
  }

  /** Color preview card */
  @Builder
  accentPreview() {
    Column({ space: 10 }) {
      Text(t('color_preview')).fontSize(13).fontColor(this.store.palette().subtle)
      Row({ space: 8 }) {
        Text(t('preview_button'))
          .fontSize(14)
          .fontColor(this.store.palette().onPrimary)
          .padding({ left: 16, right: 16, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor(this.store.palette().primary)
        Text(t('preview_tag'))
          .fontSize(14)
          .fontColor(this.store.palette().accent)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor(this.store.palette().accentSoft)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: true })
          .selectedColor(this.store.palette().accentUi)
          .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')

      Row() {
        Row()
          .width('62%')
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.store.palette().accentUi)
      }
      .width('100%')
      .height(6)
      .borderRadius(3)
      .backgroundColor(this.store.palette().chip)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 6, bottom: 12 })
  }

  glassKeys(): string[] {
    return this.store.sysMaterialSupported ? GLASS_KEYS.concat(['system']) : GLASS_KEYS;
  }

  glassLabels(): string[] {
    return tr(this.store.sysMaterialSupported ? GLASS_LABELS.concat(['glass_system']) : GLASS_LABELS);
  }

  async pickWallpaper(): Promise<void> {
    try {
      const opts = new photoAccessHelper.PhotoSelectOptions();
      opts.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opts.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const res = await picker.select(opts);
      if (res.photoUris.length > 0) {
        this.store.setWallpaperFromUri(res.photoUris[0]);
      }
    } catch (e) {
      this.store.toast(t('pick_image_failed'));
    }
  }

  build() {
    Column() {
      Group({ pal: this.store.palette(), title: t('appearance') }) {
        RowItem({ pal: this.store.palette(), title: t('theme') }) {
          SegTabs({
            pal: this.store.palette(),
            dense: isEn(),
            items: tr(THEME_LABELS),
            selected: Math.max(0, THEME_KEYS.indexOf(this.store.theme)),
            onSelect: (i: number) => {
              this.store.setTheme(THEME_KEYS[i]);
            }
          })
        }
        RowItem({
          pal: this.store.palette(),
          title: t('accent_color'),
          clickable: true,
          onTap: () => {
            this.showAccent = !this.showAccent;
          }
        }) {
          Row() {
            Row()
              .width(14)
              .height(14)
              .borderRadius(7)
              .backgroundColor(this.store.palette().accentFill)
            Text(t(this.store.accentDef().nameKey))
              .fontSize(15)
              .maxLines(1)
              .fontColor(this.store.palette().accent)
              .margin({ left: 8 })
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(14)
              .fontColor([this.store.palette().subtle])
              .margin({ left: 6 })
          }
          .bindPopup(this.showAccent, {
            builder: this.accentMenu(),
            placement: Placement.BottomRight,
            popupColor: this.store.palette().sheet,
            backgroundBlurStyle: this.store.sheetBlur(),
            enableArrow: false,
            onStateChange: (e) => {
              if (!e.isVisible) {
                this.showAccent = false;
              }
            }
          })
        }
        this.accentPreview()
      }

      Group({ pal: this.store.palette(), title: t('nav_bar') }) {
        SwitchRow({
          pal: this.store.palette(),
          title: t('auto_hide_nav'),
          desc: t('auto_hide_nav_desc'),
          checked: this.store.autoHideNav,
          onChange: (v: boolean) => {
            this.store.setAutoHideNav(v);
          }
        })
      }

      Group({ pal: this.store.palette(), title: t('glass') }) {
        SwitchRow({
          pal: this.store.palette(),
          title: t('glass'),
          desc: t('glass_desc'),
          checked: this.store.glassOn,
          onChange: (v: boolean) => {
            this.store.setGlass(v);
          }
        })
        if (this.store.glassOn) {
          // title above the segments: up to five options (longer in English) don't fit beside the title
          Column({ space: 8 }) {
            Text(t('material')).fontSize(16).fontColor(this.store.palette().text)
            SegTabs({
              pal: this.store.palette(),
              dense: isEn() || this.store.sysMaterialSupported,
              items: this.glassLabels(),
              selected: Math.max(0, this.glassKeys().indexOf(this.store.glassStyle)),
              onSelect: (i: number) => {
                this.store.glassStyle = this.glassKeys()[i];
                this.store.savePrefs();
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          SliderRow({
            pal: this.store.palette(),
            title: t('blur_strength'),
            value: this.store.glassBlur,
            min: 0,
            max: 100,
            step: 1,
            label: Math.round(this.store.glassBlur).toString(),
            onValue: (v: number) => {
              this.store.glassBlur = Math.round(v);
              this.store.savePrefs();
            }
          })
          SliderRow({
            pal: this.store.palette(),
            title: t('card_opacity'),
            value: this.store.glassAlpha,
            min: 0.1,
            max: 0.95,
            step: 0.01,
            label: Math.round(this.store.glassAlpha * 100) + '%',
            onValue: (v: number) => {
              this.store.glassAlpha = Math.round(v * 100) / 100;
              this.store.savePrefs();
            }
          })
          SwitchRow({
            pal: this.store.palette(),
            title: t('glass_rows'),
            desc: t('glass_rows_desc'),
            checked: this.store.glassRows,
            onChange: (v: boolean) => {
              this.store.glassRows = v;
              this.store.savePrefs();
            }
          })
        }
      }

      Group({ pal: this.store.palette(), title: t('light') }) {
        SwitchRow({
          pal: this.store.palette(),
          title: t('light'),
          desc: t('light_desc'),
          checked: this.store.lightOn,
          onChange: (v: boolean) => {
            this.store.setLight(v);
          }
        })
        if (this.store.lightOn) {
          SliderRow({
            pal: this.store.palette(),
            title: t('light_intensity'),
            value: this.store.lightIntensity,
            min: 0,
            max: 1,
            step: 0.01,
            label: Math.round(this.store.lightIntensity * 100) + '%',
            onValue: (v: number) => {
              this.store.lightIntensity = Math.round(v * 100) / 100;
              this.store.savePrefs();
            }
          })
          SwitchRow({
            pal: this.store.palette(),
            title: t('light_tilt'),
            desc: t('light_tilt_desc'),
            checked: this.store.lightTilt,
            onChange: (v: boolean) => {
              this.store.setLightTilt(v);
            }
          })
          SwitchRow({
            pal: this.store.palette(),
            title: t('light_glow'),
            desc: t('light_glow_desc'),
            checked: this.store.lightGlow,
            onChange: (v: boolean) => {
              this.store.lightGlow = v;
              this.store.savePrefs();
            }
          })
          SwitchRow({
            pal: this.store.palette(),
            title: t('light_sweep'),
            desc: t('light_sweep_desc'),
            checked: this.store.lightSweep,
            onChange: (v: boolean) => {
              this.store.lightSweep = v;
              this.store.savePrefs();
            }
          })
        }
        RowItem({
          pal: this.store.palette(),
          title: t('sys_material'),
          desc: this.store.sysMaterialSupported ? t('sys_material_yes') : t('sys_material_no')
        })
      }

      Group({ pal: this.store.palette(), title: t('wallpaper') }) {
        if (this.store.wallpaperPath.length > 0) {
          Image(fileUri.getUriFromPath(this.store.wallpaperPath))
            .width('100%')
            .height(160)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }
        RowItem({
          pal: this.store.palette(),
          title: this.store.wallpaperPath.length === 0 ? t('wallpaper_upload') : t('wallpaper_change'),
          desc: t('wallpaper_desc'),
          clickable: true,
          onTap: () => {
            this.pickWallpaper();
          }
        }) {
          SymbolGlyph($r('sys.symbol.picture')).fontSize(20).fontColor([this.store.palette().text])
        }
        if (this.store.wallpaperPath.length > 0 && !this.store.glassOn) {
          SliderRow({
            pal: this.store.palette(),
            title: t('card_opacity'),
            value: this.store.cardAlpha,
            min: 0.2,
            max: 1,
            step: 0.01,
            label: Math.round(this.store.cardAlpha * 100) + '%',
            onValue: (v: number) => {
              this.store.cardAlpha = v;
              this.store.savePrefs();
            }
          })
        }
        if (this.store.wallpaperPath.length > 0) {
          SliderRow({
            pal: this.store.palette(),
            title: t('wallpaper_dim'),
            value: this.store.wallpaperDim,
            min: 0,
            max: 0.7,
            step: 0.01,
            label: Math.round(this.store.wallpaperDim * 100) + '%',
            onValue: (v: number) => {
              this.store.wallpaperDim = v;
              this.store.savePrefs();
            }
          })
          SliderRow({
            pal: this.store.palette(),
            title: t('wallpaper_blur'),
            value: this.store.wallpaperBlur,
            min: 0,
            max: 30,
            step: 1,
            label: Math.round(this.store.wallpaperBlur).toString(),
            onValue: (v: number) => {
              this.store.wallpaperBlur = v;
              this.store.savePrefs();
            }
          })
          RowItem({
            pal: this.store.palette(), title: t('wallpaper_remove'), clickable: true, onTap: () => {
              this.store.clearWallpaper();
            }
          }) {
            SymbolGlyph($r('sys.symbol.trash')).fontSize(20).fontColor([this.store.palette().bad])
          }
        }
      }

    }
    .width('100%')
  }
}

// ---------------- Proxy settings ----------------
@ComponentV2
struct ProxyPrefsPage {
  private store: Store = Store.get();
  @Local url: string = '';

  aboutToAppear(): void {
    this.url = this.store.testUrl;
  }

  build() {
    Column() {
      Group({ pal: this.store.palette(), title: t('latency_test') }) {
        Column() {
          Text(t('test_url')).fontSize(12).fontColor(this.store.palette().subtle).margin({ bottom: 4 })
          TextInput({ text: this.url, placeholder: 'https://www.gstatic.com/generate_204' })
            .width('100%')
            .height(44)
            .fontSize(15)
            .fontColor(this.store.palette().text)
            .backgroundColor(this.store.palette().chip)
            .onChange((v: string) => {
              this.url = v;
              if (v.trim().length > 0) {
                this.store.testUrl = v.trim();
                this.store.savePrefs();
              }
            })
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        NumberRow({
          pal: this.store.palette(), title: t('test_timeout'), value: this.store.testTimeout, suffix: 'ms', onValue: (v: number) => {
            this.store.testTimeout = Math.max(100, v);
            this.store.savePrefs();
          }
        })
        SwitchRow({
          pal: this.store.palette(),
          title: t('group_url_first'),
          checked: this.store.groupTestUrlFirst,
          onChange: (v: boolean) => {
            this.store.groupTestUrlFirst = v;
            this.store.savePrefs();
          }
        })
        NumberRow({
          pal: this.store.palette(), title: t('low_latency'), value: this.store.lowLatency, suffix: 'ms',
          onValue: (v: number) => {
            this.store.lowLatency = v;
            this.store.savePrefs();
          }
        })
        NumberRow({
          pal: this.store.palette(), title: t('medium_latency'), value: this.store.mediumLatency, suffix: 'ms',
          onValue: (v: number) => {
            this.store.mediumLatency = v;
            this.store.savePrefs();
          }
        })
      }

      Group({ pal: this.store.palette(), title: t('group_display') }) {
        RowItem({ pal: this.store.palette(), title: t('node_sort') }) {
          SegTabs({
            pal: this.store.palette(),
            dense: isEn(),
            items: tr(SORT_LABELS),
            selected: Math.max(0, SORT_KEYS.indexOf(this.store.sortProxies)),
            onSelect: (i: number) => {
              this.store.sortProxies = SORT_KEYS[i];
              this.store.savePrefs();
            }
          })
        }
        RowItem({ pal: this.store.palette(), title: t('cards_per_row') }) {
          SegTabs({
            pal: this.store.palette(),
            items: ['1', '2', '3'],
            selected: Math.max(0, Math.min(2, this.store.proxyCols - 1)),
            onSelect: (i: number) => {
              this.store.proxyCols = i + 1;
              this.store.savePrefs();
            }
          })
        }
        SwitchRow({
          pal: this.store.palette(), title: t('hide_unavailable'), checked: this.store.hideUnavailable,
          onChange: (v: boolean) => {
            this.store.hideUnavailable = v;
            this.store.savePrefs();
          }
        })
        SwitchRow({
          pal: this.store.palette(), title: t('show_global'), checked: this.store.showGlobal,
          onChange: (v: boolean) => {
            this.store.showGlobal = v;
            this.store.savePrefs();
          }
        })
        SwitchRow({
          pal: this.store.palette(), title: t('show_hidden_groups'), desc: t('show_hidden_desc'),
          checked: this.store.showHiddenGroups, onChange: (v: boolean) => {
            this.store.showHiddenGroups = v;
            this.store.savePrefs();
          }
        })
      }
    }
    .width('100%')
  }
}

// ---------------- Connection settings ----------------
@ComponentV2
struct ConnPrefsPage {
  private store: Store = Store.get();

  build() {
    Column() {
      Group({ pal: this.store.palette(), title: t('keep_counts') }) {
        NumberRow({
          pal: this.store.palette(), title: t('closed_keep'), value: this.store.closedConnMax, suffix: t('unit_items'),
          onValue: (v: number) => {
            this.store.closedConnMax = Math.max(10, v);
            this.store.savePrefs();
          }
        })
        NumberRow({
          pal: this.store.palette(), title: t('logs_keep'), value: this.store.logMax, suffix: t('unit_items'), onValue: (v: number) => {
            this.store.logMax = Math.max(50, v);
            this.store.savePrefs();
          }
        })
      }

      Group({ pal: this.store.palette(), title: t('rules') }) {
        SwitchRow({
          pal: this.store.palette(), title: t('show_rule_hits'), desc: t('needs_core_support'), checked: this.store.showRuleHits,
          onChange: (v: boolean) => {
            this.store.showRuleHits = v;
            this.store.savePrefs();
          }
        })
      }
    }
    .width('100%')
  }
}

// ---------------- Crash logs ----------------
@ComponentV2
export struct CrashDetail {
  private store: Store = Store.get();
  @Param name: string = '';
  @Event onClose: () => void = () => {
  };

  build() {
    Column() {
      Text(t('crash_log')).fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
        .margin({ bottom: 10 })
      Scroll() {
        Scroll() {
          Text(CrashLog.read(this.name))
            .fontSize(11)
            .lineHeight(15)
            .fontFamily('monospace')
            .fontColor(this.store.palette().text)
            .copyOption(CopyOptions.LocalDevice)
        }
        .scrollable(ScrollDirection.Horizontal)
        .align(Alignment.TopStart)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .padding(10)
      .borderRadius(12)
      .backgroundColor(this.store.palette().chip)

      Row({ space: 8 }) {
        Button(t('copy'), { type: ButtonType.Capsule })
          .layoutWeight(1)
          .fontColor(this.store.palette().text)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            FileUtil.copyText(CrashLog.read(this.name));
            this.store.toast(t('copied'));
          })
        Button(t('share'), { type: ButtonType.Capsule })
          .layoutWeight(1)
          .fontColor(this.store.palette().text)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            const ctx = this.store.ctx;
            if (ctx !== null) {
              FileUtil.shareText(ctx, t('crash_share_title'), CrashLog.read(this.name)).catch(() => {
                this.store.toast(t('share_failed'));
              });
            }
          })
        Button(t('save'), { type: ButtonType.Capsule })
          .layoutWeight(1)
          .fontColor(this.store.palette().text)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            const ctx = this.store.ctx;
            if (ctx === null) {
              return;
            }
            FileUtil.saveTextAs(ctx, 'mimipanel-' + this.name, CrashLog.read(this.name)).then((n: string) => {
              if (n.length > 0) {
                this.store.toast(t('saved_file', n));
              }
            }).catch(() => {
              this.store.toast(t('save_failed'));
            });
          })
      }
      .width('100%')
      .margin({ top: 10 })

      Button(t('close_btn'), { type: ButtonType.Normal })
        .fontColor(this.store.palette().text)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onClose();
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .attributeModifier(Store.get().glass('card'))
  }
}

@ComponentV2
struct CrashLogPage {
  private store: Store = Store.get();
  @Local files: string[] = [];
  @Local open: string = '';
  @Local showDetail: boolean = false;

  aboutToAppear(): void {
    this.files = CrashLog.list();
    CrashLog.markSeen();
    this.store.crashPrompt = false;
  }

  @Builder
  detailSheet() {
    CrashDetail({
      name: this.open, onClose: () => {
        this.showDetail = false;
      }
    })
  }

  build() {
    Column() {
      Text(t('crash_intro'))
        .fontSize(14)
        .fontColor(this.store.palette().subtle)
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .attributeModifier(Store.get().glass('card'))
        .margin({ top: 16 })

      Column() {
        if (this.files.length === 0) {
          Text(t('no_crash')).fontSize(15).fontColor(this.store.palette().subtle).padding(20)
        } else {
          ForEach(this.files, (f: string, i: number) => {
            Row() {
              SymbolGlyph($r('sys.symbol.exclamationmark_magnifyingglass'))
                .fontSize(22)
                .fontColor([this.store.palette().bad])
              Column() {
                Text(CrashLog.title(f)).fontSize(16).fontColor(this.store.palette().text)
                Text(CrashLog.firstErrorLine(f)).fontSize(12).fontColor(this.store.palette().subtle).maxLines(2)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 12 })

              SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([this.store.palette().subtle])
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            .onClick(() => {
              this.open = f;
              this.showDetail = true;
            })
            if (i < this.files.length - 1) {
              Divider().color(this.store.palette().outlineVariant)
            }
          }, (f: string) => f)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .borderRadius(18)
      .attributeModifier(Store.get().glass('card'))
      .margin({ top: 12 })

      if (this.files.length > 0) {
        Button(t('clear_crash'), { type: ButtonType.Capsule })
          .width('100%')
          .margin({ top: 12 })
          .fontColor(this.store.palette().bad)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            CrashLog.clear();
            this.files = [];
            this.store.toast(t('cleared'));
          })
      }
    }
    .width('100%')
    .bindSheet(this.showDetail, this.detailSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      // 1.2.3: sheet color (opaque without glass, >= 0.88 over the blur with glass); card is translucent with a wallpaper
      backgroundColor: this.store.palette().sheet,
      blurStyle: this.store.sheetBlur(),
      onDisappear: () => {
        this.showDetail = false;
      }
    })
  }
}

// ---------------- About ----------------
@ComponentV2
struct AboutPage {
  private store: Store = Store.get();

  withdraw(): void {
    this.getUIContext().showAlertDialog({
      title: t('withdraw_title'),
      message: t('withdraw_msg'),
      autoCancel: true,
      primaryButton: {
        value: t('cancel'), action: () => {
        }
      },
      secondaryButton: {
        value: t('withdraw_exit'), fontColor: this.store.palette().bad, action: () => {
          this.store.declinePrivacy();
        }
      }
    });
  }

  @Builder
  chevron() {
    SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([this.store.palette().subtle])
  }

  build() {
    Column() {
      Group({ pal: this.store.palette(), title: '' }) {
        RowItem({ pal: this.store.palette(), title: t('app_name_label'), desc: t('app_name') })
        RowItem({ pal: this.store.palette(), title: t('version'), desc: CrashLog.versionName() })
        RowItem({ pal: this.store.palette(), title: t('developer'), desc: LEGAL_DEVELOPER + ' · ' + LEGAL_CONTACT })
        RowItem({
          pal: this.store.palette(),
          title: t('compat_api'),
          desc: t('compat_api_desc')
        })
      }

      Group({ pal: this.store.palette(), title: t('legal') }) {
        RowItem({
          pal: this.store.palette(), title: t('privacy_policy'), clickable: true, onTap: () => {
            this.store.legalDoc = 'privacy';
          }
        }) {
          this.chevron()
        }
        RowItem({
          pal: this.store.palette(), title: t('user_agreement'), clickable: true, onTap: () => {
            this.store.legalDoc = 'agreement';
          }
        }) {
          this.chevron()
        }
        RowItem({
          pal: this.store.palette(),
          title: t('withdraw'),
          desc: t('withdraw_desc'),
          descColor: this.store.palette().subtle,
          clickable: true,
          onTap: () => {
            this.withdraw();
          }
        }) {
          this.chevron()
        }
      }
    }
    .width('100%')
  }
}

// ---------------- Settings home ----------------
@ComponentV2
export struct SettingsView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(1);
  private sc: Scroller = new Scroller();
  @Local query: string = '';

  shown(): Section[] {
    const q = this.query.trim().toLowerCase();
    return SECTIONS.filter((s: Section) => q.length === 0 ||
      (bothLangs(s.title) + ' ' + bothLangs(s.desc) + ' ' + bothLangs(s.keywords)).toLowerCase().indexOf(q) >= 0);
  }

  pageTitle(): string {
    for (const s of SECTIONS) {
      if (s.key === this.store.settingsPage) {
        return t(s.title);
      }
    }
    return t('settings');
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.sc) {
        Column() {
          if (this.store.settingsPage.length === 0) {
            // The title is in the header (same row as search), so no large title here
            Blank().height(14)
            Column() {
              ForEach(this.shown(), (s: Section, i: number) => {
                Row() {
                  Stack() {
                    SymbolGlyph(s.icon).fontSize(24).fontColor([this.store.palette().text])
                  }
                  .width(48)
                  .height(48)
                  .borderRadius(12)
                  .backgroundColor(this.store.palette().chip)

                  Column() {
                    Text(t(s.title)).fontSize(18).fontColor(this.store.palette().text)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(s.key === 'lang' ? langOptionLabel(this.store.langPref()) : t(s.desc))
                      .fontSize(14).fontColor(this.store.palette().subtle).margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: 16 })

                  if (s.key === 'crash' && this.store.crashPrompt) {
                    Row().width(8).height(8).borderRadius(4.0).backgroundColor(this.store.palette().bad).margin({ right: 8 })
                  }
                  SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([this.store.palette().subtle])
                }
                .width('100%')
                .padding(18)
                .onClick(() => {
                  this.store.settingsPage = s.key;
                  this.store.expandNav();
                  this.sc.scrollEdge(Edge.Top);
                })
                if (i < this.shown().length - 1) {
                  Divider().color(this.store.palette().outlineVariant)
                }
              }, (s: Section) => s.key)
            }
            .width('100%')
            .borderRadius(18)
            .attributeModifier(Store.get().glass('card'))
          } else if (this.store.settingsPage === 'lang') {
            LanguagePage()
          } else if (this.store.settingsPage === 'backend') {
            BackendPage()
          } else if (this.store.settingsPage === 'panel') {
            PanelPage()
          } else if (this.store.settingsPage === 'proxy') {
            ProxyPrefsPage()
          } else if (this.store.settingsPage === 'conn') {
            ConnPrefsPage()
          } else if (this.store.settingsPage === 'crash') {
            CrashLogPage()
          } else if (this.store.settingsPage === 'about') {
            AboutPage()
          }
        }
        .padding({ left: 14, right: 14, top: this.headerH, bottom: this.bottomPad + 14 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      // 1.2.2: bounce at top/bottom even when the (filtered) list or a short sub-page fits on screen
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onDidScroll((x: number, y: number, st: ScrollState) => {
        this.store.navScroll(this.sc, y, st);
      })

      GlassHeader({
        onHeight: (h: number) => {
          this.headerH = h;
        }
      }) {
        if (this.store.settingsPage.length > 0) {
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(20)
              .fontColor([this.store.palette().text])
              .padding({ left: 2, right: 10, top: 5, bottom: 5 })
              .onClick(() => {
                this.store.settingsPage = '';
                this.store.expandNav();
                this.sc.scrollEdge(Edge.Top);
              })
            HeaderStatus({
              pal: this.store.palette(),
              title: this.pageTitle(),
              connState: this.store.connState,
              address: this.store.active !== null ? this.store.active.host + ':' + this.store.active.port : t('not_connected'),
              tag: ''
            })
              .layoutWeight(1)
          }
          .width('100%')
        } else {
          // Settings home: title and search share one header row
          Row() {
            Text(t('settings')).fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
            SearchBox({
              pal: this.store.palette(),
              dense: true,
              value: this.query,
              placeholder: t('search_settings'),
              onChange: (v: string) => {
                this.query = v;
              }
            })
              .layoutWeight(1)
              .margin({ left: 12 })
          }
          .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.store.palette().bg)
  }
}
