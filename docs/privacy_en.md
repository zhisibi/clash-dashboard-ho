# Mimi Panel Privacy Policy

Version: 6
Last updated: November 13, 2026
Effective: November 13, 2026

Mimi Panel ("the App") is provided by the developer Zhang Shibo ("we" or "us"). The App is a control panel that runs locally on your device and connects to the external-controller API of a mihomo-compatible proxy core that you deploy yourself. We take the protection of your personal information seriously; please read this policy carefully before using the App.

The Chinese version of this policy (docs/privacy.md) is the governing version; this English version is provided for convenience.

## 1. We do not collect your personal information

- The App has no account registration or sign-in and never asks for your phone number, email or other identity information.
- The App does not collect or upload any personal information, device identifiers, usage statistics or behavioral data. We run no servers of our own; the App sends no data to any server of ours and performs no analytics or ad tracking of any kind.
- The App contains no third-party SDKs (no analytics, advertising, push or crash-reporting SDKs).
- All information the App handles stays on your device, as detailed in Section 2 and Appendix 1 below.

## 2. Information stored on your device

The following information is kept only in the App's private storage on your device (system Preferences and the app sandbox) and is never sent to us or any third party:

- Backend details you enter: name, protocol (HTTP/HTTPS), host, port, path prefix and access secret. The access secret is stored in plain text in the App's sandbox storage (Preferences), protected by the operating system's app-sandbox isolation so that other apps cannot read it; please also keep your device itself secure.
- App settings: theme, accent color, UI language, frosted glass and light effects, latency test parameters, log level, display and retention preferences.
- A copy of the wallpaper image you choose (only if you set a wallpaper).
- The local data snapshot shown on desktop / minus-one-screen cards, which contains: connection state, backend name, total upload, total download, memory usage, connection count, current mode, main policy group, current node name and accent color. The snapshot does not contain the access secret.
- Crash logs: when the App hits an uncaught exception, it records the time, app version, device model, OS version and the exception stack trace inside the app sandbox, so you can troubleshoot. Only the most recent 20 logs are kept; older ones are deleted automatically. Crash logs are stored only inside the app sandbox, are not mirrored to any public folder and are never uploaded automatically; they leave the device only when you tap "Copy", "Share" or "Save", and only to the clipboard, app or location you choose.

Retention: backend details and app settings are kept until you delete them in the App or uninstall the App. Live connection data and core logs are processed in memory only, are never written to disk, and disappear when the App exits.

## 3. Network access

