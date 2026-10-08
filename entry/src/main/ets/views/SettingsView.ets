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

const SECTIONS: Section[] = [
  new Section('backend', '后端', '当前后端、内核运维与网络监听', $r('sys.symbol.externaldrive'),
    '后端 内核 模式 tun 局域网 端口 重启 更新 geo dns fakeip 重载 配置 密钥'),
  new Section('panel', '面板', '主题、主题色、导航栏、毛玻璃、沉浸光感、壁纸', $r('sys.symbol.house'),
    '导航栏 底栏 自动收起 隐藏 主题 主题色 颜色 配色 深色 浅色 壁纸 背景 毛玻璃 玻璃 模糊 磨砂 透明 材质 光感 沉浸 沉浸光感 光效 高光 流光 光晕 重力 陀螺仪 倾斜'),
  new Section('proxy', '代理', '测速、代理组展示', $r('sys.symbol.paperplane'), '测速 延迟 url 超时 排序 隐藏 卡片 global'),
  new Section('conn', '连接', '连接与日志保留数量', $r('sys.symbol.arrow_left_arrow_right'), '连接 日志 保留 数量 规则 命中'),
  new Section('crash', '闪退日志', '查看、复制、分享应用崩溃记录', $r('sys.symbol.exclamationmark_magnifyingglass'),
    '闪退 崩溃 crash 日志 反馈 bug'),
  new Section('about', '关于', '版本、开发者、隐私政策与用户协议', $r('sys.symbol.info_circle'),
    '关于 版本 开发者 隐私 隐私政策 用户协议 协议 撤回 同意')
];

const LOG_LEVELS: string[] = ['debug', 'info', 'warning', 'error', 'silent'];
const THEME_KEYS: string[] = ['system', 'light', 'dark'];
const THEME_LABELS: string[] = ['跟随系统', '浅色', '深色'];
const GLASS_KEYS: string[] = ['custom', 'thin', 'regular', 'thick'];
const GLASS_LABELS: string[] = ['自定义', '薄', '常规', '厚'];
const SORT_KEYS: string[] = ['default', 'latency', 'name'];
const SORT_LABELS: string[] = ['默认', '延迟', '名称'];

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

const OPS: OpDef[] = [
  new OpDef('重载配置文件', '重载配置', $r('sys.symbol.arrow_counterclockwise'), false, ''),
  new OpDef('更新 GEO 数据库', '更新 GEO', $r('sys.symbol.paperplane'), false, ''),
  new OpDef('清空 FakeIP 缓存', '清空 FakeIP', $r('sys.symbol.trash'), false, ''),
  new OpDef('清空 DNS 缓存', '清空 DNS 缓存', $r('sys.symbol.trash'), false, ''),
  new OpDef('更新内核', '更新内核', $r('sys.symbol.square_and_arrow_down'), false, '确定升级内核？升级后内核会自动重启。'),
  new OpDef('重启内核', '重启内核', $r('sys.symbol.power'), true, '确定重启内核？')
];

function runOp(store: Store, key: string): void {
  switch (key) {
    case '重载配置':
      store.coreAction(key, (a: CoreApi) => a.reloadConfigs());
      break;
    case '更新 GEO':
      store.coreAction(key, (a: CoreApi) => a.upgradeGeo());
      break;
    case '清空 FakeIP':
      store.coreAction(key, (a: CoreApi) => a.flushFakeIp());
      break;
    case '清空 DNS 缓存':
      store.coreAction(key, (a: CoreApi) => a.flushDns());
      break;
    case '更新内核':
      store.coreAction(key, (a: CoreApi) => a.upgradeCore());
      break;
    case '重启内核':
      store.coreAction(key, (a: CoreApi) => a.restart());
      break;
    default:
      break;
  }
}

