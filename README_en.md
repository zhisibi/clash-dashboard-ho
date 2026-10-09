# Mimi Panel (HarmonyOS)

English · [简体中文](README.md)

A native HarmonyOS control panel written in **ArkTS + ArkUI (Stage model)** for the `external-controller` RESTful API of mihomo-compatible proxy cores. The UI follows Zashboard.

> The app **does not contain a proxy core** and never starts a proxy service. It needs a backend that is already running (a core on your router or a LAN computer, or the external controller exposed by a proxy client on the phone).

| Item | Value |
| --- | --- |
| App name | Mimi Panel (咪咪面板) |
| bundleName | `com.zhisibi.mimipanel` |
| Version | 1.2.4 (versionCode 1020400) |
| Minimum OS | HarmonyOS 6.0 (`compatibleSdkVersion: "6.0.0(20)"`) |
| Target OS | HarmonyOS 7 (`targetSdkVersion: "26.0.0"`, API 26) |
| Tooling | DevEco Studio 26.0.0 Release (26.0.0.821) or the matching Command Line Tools |
| UI languages | Simplified Chinese and English (Settings → Language, can follow the system) |

## What's new in 1.2.4
- Fixed the privacy policy and user agreement pages not scrolling and their back button not responding (the touch blocking added in 1.2.3 also blocked the page's own content).
- The developer shown in About, the privacy policy and the user agreement is now Zhang Shibo; both documents are dated October 9, 2026.

## What's new in 1.2.3

- Proxy-group sheet (subtitle "Selector · 5 nodes · now …"): the ⚡ latency-test button no longer sits under the system close button (X). The sheet hides the system close and shows ⚡ Test and ✕ Close side by side, each with a 48 vp touch target; dragging the sheet down still closes it. The connection-details sheet's **Close** button gets the same fix.
- Node cards: the latency pill (e.g. 96, 241) no longer covers the node's current selection. The chip row takes the width left of the pill and the last chip ends in an ellipsis instead of running under it (Chinese and English UI).
- With frosted glass (or a wallpaper) on, the Privacy Policy / User Agreement opened from Settings → About was see-through: the About page and the bottom bar showed through the text. These pages now draw an opaque page-color base first, with the glass gradient or a strongly blurred, dimmed wallpaper only on top of it; they fully cover the bottom bar and block touches beneath. The back button has a 48 vp touch target.
- Same class of problem fixed elsewhere: the consent screen shown again after withdrawing consent no longer has a black background when a wallpaper is set; the backend editor, crash-log sheet and accent-color popup are no longer translucent with a wallpaper and glass off; with glass on every sheet's base is at least 88% opaque over the system blur, so its text never mixes with the page beneath.

## What's new in 1.2.2

- Fixes the AppGallery pre-listing check "scrolling to a boundary should give feedback" (flagged on the Settings page of a foldable, folded and unfolded):
  - Swiping between pages now bounces past the first page (Overview) and the last page (Settings).
  - Every scrollable area (all six pages, every Settings sub-page, the consent and setup screens, the privacy policy / user agreement, the backend editor, the proxy-group sheet, connection details and crash logs) bounces at the top and bottom, even when the content is shorter than the screen.
  - Empty, loading and error states on Proxies, Connections, Logs and Rules are now scrollable too, so they bounce and still support pull-to-refresh.

## What's new in 1.2.1

- Fixes the AppGallery pre-listing color-contrast check: **Save & Connect** and **Test Connection** are never shown in a faded disabled state; they validate on tap, show a toast and highlight the missing field.
- Secondary text, labels, placeholders, status colors and all 7 accent presets (light and dark) now meet WCAG contrast (text 4.5:1, icons 3:1), checked by `scripts/check-contrast.py`.

## What's new in 1.2.0

- **English UI.** Settings → **Language** offers Follow system (default), 简体中文 and English. The choice is saved locally and applies **immediately, without a restart**.
- Every screen is translated: Overview, Proxies, Rules / Rule Sets, Connections, Logs, all Settings pages, About, the backend form, the first-launch consent screen, crash logs, toasts, dialogs, empty and error states, units and relative times, accent color names, and the glass / light settings.
- English versions of the [Privacy Policy](docs/privacy_en.md) and [User Agreement](docs/agreement_en.md), shown in the app when the UI is in English.
- Layout tuned for longer English labels (short bottom-nav labels, auto-shrinking text, ellipsis instead of overlap).

See the Chinese README for the full changelog.

## Features

| Page | Features |
| --- | --- |
| Overview | Live up/down speed, totals, active connections, memory, speed and memory charts, top hosts, quick mode switch |
| Proxies | Group cards (1–3 per row), node selection, group / node latency tests, latency colors, sorting, regex search, hide unavailable nodes, GLOBAL and hidden groups, unpin, proxy providers (usage / expiry, update, health check) |
| Rules | Rule list (virtual scrolling) with hit counts, enable / disable single rules, rule set updates, proxy chain and latency |
| Connections | Active / closed / all, regex search, source IP filter, 11 sort fields, compact mode, close one / filtered / all, details (copyable), pause |
| Logs | Log level, type filter, regex search, pause, clear, newest-first toggle, copy, save as text file |
| Settings | Language, backends and core maintenance, theme and accent color, frosted glass, immersive light, wallpaper, latency test options, retention, crash logs, About |

## Building

Open the project in DevEco Studio 26.0.0 Release and run `Build → Build Hap(s)/APP(s)`, or use the Command Line Tools:

```bash
hvigorw --mode module -p module=entry@default -p product=default -p buildMode=release assembleHap --no-daemon
```

Output: `entry/build/default/outputs/default/entry-default-unsigned.hap`. Installing on a real phone needs signing with your own Huawei developer account (DevEco Studio → `File → Project Structure → Signing Configs` → automatic signing).

## Translations

UI strings live in `entry/src/main/ets/common/i18n/StringsZh.ets` and `StringsEn.ets` and are read through `t(key)` from `common/I18n.ets`. Legal texts are generated from `docs/*.md` with `python3 scripts/gen-legal.py`. Run `python3 scripts/check-i18n.py` to verify both tables have the same keys, every key used in code exists, and no Chinese text is left in `.ets` outside the Chinese tables.

## License and privacy

No account, no data collection, no third-party SDKs; backends, secrets and settings stay on the device. See the [Privacy Policy](docs/privacy_en.md).