- The App requests the network permission (ohos.permission.INTERNET). Except as listed in this section, the App's network requests go only to the backend addresses you configure, to read and change the proxy core's status, configuration, connections, logs and rules.
- Node latency tests are performed by your backend: the App only passes the test URL you set (default https://www.gstatic.com/generate_204) to the backend as a parameter and never visits that URL itself.
- Icon loading: the App loads and displays proxy-group icons. The icon address comes from the icon field in the data your backend returns through its API; it can be any remote URL and is determined by your backend's configuration — the App neither presets nor designates it. When loading, your device requests the image directly from the server hosting that icon, and that server will therefore learn your device's IP address and the time of the request. If you do not want such requests to occur, do not set icons for proxy groups in your backend configuration, or leave the icon field empty in the backend; when no icon is configured, the App makes no such requests.
- Update check: the App does not check for updates automatically. Only when you manually tap Settings > About > Version does the App ask Huawei AppGallery's system update service (StoreKit) whether a newer version exists; if so, the system shows its update prompt. That query is handled by AppGallery under its own privacy policy; the App itself sends no request to any server of ours and provides no additional personal information.
- Apart from the above, the App sends no data to us or to any other server.

## 4. Use of device capabilities and permissions

- The App requests exactly two system permissions: the network permission (ohos.permission.INTERNET) and the background-running permission (ohos.permission.KEEP_BACKGROUND_RUNNING). Their purposes, use scenarios and the effect of refusing them are listed in Appendix 3 below.
- Gravity sensor: used only when you turn on "Immersive Light → Follow device tilt", to adjust the direction of UI highlights. The data is used in memory in real time and is never stored or uploaded. The feature is off by default and stops automatically when the App goes to the background.
- Image picker: when setting a wallpaper, you pick one image through the system photo picker. The App can access only the image you pick and needs no storage permission.
- Saving and sharing files: done through the system "Save as" picker and share panel, and only for log text you choose to export.
- Clipboard: written only when you tap "Copy" (including the QQ group number on the feedback entry). The App never reads the clipboard.
- Desktop and minus-one-screen cards (service widgets): card content comes from a data snapshot the App generates locally on the device (see Section 2 for its fields; it contains no access secret). The card process itself has no network access and never reads or touches your backend address or access secret. When you tap a card to switch the mode or node, the tap command travels through the system's call channel back to the App's main process, which uses the backend details you saved in the App and sends the switch request only to your own backend; it contacts no other server. The background-running permission exists so that such card taps can wake the main process to carry out the action (see Appendix 3).

## 5. Your rights

- View, change and delete: you can view, change or delete your saved backends and settings in the App at any time, remove the wallpaper and clear crash logs.
- Export: the App supports exporting only log text, initiated by you through the system file picker. Backend configurations and app settings cannot be exported, and the App provides no export function for them.
- Withdraw consent: you can withdraw consent under "Settings → About → Withdraw privacy consent"; the App then exits and asks for consent again on the next launch.
- Uninstall: you can uninstall the App at any time; all data the App keeps in its sandbox (backend details, settings, snapshots, crash logs and more) is then deleted by the system together with the App.

## 6. Minors

The App is intended for users who can deploy and manage a proxy core. It is not directed at minors and collects no personal information from minors.

## 7. Changes to this policy

If this policy changes, we will publish a new version with an updated version number, in the App and on our website. Before a new version takes effect, the App will ask for your consent again; if you do not agree with the new version, you may stop using and uninstall the App.

## 8. Contact us

If you have any questions about this policy, or wish to exercise your rights, contact us by the developer's email: zhisibi@163.com (shown for display only). You can also copy the QQ group number under "Settings → About → Feedback" in the App and reach us through the QQ group.

## Appendix 1: Personal Information Collection List

The App does not collect or upload personal information. The following items are processed only locally on your device and are never uploaded:

| Item | Usage scenario | Purpose | How it is handled |
| --- | --- | --- | --- |
| Backend details (name, protocol, host, port, path prefix) | Adding and switching backends; connecting to the proxy core | Connecting to and managing the backend you deploy | Processed locally only, never uploaded; stored in the app sandbox |
| Backend access secret | Authentication when connecting to a backend | Passing the backend API's identity check | Processed locally only, never uploaded; stored in plain text in the sandbox Preferences, protected by system sandbox isolation |
| App settings and preferences (theme, language, effects, test parameters, etc.) | Personalized display and feature configuration | Remembering your preferences | Processed locally only, never uploaded; stored in the app sandbox |
| Wallpaper image copy | When you set a wallpaper | Home-screen background display | Processed locally only, never uploaded; stored in the app sandbox |
| Card data snapshot (connection state, backend name, upload/download totals, memory usage, connection count, mode, policy group, current node, accent color) | Desktop / minus-one-screen card display and tap-to-switch | Showing backend status on cards and providing quick switching | Processed locally only, never uploaded; stored in the app sandbox; contains no access secret |
| Crash logs (time, app version, device model, OS version, exception stack trace) | When the App hits an uncaught exception | Troubleshooting by you | Processed locally only, never uploaded; stored in the app sandbox, most recent 20 kept; leaves the device only when you copy, share or save it |
| Connection and core log data (connection list, traffic, log stream) | Overview, Connections and Logs pages | Showing live backend status | Processed locally only, never uploaded; kept in memory only, never written to disk |

## Appendix 2: Third-Party Sharing List

- The App contains no third-party SDKs and does not share, transfer or publicly disclose your personal information to any third party.
- We run no servers of our own, and the App sends none of your information to the developer.
- The only situation involving a third party: update checks. When you manually tap to check, Huawei AppGallery's system update service handles the version query, under AppGallery's own privacy policy; the App provides it with no additional personal information.
- When you use system sharing or system file saving, content goes to the app or location you choose, handled by the system and the target app under their own rules.

## Appendix 3: App Permissions

| Permission | Purpose | Usage scenario | Effect of refusing or disabling |
| --- | --- | --- | --- |
| ohos.permission.INTERNET (network) | Connecting to the backends you configure; loading proxy-group icons from the addresses your backend returns | All of the App's network features; requesting images from icon servers when loading icons | No backend can be connected and the App's main features are unavailable; remote icons cannot load |
| ohos.permission.KEEP_BACKGROUND_RUNNING (background running) | Letting card tap commands reach the App's main process through the system's call channel to be carried out | When you tap a desktop / minus-one-screen card to switch the mode or node | Cards still display status, but taps may fail to wake the main process and switching will not work |

The App requests no other system permissions. Image picking, file saving and sharing are all performed through system components and need no additional permission.
