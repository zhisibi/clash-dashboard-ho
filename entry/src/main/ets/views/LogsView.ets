import { Store } from '../common/Store';
import { PullRefresh } from '../components/PullRefresh';
import { GlassHeader, headerGuess } from '../components/GlassHeader';
import { LogEntry } from '../common/Models';
import { fmtClock, fmtStamp, pad2, safeRegex, textMatch } from '../common/Format';
import { FileUtil } from '../common/FileUtil';
import { Palette } from '../common/Theme';
import { DropdownChip, EmptyCard, RoundIconButton, SearchBox } from '../components/Widgets';
import { t } from '../common/I18n';

const LEVELS: string[] = ['debug', 'info', 'warning', 'error', 'silent'];
const TYPE_KEYS: string[] = ['', 'debug', 'info', 'warning', 'error'];
function typeLabels(): string[] {
  return [t('all'), 'DEBUG', 'INFO', 'WARNING', 'ERROR'];
}

export function levelColor(type: string, p: Palette): string {
  const lv = type.toLowerCase();
  if (lv === 'info') {
    return p.info;
  }
  if (lv === 'warning' || lv === 'warn') {
    return p.warn;
  }
  if (lv === 'error') {
    return p.bad;
  }
  return p.subtle;
}

function logLine(l: LogEntry): string {
  return fmtClock(l.time) + ' [' + l.type + '] ' + l.payload;
}

// Frozen while not the current page (hidden TabContent); latest data applies on return, page state is kept
@ComponentV2({ freezeWhenInactive: true })
export struct LogsView {
  private store: Store = Store.get();
  @Param bottomPad: number = 96;
  @Local headerH: number = headerGuess(2);
  private sc: Scroller = new Scroller();
  @Local query: string = '';
  @Local typeFilter: string = '';
  @Local newestFirst: boolean = true;

  list(): LogEntry[] {
    const re = safeRegex(this.query);
    const f = this.store.logs.filter((l: LogEntry) =>
    (this.typeFilter.length === 0 || l.type.toLowerCase() === this.typeFilter) &&
    textMatch(re, this.query, l.payload));
    return this.newestFirst ? f.reverse() : f;
  }

  async exportLogs(): Promise<void> {
    const ctx = this.store.ctx;
    if (ctx === null) {
      return;
    }
    try {
      const text = this.list().map((l: LogEntry) => logLine(l)).join('\n');
      const name = await FileUtil.saveTextAs(ctx, 'mimi-logs-' + fmtStamp(Date.now()) + '.txt', text);
      if (name.length > 0) {
        this.store.toast(t('saved_name', name));
      }
    } catch (e) {
      this.store.toast(t('export_failed', (e as Error).message));
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      PullRefresh({ topInset: this.headerH, page: 'logs' }) {
        if (this.list().length === 0) {
          // 1.2.2: empty state sits in a full-size Scroll so it still bounces (and pulls to refresh)
          Scroll() {
            Column() {
              EmptyCard({ pal: this.store.palette(), text: this.store.logLevel === 'silent' ? t('log_silent') : t('log_waiting') })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: this.headerH + 14 })
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        } else {
          List({ space: 10, scroller: this.sc }) {
            Repeat<LogEntry>(this.list())
              .each((ri: RepeatItem<LogEntry>) => {
                ListItem() {
                  Column() {
                    Row() {
                      Text(pad2(ri.item.seq % 100)).fontSize(13).fontColor(this.store.palette().subtle)
                      Text(ri.item.type.toUpperCase())
                        .fontSize(13)
                        .fontColor(levelColor(ri.item.type, this.store.palette()))
                        .margin({ left: 16 })
                      Blank()
                      Text(fmtClock(ri.item.time)).fontSize(13).fontColor(this.store.palette().subtle)
                    }
                    .width('100%')

                    Text(ri.item.payload)
                      .fontSize(15)
                      .lineHeight(21)
                      .fontColor(this.store.palette().text)
                      .copyOption(CopyOptions.LocalDevice)
                      .width('100%')
                      .margin({ top: 4 })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .borderRadius(18)
                  .attributeModifier(Store.get().glass('row'))
                }
              })
              .key((l: LogEntry) => l.seq.toString())
              .virtualScroll()
          }
          .padding({ left: 14, right: 14, top: this.headerH + 14, bottom: this.bottomPad + 14 })
          .width('100%')
          .height('100%')
          .clipContent(ContentClipMode.BOUNDARY)
          .onDidScroll((d: number, st: ScrollState) => {
            this.store.navScroll(this.sc, d, st);
          })
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
          .cachedCount(4)
        }
      }

      GlassHeader({
        onHeight: (h: number) => {
          this.headerH = h;
        }
      }) {
        Column({ space: 6 }) {
          Row({ space: 6 }) {
            DropdownChip({
              pal: this.store.palette(), dense: true,
              label: this.store.logLevel,
              options: LEVELS,
              chipWidth: 130,
              onSelect: (i: number) => {
                this.store.setLevel(LEVELS[i]);
              }
            })
            Blank()
            RoundIconButton({
              pal: this.store.palette(), dense: true,
              icon: this.newestFirst ? $r('sys.symbol.arrow_up_to_line') : $r('sys.symbol.arrow_down_to_line'),
              onTap: () => {
                this.newestFirst = !this.newestFirst;
              }
            })
            RoundIconButton({
              pal: this.store.palette(), dense: true, icon: $r('sys.symbol.square_and_arrow_down'), onTap: () => {
                this.exportLogs();
              }
            })
            RoundIconButton({
              pal: this.store.palette(), dense: true, icon: $r('sys.symbol.square_on_square_fill'), onTap: () => {
                const l = this.list();
                FileUtil.copyText(l.map((x: LogEntry) => logLine(x)).join('\n'));
                this.store.toast(t('copied_logs', l.length));
              }
            })
            RoundIconButton({
              pal: this.store.palette(), dense: true,
              icon: this.store.logsPaused ? $r('sys.symbol.play') : $r('sys.symbol.pause'),
              active: this.store.logsPaused,
              onTap: () => {
                this.store.logsPaused = !this.store.logsPaused;
              }
            })
            RoundIconButton({
              pal: this.store.palette(), dense: true, icon: $r('sys.symbol.xmark'), onTap: () => {
                this.store.clearLogs();
              }
            })
          }
          .width('100%')

          Row({ space: 6 }) {
            DropdownChip({
              pal: this.store.palette(), dense: true,
              label: typeLabels()[Math.max(0, TYPE_KEYS.indexOf(this.typeFilter))],
              options: typeLabels(),
              chipWidth: 140,
              onSelect: (i: number) => {
                this.typeFilter = TYPE_KEYS[i];
              }
            })
            SearchBox({
              pal: this.store.palette(), dense: true,
              value: this.query,
              placeholder: t('search_regex'),
              onChange: (v: string) => {
                this.query = v;
              }
            })
              .layoutWeight(1)
          }
          .width('100%')
        }
        .width('100%')

      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.store.palette().bg)
  }
}