// ---------------- 后端页 ----------------
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
        value: '取消', action: () => {
        }
      },
      secondaryButton: {
        value: '确定', fontColor: this.store.palette().bad, action: () => {
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
      Text(this.editingNew ? '添加后端' : '编辑后端')
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
      Group({ pal: this.store.palette(), title: '后端列表' }) {
        ForEach(this.store.backends, (b: Backend) => {
          Row() {
            Radio({ value: b.id, group: 'backends' })
              .checked(this.store.active !== null && this.store.active.id === b.id)
              .radioStyle({ checkedBackgroundColor: this.store.palette().accent })
              .onChange((on: boolean) => {
                if (on && (this.store.active === null || this.store.active.id !== b.id)) {
                  this.store.connect(b);
                }
              })
            Column() {
              Text(b.display()).fontSize(16).fontColor(this.store.palette().text)
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
                this.confirm('删除后端 ' + b.display() + '？', () => {
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
          pal: this.store.palette(), title: '添加后端', clickable: true, onTap: () => {
            this.openEditor(new Backend(''), true);
          }
        }) {
          SymbolGlyph($r('sys.symbol.plus')).fontSize(20).fontColor([this.store.palette().text])
        }
      }

      if (this.store.connState === 'failed') {
        Row() {
          SymbolGlyph($r('sys.symbol.exclamationmark')).fontSize(20).fontColor([this.store.palette().bad])
          Text('连接失败：' + this.store.connError)
            .fontSize(14)
            .fontColor(this.store.palette().bad)
            .layoutWeight(1)
            .margin({ left: 10 })
          Button('重试', { type: ButtonType.Capsule })
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
        Group({ pal: this.store.palette(), title: '内核' }) {
          RowItem({
            pal: this.store.palette(),
            title: '版本',
            desc: (this.store.version.length > 0 ? this.store.version : '未知（客户端未提供版本号）') +
              (this.store.isMeta ? ' · Meta' : '')
          })
          RowItem({ pal: this.store.palette(), title: '代理模式' }) {
            SegTabs({
              pal: this.store.palette(),
              items: this.store.config.modes.map((m: string) => modeName(m)),
              selected: Math.max(0, this.store.config.modes.indexOf(this.store.config.mode)),
              onSelect: (i: number) => {
                this.store.setMode(this.store.config.modes[i]);
              }
            })
          }
          RowItem({ pal: this.store.palette(), title: '内核日志级别' }) {
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

        Group({ pal: this.store.palette(), title: '网络' }) {
          if (this.store.unsupported.has('patch')) {
            Text('当前后端不允许修改配置 (HTTP ' + this.store.unsupported.get('patch') +
              ')。模式、TUN、端口等需要在代理客户端 App 里修改。')
              .fontSize(13)
              .fontColor(this.store.palette().bad)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          }
          SwitchRow({
            pal: this.store.palette(),
            title: 'TUN 模式',
            desc: this.store.config.tunStack.length > 0 ? '栈：' + this.store.config.tunStack : '',
            checked: this.store.config.tunEnable,
            onChange: (v: boolean) => {
              this.store.setTun(v);
            }
          })
          SwitchRow({
            pal: this.store.palette(), title: '允许局域网连接', checked: this.store.config.allowLan,
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
            RowItem({ pal: this.store.palette(), title: '绑定地址', desc: this.store.config.bindAddress })
          }
          ForEach(['mixed-port', 'port', 'socks-port', 'redir-port', 'tproxy-port'], (k: string) => {
            NumberRow({
              pal: this.store.palette(),
              title: k === 'mixed-port' ? '混合端口' : (k === 'port' ? 'HTTP 端口' : (k === 'socks-port' ? 'SOCKS 端口' :
                (k === 'redir-port' ? '透明代理 Redir' : 'TProxy 端口'))),
              value: this.portValue(k),
              placeholder: '关闭',
              zeroAsEmpty: true,
              live: false,
              onValue: (v: number) => {
                this.store.setPort(k, v);
              }
            })
          }, (k: string) => k)
        }

        Group({ pal: this.store.palette(), title: '运维' }) {
          ForEach(OPS, (op: OpDef) => {
            RowItem({
              pal: this.store.palette(),
              title: op.title,
              desc: this.store.unsupported.has(op.key) ? '当前后端不支持 (HTTP ' + this.store.unsupported.get(op.key) + ')' :
                '',
              clickable: true,
              onTap: () => {
                if (op.confirm.length > 0) {
                  this.confirm(op.confirm, () => {
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
      backgroundColor: this.store.palette().card,
      blurStyle: this.store.sheetBlur(),
      onDisappear: () => {
        this.showEditor = false;
      }
    })
  }
}

// ---------------- 面板页 ----------------
@ComponentV2
struct PanelPage {
  private store: Store = Store.get();
  @Local showAccent: boolean = false;

  /** 主题色弹出菜单 */
  @Builder
  accentMenu() {
    Column() {
      Text('主题色')
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
          Text(a.name)
            .fontSize(16)
            .fontColor(this.store.accent === a.key ? this.store.palette().accent : this.store.palette().text)
            .fontWeight(this.store.accent === a.key ? FontWeight.Medium : FontWeight.Normal)
            .layoutWeight(1)
            .margin({ left: 12 })
          if (this.store.accent === a.key) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([this.store.palette().accent])
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
    .width(220)
    .padding({ bottom: 8 })
  }

  /** 颜色预览卡片 */
  @Builder
  accentPreview() {
    Column({ space: 10 }) {
      Text('颜色预览').fontSize(13).fontColor(this.store.palette().subtle)
      Row({ space: 8 }) {
        Text('按钮')
          .fontSize(14)
          .fontColor(this.store.palette().onAccent)
          .padding({ left: 16, right: 16, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor(this.store.palette().accent)
        Text('标签')
          .fontSize(14)
          .fontColor(this.store.palette().accent)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor(this.store.palette().accentSoft)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: true })
          .selectedColor(this.store.palette().accent)
          .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')

      Row() {
        Row()
          .width('62%')
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.store.palette().accent)
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
    return this.store.sysMaterialSupported ? GLASS_LABELS.concat(['系统']) : GLASS_LABELS;
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
      this.store.toast('选择图片失败');
    }
  }

  build() {
    Column() {
      Group({ pal: this.store.palette(), title: '外观' }) {
        RowItem({ pal: this.store.palette(), title: '主题' }) {
          SegTabs({
            pal: this.store.palette(),
            items: THEME_LABELS,
            selected: Math.max(0, THEME_KEYS.indexOf(this.store.theme)),
            onSelect: (i: number) => {
              this.store.setTheme(THEME_KEYS[i]);
            }
          })
        }
        RowItem({
          pal: this.store.palette(),
          title: '主题色',
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
              .backgroundColor(this.store.palette().accent)
            Text(this.store.accentDef().name)
              .fontSize(15)
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
            popupColor: this.store.palette().card,
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

      Group({ pal: this.store.palette(), title: '导航栏' }) {
        SwitchRow({
          pal: this.store.palette(),
          title: '自动收起导航栏',
          desc: '向下浏览时底部导航栏收起为左下角的圆形按钮，往回滑动或点按圆形按钮即可展开',
          checked: this.store.autoHideNav,
          onChange: (v: boolean) => {
            this.store.setAutoHideNav(v);
          }
        })
      }

      Group({ pal: this.store.palette(), title: '毛玻璃效果' }) {
        SwitchRow({
          pal: this.store.palette(),
          title: '毛玻璃效果',
          desc: '卡片、顶栏、悬浮底栏与弹窗使用半透明模糊材质；无壁纸时自动铺一层柔和渐变背景',
          checked: this.store.glassOn,
          onChange: (v: boolean) => {
            this.store.setGlass(v);
          }
        })
        if (this.store.glassOn) {
          RowItem({ pal: this.store.palette(), title: '材质' }) {
            SegTabs({
              pal: this.store.palette(),
              items: this.glassLabels(),
              selected: Math.max(0, this.glassKeys().indexOf(this.store.glassStyle)),
              onSelect: (i: number) => {
                this.store.glassStyle = this.glassKeys()[i];
                this.store.savePrefs();
              }
            })
          }
          SliderRow({
            pal: this.store.palette(),
            title: '模糊强度',
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
            title: '卡片不透明度',
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
            title: '列表项也模糊',
            desc: '连接、日志、规则等长列表逐项模糊，更通透但更耗电；关闭时列表项仅半透明',
            checked: this.store.glassRows,
            onChange: (v: boolean) => {
              this.store.glassRows = v;
              this.store.savePrefs();
            }
          })
        }
      }

      Group({ pal: this.store.palette(), title: '沉浸光感' }) {
        SwitchRow({
          pal: this.store.palette(),
          title: '沉浸光感',
          desc: '玻璃边缘高光、斜向柔光与主题色光晕，与毛玻璃搭配效果最佳',
          checked: this.store.lightOn,
          onChange: (v: boolean) => {
            this.store.setLight(v);
          }
        })
        if (this.store.lightOn) {
          SliderRow({
            pal: this.store.palette(),
            title: '光感强度',
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
            title: '跟随重力感应',
            desc: '倾斜手机时高光方向随之变化（低频采样，退到后台自动停止）',
            checked: this.store.lightTilt,
            onChange: (v: boolean) => {
              this.store.setLightTilt(v);
            }
          })
          SwitchRow({
            pal: this.store.palette(),
            title: '主题色光晕',
            desc: '卡片与底栏周围一圈柔和的主题色光',
            checked: this.store.lightGlow,
            onChange: (v: boolean) => {
              this.store.lightGlow = v;
              this.store.savePrefs();
            }
          })
          SwitchRow({
            pal: this.store.palette(),
            title: '流光扫过',
            desc: '切换底部页签时，一道光从底栏上扫过',
            checked: this.store.lightSweep,
            onChange: (v: boolean) => {
              this.store.lightSweep = v;
              this.store.savePrefs();
            }
          })
        }
        RowItem({
          pal: this.store.palette(),
          title: '系统沉浸光感材质',
          desc: this.store.sysMaterialSupported ?
            '本机支持（API 26+）。在毛玻璃“材质”中选择“系统”即可使用系统原生材质与光感反馈' :
            '本机不支持（需 HarmonyOS API 26 且设备支持），已使用应用内自绘光感效果'
        })
      }

      Group({ pal: this.store.palette(), title: '壁纸' }) {
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
          title: this.store.wallpaperPath.length === 0 ? '上传壁纸' : '更换壁纸',
          desc: '从相册选择一张图片作为面板背景',
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
            title: '卡片不透明度',
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
            title: '壁纸暗化',
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
            title: '壁纸模糊',
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
            pal: this.store.palette(), title: '移除壁纸', clickable: true, onTap: () => {
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

// ---------------- 代理设置页 ----------------
@ComponentV2
struct ProxyPrefsPage {
  private store: Store = Store.get();
  @Local url: string = '';

  aboutToAppear(): void {
    this.url = this.store.testUrl;
  }

  build() {
    Column() {
      Group({ pal: this.store.palette(), title: '测速' }) {
        Column() {
          Text('测速 URL').fontSize(12).fontColor(this.store.palette().subtle).margin({ bottom: 4 })
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
          pal: this.store.palette(), title: '超时', value: this.store.testTimeout, suffix: 'ms', onValue: (v: number) => {
            this.store.testTimeout = Math.max(100, v);
            this.store.savePrefs();
          }
        })
        SwitchRow({
          pal: this.store.palette(),
          title: '优先使用代理组自带的测速 URL',
          checked: this.store.groupTestUrlFirst,
          onChange: (v: boolean) => {
            this.store.groupTestUrlFirst = v;
            this.store.savePrefs();
          }
        })
        NumberRow({
          pal: this.store.palette(), title: '低延迟阈值（绿色）', value: this.store.lowLatency, suffix: 'ms',
          onValue: (v: number) => {
            this.store.lowLatency = v;
            this.store.savePrefs();
          }
        })
        NumberRow({
          pal: this.store.palette(), title: '中延迟阈值（黄色）', value: this.store.mediumLatency, suffix: 'ms',
          onValue: (v: number) => {
            this.store.mediumLatency = v;
            this.store.savePrefs();
          }
        })
      }

      Group({ pal: this.store.palette(), title: '代理组展示' }) {
        RowItem({ pal: this.store.palette(), title: '节点排序' }) {
          SegTabs({
            pal: this.store.palette(),
            items: SORT_LABELS,
            selected: Math.max(0, SORT_KEYS.indexOf(this.store.sortProxies)),
            onSelect: (i: number) => {
              this.store.sortProxies = SORT_KEYS[i];
              this.store.savePrefs();
            }
          })
        }
        RowItem({ pal: this.store.palette(), title: '每行卡片数' }) {
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
          pal: this.store.palette(), title: '隐藏不可用节点', checked: this.store.hideUnavailable,
          onChange: (v: boolean) => {
            this.store.hideUnavailable = v;
            this.store.savePrefs();
          }
        })
        SwitchRow({
          pal: this.store.palette(), title: '显示 GLOBAL 代理组', checked: this.store.showGlobal,
          onChange: (v: boolean) => {
            this.store.showGlobal = v;
            this.store.savePrefs();
          }
        })
        SwitchRow({
          pal: this.store.palette(), title: '显示隐藏的代理组', desc: '配置中 hidden: true 的代理组',
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

// ---------------- 连接设置页 ----------------
@ComponentV2
struct ConnPrefsPage {
  private store: Store = Store.get();

  build() {
    Column() {
      Group({ pal: this.store.palette(), title: '保留数量' }) {
        NumberRow({
          pal: this.store.palette(), title: '已关闭连接保留', value: this.store.closedConnMax, suffix: '条',
          onValue: (v: number) => {
            this.store.closedConnMax = Math.max(10, v);
            this.store.savePrefs();
          }
        })
        NumberRow({
          pal: this.store.palette(), title: '日志保留', value: this.store.logMax, suffix: '条', onValue: (v: number) => {
            this.store.logMax = Math.max(50, v);
            this.store.savePrefs();
          }
        })
      }

      Group({ pal: this.store.palette(), title: '规则' }) {
        SwitchRow({
          pal: this.store.palette(), title: '显示规则命中次数', desc: '需要内核支持', checked: this.store.showRuleHits,
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

// ---------------- 闪退日志 ----------------
@ComponentV2
export struct CrashDetail {
  private store: Store = Store.get();
  @Param name: string = '';
  @Event onClose: () => void = () => {
  };

  build() {
    Column() {
      Text('闪退日志').fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
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
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .padding(10)
      .borderRadius(12)
      .backgroundColor(this.store.palette().chip)

      Row({ space: 8 }) {
        Button('复制', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .fontColor(this.store.palette().text)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            FileUtil.copyText(CrashLog.read(this.name));
            this.store.toast('已复制');
          })
        Button('分享', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .fontColor(this.store.palette().text)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            const ctx = this.store.ctx;
            if (ctx !== null) {
              FileUtil.shareText(ctx, '咪咪面板 闪退日志', CrashLog.read(this.name)).catch(() => {
                this.store.toast('分享失败');
              });
            }
          })
        Button('保存', { type: ButtonType.Capsule })
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
                this.store.toast('已保存 ' + n);
              }
            }).catch(() => {
              this.store.toast('保存失败');
            });
          })
      }
      .width('100%')
      .margin({ top: 10 })

      Button('关闭', { type: ButtonType.Normal })
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
      Text('应用闪退时会自动记录错误堆栈。打开一条日志后可以复制、分享或保存，发给开发者排查。')
        .fontSize(14)
        .fontColor(this.store.palette().subtle)
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .attributeModifier(Store.get().glass('card'))
        .margin({ top: 16 })

      Column() {
        if (this.files.length === 0) {
          Text('暂无闪退记录').fontSize(15).fontColor(this.store.palette().subtle).padding(20)
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
        Button('清空闪退日志', { type: ButtonType.Capsule })
          .width('100%')
          .margin({ top: 12 })
          .fontColor(this.store.palette().bad)
          .backgroundColor(this.store.palette().chip)
          .onClick(() => {
            CrashLog.clear();
            this.files = [];
            this.store.toast('已清空');
          })
      }
    }
    .width('100%')
    .bindSheet(this.showDetail, this.detailSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      backgroundColor: this.store.palette().card,
      blurStyle: this.store.sheetBlur(),
      onDisappear: () => {
        this.showDetail = false;
      }
    })
  }
}

// ---------------- 关于 ----------------
@ComponentV2
struct AboutPage {
  private store: Store = Store.get();

  withdraw(): void {
    this.getUIContext().showAlertDialog({
      title: '撤回隐私政策同意',
      message: '撤回后将断开后端并退出应用，下次打开需要重新同意才能使用。已保存的后端与设置仍保留在本机，如需删除请卸载应用。',
      autoCancel: true,
      primaryButton: {
        value: '取消', action: () => {
        }
      },
      secondaryButton: {
        value: '撤回并退出', fontColor: this.store.palette().bad, action: () => {
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
        RowItem({ pal: this.store.palette(), title: '应用名称', desc: '咪咪面板' })
        RowItem({ pal: this.store.palette(), title: '版本', desc: CrashLog.versionName() })
        RowItem({ pal: this.store.palette(), title: '开发者', desc: LEGAL_DEVELOPER + ' · ' + LEGAL_CONTACT })
        RowItem({
          pal: this.store.palette(),
          title: '兼容接口',
          desc: '与 mihomo 兼容的外部控制器（external-controller）RESTful API。本应用不包含代理内核，也不提供代理服务。'
        })
      }

      Group({ pal: this.store.palette(), title: '协议' }) {
        RowItem({
          pal: this.store.palette(), title: '隐私政策', clickable: true, onTap: () => {
            this.store.legalDoc = 'privacy';
          }
        }) {
          this.chevron()
        }
        RowItem({
          pal: this.store.palette(), title: '用户协议', clickable: true, onTap: () => {
            this.store.legalDoc = 'agreement';
          }
        }) {
          this.chevron()
        }
        RowItem({
          pal: this.store.palette(),
          title: '撤回隐私政策同意',
          desc: '撤回后应用将退出',
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

// ---------------- 设置主页 ----------------
@ComponentV2
export struct SettingsView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(1);
  private sc: Scroller = new Scroller();
  @Local query: string = '';

  shown(): Section[] {
    const q = this.query.trim().toLowerCase();
    return SECTIONS.filter((s: Section) => q.length === 0 || (s.title + s.desc + s.keywords).toLowerCase().indexOf(q) >= 0);
  }

  pageTitle(): string {
    for (const s of SECTIONS) {
      if (s.key === this.store.settingsPage) {
        return s.title;
      }
    }
    return '设置';
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.sc) {
        Column() {
          if (this.store.settingsPage.length === 0) {
            // 标题已在顶栏（与搜索框同一行），这里不再重复大标题
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
                    Text(s.title).fontSize(18).fontColor(this.store.palette().text)
                    Text(s.desc).fontSize(14).fontColor(this.store.palette().subtle).margin({ top: 4 })
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
              address: this.store.active !== null ? this.store.active.host + ':' + this.store.active.port : '未连接',
              tag: ''
            })
              .layoutWeight(1)
          }
          .width('100%')
        } else {
          // 设置主页：标题与搜索框放在同一行，顶栏只占一行
          Row() {
            Text('设置').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.store.palette().text)
            SearchBox({
              pal: this.store.palette(),
              dense: true,
              value: this.query,
              placeholder: '搜索设置',
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
