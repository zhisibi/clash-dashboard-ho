# 咪咪面板（HarmonyOS 版）

[English](README_en.md) · 简体中文

用 **ArkTS + ArkUI（Stage 模型）** 编写的 HarmonyOS 原生管理面板，适用于与 mihomo 兼容的代理内核所提供的 `external-controller` RESTful API。
功能与安卓 Kotlin/Compose 版 v1.1.2 对齐，界面参照 Zashboard。

> App 本身**不包含代理内核**，也不会启动代理服务，需要配合已在运行的后端使用（例如路由器或局域网电脑上的内核，或手机上的代理客户端开放的外部控制器）。

| 项目 | 值 |
| --- | --- |
| 应用名 | 咪咪面板（英文 Mimi Panel） |
| bundleName | `com.zhisibi.mimipanel`（**唯一的修改位置：`AppScope/app.json5` 的 `bundleName`**，必须与 AppGallery Connect 中创建的应用包名一致） |
| 版本 | 1.2.8（versionCode 1020800） |
| 最低系统 | HarmonyOS 6.0（`compatibleSdkVersion: "6.0.0(20)"`） |
| 目标系统 | HarmonyOS 7（`targetSdkVersion: "26.0.0"`，API 26） |
| 开发工具 | DevEco Studio 26.0.0 Release（26.0.0.821）或同版本 Command Line Tools |
| 状态管理 | ArkUI 状态管理 V2（`@ObservedV2` / `@Trace` / `@ComponentV2`） |
| 界面语言 | 简体中文、English（设置 → 语言，可跟随系统） |

## 更新日志

### 1.2.8
- 检查更新改为通过华为应用市场（StoreKit 更新服务）：点击“设置 → 关于 → 版本”，有新版本时弹出系统更新提示，不再访问 GitHub；隐私政策同步修改。

### 1.2.7
- 新增：“设置 → 关于 → 版本”点击即检查 GitHub 仓库最新发布版本，有新版本时弹窗提示，可直接打开下载页。
- 隐私政策补充检查更新所涉及的网络访问，隐私政策版本升为 2（升级后会请您重新确认）。

### 1.2.6
- 代理页所有测速按钮按下时有按压缩放动画，测速期间持续转圈直到结束：顶栏“全部测速”、代理组详情的测速按钮会变为加载动画；测试整个代理组 / 健康检查提供者时，其中每个节点的延迟胶囊也同步转圈。

### 1.2.5
- 隐私政策与用户协议末尾的联系方式改为开发者邮箱：zhisibi@163.com。

### 1.2.4
- 修复隐私政策与用户协议页面无法上下滑动、返回按钮无响应（1.2.3 引入的触摸拦截把页面自身内容也拦住了）。
- 关于页、隐私政策与用户协议中的开发者改为张世博；两份文件更新日期改为 2026 年 10 月 9 日。

### 1.2.3
- 修复代理组节点弹窗（如“节点选择 Selector · 5 个节点 · 当前 …”）右上角的测速按钮被系统关闭按钮（X）压住：弹窗不再显示系统关闭按钮，标题栏改为“⚡ 测速”与“✕ 关闭”两个并排按钮，触控区域均为 48vp；仍可下拉拖动关闭。连接详情弹窗的“断开”按钮同样处理
- 修复节点卡片的延迟胶囊（如 96、241）盖住节点的当前选中文字（ai…、v…、国旗等）：标签区占满延迟胶囊左侧的剩余宽度，最后一个标签超长时以省略号结尾，不再被胶囊遮住（中英文界面均已处理）
- 修复开启毛玻璃（或设置壁纸）后，从设置 → 关于打开的隐私政策 / 用户协议页面透明，下面的“关于”页和底部导航栏透出、文字叠在一起无法阅读：隐私政策 / 用户协议改为先铺一层不透明的页面底色，毛玻璃渐变或（强模糊 + 遮罩的）壁纸只叠在这层底色之上，并完全遮住底部导航栏、拦截下层点击；返回按钮触控区域加大到 48vp
- 同类问题一并排查修复：撤回同意后重新出现的首次启动同意页在设置了壁纸时不再是黑底；后端编辑弹窗、闪退日志弹窗、主题色选择浮层在“壁纸 + 关闭毛玻璃”时不再半透明；开启毛玻璃时所有弹窗的底色不透明度提高到至少 88%（叠在系统模糊之上），文字不再与下层页面混在一起

### 1.2.2
- 修复 AppGallery 上架自检“界面滑动到边界位置时应有反馈动效”问题（在折叠屏展开/折叠态的设置页检出 Tabs / Swiper / Scroll 缺少回弹）：
  - 左右滑动切换页面：在第一页（概览）继续右滑、在最后一页（设置）继续左滑时回弹（Tabs 边缘效果由“无”改为“弹簧”）
  - 所有可滚动区域（概览、代理、连接、日志、规则 / 规则集、设置主页及全部子页面、首次启动同意页、连接后端引导页、隐私政策 / 用户协议、后端编辑弹窗、代理组节点弹窗、连接详情、闪退日志）滑到顶部或底部时回弹，内容不足一屏（如设置搜索后只剩几项、内容较短的子页面）也会回弹
  - 代理、连接、日志、规则页的空状态 / 加载中 / 错误状态改为可滚动容器，同样支持回弹与下拉刷新
  - 闪退日志正文左右滚动到边界时也会回弹
### 1.2.1
- 修复 AppGallery 上架自检“颜色对比度”问题（图标/标题对比度需 >3:1，正文需 >4.5:1）：
  - 连接后端表单的 **保存并连接**、**测试连接** 按钮不再进入禁用态（禁用态 40% 透明导致白字对比度仅 1.89）；按钮始终可点，点击时校验：未填地址 / 端口或端口超出 1–65535 时弹出提示，并将对应输入框标红、在按钮上方显示原因
  - 次要文字、标签、输入框占位符、状态色（成功 / 警告 / 错误 / 日志信息）加深（浅色）或提亮（深色），在卡片、输入框、半透明毛玻璃卡片、顶栏与底栏上均达到 4.5:1
  - 主题色拆分为“文字色 / 图标控件色 / 按钮填充色”：7 个预设主题色在浅色与深色模式下按钮文字均 ≥4.5:1——橘黄黄、哔哩粉、小草绿在浅色模式下保留原有亮色按钮并改用深色文字；深色模式下星河蓝、猫咪蓝、华为红、优雅紫按钮略加深以承载白字，其余三色用深色文字；主题色文字（链接、选中项、标签）与图标按需加深/提亮；背景渐变、色板等装饰仍用原色
  - 底部导航选中项、同意页“同意”按钮、颜色预览、连接页上传/下载文字同步使用新配色
- 新增 `scripts/check-contrast.py`：按 `Theme.ets` 计算全部预设主题色在浅色/深色下各配色与页面、卡片、输入框、半透明卡片（默认不透明度 0.55，叠加毛玻璃背景渐变）、顶栏、底栏之间的 WCAG 对比度，不达标时返回非 0

### 1.2.0
- 新增 **英文界面（English）**：设置页顶部新增 **语言 / Language**，可选“跟随系统”（默认）、简体中文、English，选择保存在本地设置中
  - 切换后**立即生效、无需重启**：界面文字统一走应用内字符串表（`common/I18n.ets` 的 `t()` + `common/i18n/StringsZh.ets` / `StringsEn.ets`），语言是响应式状态，切换时整棵界面按语言重建，当前页签与设置子页面保持不变
  - 同时调用 `i18n.System.setAppPreferredLanguage` 让系统资源（应用名、权限说明等）与应用语言一致；“跟随系统”时系统语言为中文显示中文，其他语言显示英文，运行中修改系统语言也会跟随
  - 覆盖全部界面：概览、代理、规则 / 规则集、连接、日志、设置及所有子页面、关于、后端表单、首次启动同意页、闪退日志、提示 Toast、确认弹窗、空状态与错误提示、单位与相对时间（如“3 分钟前 / 3 min ago”）、主题色名称、毛玻璃与光感设置等
  - 新增英文版《隐私政策》《用户协议》（`docs/privacy_en.md`、`docs/agreement_en.md`），应用内按界面语言显示；`scripts/gen-legal.py` 现在生成 `common/i18n/LegalZh.ets` 与 `LegalEn.ets`
  - 英文排版：底部导航使用短标签（Overview / Proxies / Conns / Logs / Rules / Settings）并在空间不足时自动缩小字号，较长的分段选项在英文下使用紧凑尺寸，标题等单行文字超长时省略号截断；毛玻璃“材质”选项改为标题下方单独一行
  - 应用名称与能力描述、网络权限说明提供 en_US 资源（Mimi Panel）
  - 设置搜索同时匹配中英文关键词
- 代码注释统一改为英文；新增 `scripts/check-i18n.py`：检查中英文字符串表键一致、代码里用到的键都存在、`.ets` 中除中文字符串表外没有中文字符
- 隐私政策：本地保存的设置项中补充“界面语言”（无实质变更，不需要重新同意）

### 1.1.9
- 基于 1.1.7 代码：恢复系统沉浸材质（`uiMaterial` / `systemMaterial`，API 26 且设备支持时在毛玻璃“材质”中可选“系统”），`targetSdkVersion` 恢复为 `26.0.0`，用 DevEco Studio 26.0.0 Release（SDK 26.0.0.821）构建
- 新增 **下拉刷新**（ArkUI `Refresh` 组件）：概览、代理（代理组 / 订阅）、连接、日志、规则（规则 / 规则集）页面下拉即可刷新；设置页不需要
  - 概览：探测后端并刷新配置、代理与规则；代理、规则：重新拉取对应数据；连接、日志：探测后端后重建实时流；后端连接失败时下拉会重新连接
  - 刷新指示器使用主题色，显示在毛玻璃顶栏下方（不被顶栏遮挡），请求完成（成功或失败）后才收起，失败时弹出简短提示
  - 与左右滑动切页、滚动自动收起底栏共存；内容不满一屏时也能下拉
  - 未同意隐私政策与用户协议前不会发起任何网络请求
- 说明：1.1.8 是移除系统材质、`targetSdkVersion` 改为 `6.1.1(24)` 的 API 24 兼容构建，1.1.9 回到 1.1.7 的配置

### 1.1.7

- 改名为 **咪咪面板**（英文 Mimi Panel），去掉界面、代码与文档中的第三方品牌字样；内部 API 客户端改名为 `CoreApi`
- bundleName 改为 `com.zhisibi.mimipanel`，为上架华为应用市场做准备。**这是一个新应用**：与旧包名的版本互不覆盖，旧版里的后端与设置不会自动带过来，需要重新添加
- 新增首次启动的《隐私政策》《用户协议》同意弹窗：同意前不发起任何网络请求，不同意则退出；正文见 `docs/privacy.md`、`docs/agreement.md`
- 新增 **设置 → 关于**：应用名称、版本、开发者、隐私政策、用户协议、撤回隐私政策同意
- 应用内本地设置存储改名为 `mimi_panel`，导出日志文件名改为 `mimi-logs-*.txt`
- 增加英文（en_US）应用名称资源
- 自动发布：附件改名为 `MimiPanel-HarmonyOS-<版本>-unsigned.hap`；配置签名 Secrets 后还会构建并附上已签名的 `.hap` 和用于上传 AppGallery Connect 的已签名 `.app`

### 1.1.6

- 修复：悬浮底栏的页签点不动。原因是 1.1.5 把底栏放进了一个全宽、`HitTestMode.Transparent` 的容器并叠在全屏页面之上，落在底栏上的触摸会同时命中下方页面的列表/滚动手势和卡片点击，页签的点击在手势竞争中被下层吞掉；另外外层玻璃容器上还挂了一个与页签嵌套竞争的 `onClick`，流光层用 `.overlay()` 盖在页签上方。现在底栏本体使用 `HitTestMode.BLOCK_HIERARCHY`（触摸只交给底栏），去掉外层 `onClick`（收起后的圆形按钮自己响应点击并展开），流光层改为底栏内部的装饰层并设为 `HitTestMode.None`；系统沉浸材质的“交互形变”也对底栏关闭。
- 新增：左右滑动切换页面。六个页面放在隐藏页签栏的 `Tabs` 中，底栏与页面双向同步——点底栏动画切到对应页，滑动切页时底栏高亮在动画开始时就跟上；切页后自动展开已收起的底栏。页面切换不会重建，各页的筛选、搜索、滚动位置等状态都会保留；不在当前页时暂停界面刷新（`freezeWhenInactive`），切回来立即显示最新数据，WebSocket 数据流行为与之前一致。页面内的滑块、横向滚动等手势优先于翻页。
- 顶栏收窄约一半：标题 18fp、上下内边距收紧，顶栏内的分段按钮、搜索框、下拉框、图标按钮使用紧凑尺寸；设置主页的标题与搜索框合并为一行；连接页的 ↑/↓ 总流量改为分段按钮右侧的两行小字，条数移到排序行。内容留白继续跟随实测的顶栏高度。

### 1.1.5

- 全屏沉浸：窗口改为全屏布局（`setWindowLayoutFullScreen`），页面背景/壁纸延伸到状态栏和底部手势指示条下方，去掉了底部那条灰色色带；内容按 `getWindowAvoidArea`（状态栏 TYPE_SYSTEM、导航条 TYPE_NAVIGATION_INDICATOR）的高度自动留白，并监听避让区变化；状态栏文字颜色跟随浅色/深色。
- 悬浮底栏下移，贴近手势指示条（约留 8vp 间隙）；各页面列表底部留白随底栏位置计算，最后一项可以滚到底栏上方。
- 底栏改为真正的磨砂玻璃：开毛玻璃时始终使用强模糊（自定义材质模糊半径 ≥70、预设材质 COMPONENT_THICK / ULTRA_THICK、系统材质 THICK）并保证足够的底色，下面滚过的文字不再透出来与标签打架；关闭毛玻璃时为接近不透明的底色。
- 底栏自动收起：往下浏览时底栏以动画收起成左下角的圆形玻璃按钮（显示当前页图标）；往回滑动或点按圆形按钮即展开。只响应手指拖动/惯性滑动，忽略程序滚动与触底回弹抖动，回到页面顶部时始终展开。设置 → 面板 → 导航栏 → 自动收起导航栏（默认开启）。
- 顶栏改为真正的毛玻璃：顶栏叠放在内容之上并延伸到状态栏下方，内容从顶栏下面滚过并被模糊（共享组件 `components/GlassHeader.ets`，六个页面统一）；关闭毛玻璃时顶栏为接近不透明的底色。
- “后端连接失败”提示条改为悬浮在底栏上方。

### 1.1.4
- 新增 **设置 → 面板 → 毛玻璃效果**（开关 + 可调参数）
  - 材质：自定义（模糊 + 饱和度增强，`backgroundEffect`）、薄 / 常规 / 厚（系统组件材质 `backgroundBlurStyle(COMPONENT_THIN/REGULAR/THICK)`，按模糊强度调节程度）；API 26 且设备支持时额外提供“系统”（系统沉浸材质 `systemMaterial`）
  - 模糊强度、卡片不透明度滑块；“列表项也模糊”开关（长列表逐项模糊更通透但更耗电，默认关闭）
  - 作用于卡片、各页顶栏、悬浮底栏、半模态面板与弹出菜单；有壁纸时透出壁纸，无壁纸时自动铺一层柔和的主题色渐变背景，让玻璃效果可见
- 新增 **设置 → 面板 → 沉浸光感**（开关 + 可调参数）
  - 玻璃边缘高光（朝向光源的边更亮，形成玻璃厚度感）、斜向柔光、主题色光晕
  - 光感强度滑块；“跟随重力感应”（倾斜手机时高光方向随之变化，100 ms 低频采样、按 6° 量化更新，退到后台自动停止）；“主题色光晕”与“流光扫过”（切换页签时一道光扫过底栏，一次性动画）开关
  - 在 API 26 且支持沉浸材质的设备上，可在毛玻璃“材质”中选择“系统”，使用系统原生沉浸光感材质与光感交互反馈；其他设备（如 HarmonyOS 6.0 / API 20）使用应用内自绘效果
- 所有新设置保存在本地，修改即时生效、无需重启，并适配深色模式；设置搜索支持“毛玻璃 / 模糊 / 光感 / 沉浸”等关键词

### 1.1.3
- 新图标：原创扁平风“小猫咪”头像，蓝紫渐变背景，HarmonyOS 分层图标（前景/背景 1024×1024，主体在安全区内，圆形/圆角方形遮罩都不会裁切）
- 新增 **设置 → 面板 → 外观 → 主题色**：星河蓝（默认）、橘黄黄、猫咪蓝、华为红、优雅紫、哔哩粉、小草绿
  - 点击“主题色”弹出菜单，彩色圆点 + 名称，当前项带 ✓；下方有“颜色预览”卡片
  - 全局生效、即时切换无需重启：按钮、分段选项卡、开关、滑块、单选框、输入光标、流量/内存曲线、选中节点描边、订阅进度条、底部悬浮导航栏选中项
  - 与浅色/深色/跟随系统叠加，深色模式自动使用稍亮的色调；选择保存在本地设置中

### 1.1.2
- 从安卓 Kotlin 版 v1.1.2 移植的首个 HarmonyOS 版本

## 功能

| 页面 | 功能 |
| --- | --- |
| 概览 | 实时上传/下载速度、总流量、活跃连接、内存占用、速度与内存曲线（Canvas）、流量最多的主机、快速切换代理模式 |
| 代理 | 代理组卡片（1~3 列）、节点选择、分组/单节点测速、延迟颜色分级、排序、搜索（支持正则）、隐藏不可用节点、显示 GLOBAL 与隐藏组、取消固定、代理提供商（订阅流量/到期、更新、健康检查） |
| 连接 | 活跃/已关闭/全部、搜索与正则过滤、来源 IP 筛选、11 种字段排序、紧凑模式、单条/全部/筛选结果断开、连接详情（可复制）、暂停刷新 |
| 日志 | 日志级别切换、类型过滤、正则搜索、暂停、清空、正序/倒序、复制、另存为文本文件 |
| 规则 | 规则列表（虚拟滚动，规则多也不卡）、单条规则启用/禁用、规则集更新、命中次数、代理链与延迟 |
| 设置 | 界面语言（跟随系统 / 简体中文 / English）、关于（版本、开发者、隐私政策、用户协议）、多后端管理与连接测试、代理模式、内核日志级别、TUN、局域网、IPv6、各类端口、重载配置、更新 GEO、清空 DNS/FakeIP 缓存、更新/重启内核、主题（跟随系统/浅色/深色）、主题色（7 种预设）、毛玻璃效果、沉浸光感、自定义壁纸（卡片不透明度/暗化/模糊）、测速参数、保留数量、闪退日志 |

- 实时数据通过 WebSocket 获取：`/traffic`、`/memory`、`/connections`、`/logs`，断线指数退避自动重连（1s → 10s）
- 后端返回 404/405/501 的接口（例如部分客户端限制了外部控制）会被标记为“当前后端不支持”，并在设置里说明
- 更新 GEO 时 `/configs/geo` 不可用会自动改用 `/upgrade/geo`
- 闪退（JS 未捕获异常）时自动保存错误日志，下次启动弹窗提示；可在 **设置 → 闪退日志** 中复制、分享或另存为

## 使用

1. 在代理客户端里开启外部控制器（external-controller），记下地址、端口和密钥（secret）
2. 安装后首次打开填写后端地址，例如 `192.168.1.1:9090` 或 `127.0.0.1:9090`
3. 点“测试连接”，成功后“保存并连接”

## 用到的系统能力

| 能力 | API |
| --- | --- |
| HTTP 请求 | `@kit.NetworkKit` `http`（GET/POST/PUT/DELETE） |
| PATCH 请求 | `@kit.RemoteCommunicationKit` `rcp`（NetworkKit 的 `RequestMethod.PATCH` 从 API 26 才有，为兼容 HarmonyOS 6.0 改用 RCP） |
| 实时流 | `@kit.NetworkKit` `webSocket` |
| 设置存储 | `@kit.ArkData` `preferences` |
| 壁纸选择 | `@kit.MediaLibraryKit` `photoAccessHelper.PhotoViewPicker`（无需存储权限） |
| 导出文件 | `@kit.CoreFileKit` `picker.DocumentViewPicker`（另存为） |
| 复制 / 分享 | `pasteboard`、`@kit.ShareKit` `systemShare` |
| 闪退捕获 | `@kit.AbilityKit` `errorManager` |

权限只申请了 `ohos.permission.INTERNET`。明文 HTTP（`http://127.0.0.1`、局域网地址）通过
`entry/src/main/resources/base/profile/network_config.json` 显式允许（`cleartextTrafficPermitted: true`，并对 Network Kit / Remote Communication Kit 生效）。

## 构建

### 方式一：DevEco Studio（推荐）

1. 安装 DevEco Studio 26.0.0 或更新版本（自带 HarmonyOS SDK）
2. `File → Open` 打开本目录，等待同步完成
3. `Build → Build Hap(s)/APP(s) → Build Hap(s)`

输出：`entry/build/default/outputs/default/entry-default-unsigned.hap`（未配置签名时）或 `entry-default-signed.hap`

### 方式二：命令行（Command Line Tools）

从华为开发者联盟下载 Command Line Tools（需要登录）：<https://developer.huawei.com/consumer/cn/download/>，解压后：

```bash
CLT_HOME=/path/to/command-line-tools ./scripts/build.sh release
```

等价命令：

```bash
export DEVECO_SDK_HOME=$CLT_HOME/sdk
export PATH=$CLT_HOME/bin:$PATH
hvigorw --mode module -p module=entry@default -p product=default -p buildMode=release assembleHap --no-daemon
```

### 自动发布（GitHub Actions）

`.github/workflows/release.yml`：推送 `v*` 标签（如 `git tag v1.2.0 && git push origin v1.2.0`）或在 Actions 页手动运行（填写标签）时触发。

- 在 `ubuntu-latest` 上从 [ErBWs/ohos-sdk](https://github.com/ErBWs/ohos-sdk) 镜像下载 Command Line Tools 26.0.0.821（linux-x64，校验 sha256），裁掉用不到的 NDK 后用 `actions/cache` 缓存，之后的运行不再重复下载
- `ohpm install` 后执行 `hvigorw assembleHap`（release 模式），版本号取自 `AppScope/app.json5`
- 创建与标签同名的 Release，说明取自本文“更新日志”中对应版本，附件为 `MimiPanel-HarmonyOS-<版本>-unsigned.hap`（**未签名，只能装到模拟器**）

可选签名：在仓库 `Settings → Secrets and variables → Actions` 中配置以下 Secrets 后，会用 `scripts/ci-signing.js` 生成 hvigor 的 signingConfig，再执行 `hvigorw assembleApp`，附上已签名的 `MimiPanel-HarmonyOS-<版本>-signed.hap` 与 `MimiPanel-HarmonyOS-<版本>-signed.app`；不配置则只发布未签名包。Secrets 首尾的空格/换行会被自动去掉。

| Secret | 内容 |
| --- | --- |
| `HAP_SIGN_P12_BASE64` | 密钥库 `.p12` 的 base64（`base64 -w0 key.p12`） |
| `HAP_SIGN_CER_BASE64` | AGC 证书 `.cer` 的 base64 |
| `HAP_SIGN_P7B_BASE64` | AGC Profile `.p7b` 的 base64 |
| `HAP_KEY_ALIAS` | 密钥别名 |
| `HAP_KEY_PASSWORD` | 密钥密码 |
| `HAP_STORE_PASSWORD` | 密钥库密码 |

> 用 AGC 证书签名的包只能装到该 Profile 授权的设备上；DevEco Studio 自动签名生成的证书绑定本机账号，不适合放进 CI。

## 签名与安装到真机

HarmonyOS 真机**只能安装签过名的 HAP**；未签名 HAP 只能装到 DevEco Studio 的模拟器上。签名需要你自己的华为开发者账号。

### 方式一：DevEco Studio 自动签名（最简单，用于自己调试）

1. 手机开启开发者模式：设置 → 关于本机，连续点击“版本号”；然后在 设置 → 系统 → 开发者选项 中打开 **USB 调试**（无线调试也可以）
2. 用数据线连接电脑，DevEco Studio 右上角设备列表里出现手机
3. `File → Project Structure → Project → Signing Configs`，勾选 **Automatically generate signature**，按提示登录华为账号
4. 点运行（▶）即可安装；也可 `Build → Build Hap(s)` 生成 `entry-default-signed.hap`

自动签名生成的是**调试证书**，会绑定当前登录账号和已连接的设备，适合自用，有效期有限，过期后重新签一次即可。

### 方式二：手动签名（AppGallery Connect 证书）

1. 在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 创建应用，包名填 `com.zhisibi.mimipanel`
2. 生成密钥库（`.p12`）和证书请求文件（`.csr`）：DevEco Studio `Build → Generate Key and CSR`
3. 在 AGC 申请**调试证书（.cer）**并注册手机 UDID，再申请**调试 Profile（.p7b）**
4. `File → Project Structure → Signing Configs` 取消自动签名，填入 `.p12`、`.cer`、`.p7b` 与密码；或直接写进 `build-profile.json5` 的 `signingConfigs`
5. 重新构建得到已签名 HAP

命令行签名可使用 SDK 自带的 `hap-sign-tool.jar`（位于 `sdk/default/openharmony/toolchains/lib/`）：

```bash
java -jar hap-sign-tool.jar sign-app -keyAlias "你的别名" -signAlg SHA256withECDSA -mode localSign \
  -appCertFile debug.cer -profileFile debug.p7b -inFile entry-default-unsigned.hap \
  -keystoreFile key.p12 -keystorePwd 密码 -keyPwd 密码 -outFile MimiPanel-signed.hap -signCode 1
```

### 安装

```bash
hdc install MimiPanel-signed.hap        # hdc 在 sdk/default/openharmony/toolchains/
hdc shell aa start -a EntryAbility -b com.zhisibi.mimipanel
```

> 升级安装必须使用同一套签名证书，否则需要先卸载旧版。

## 项目结构

```
AppScope/                       # 应用级配置（bundleName、版本、图标）
docs/                           # privacy.md / agreement.md 隐私政策与用户协议，privacy_en.md / agreement_en.md 英文版（可用 GitHub Pages 托管）
icon-src/                       # 图标源文件（SVG：前景小猫 + 渐变背景）
entry/src/main/
├── module.json5                # 模块配置、INTERNET 权限
├── resources/base/profile/
│   ├── main_pages.json
│   └── network_config.json     # 允许明文 HTTP
└── ets/
    ├── entryability/EntryAbility.ets   # 入口、深色模式、闪退捕获
    ├── pages/Index.ets                 # 首次设置、底部导航、壁纸、连接失败横幅
    ├── common/
    │   ├── Models.ets          # 数据模型与 JSON 解析
    │   ├── CoreApi.ets         # REST + WebSocket 客户端
    │   ├── I18n.ets            # 界面语言（跟随系统 / 中文 / 英文）与 t() 取字符串
    │   ├── i18n/               # StringsZh.ets / StringsEn.ets 字符串表；LegalZh.ets / LegalEn.ets（scripts/gen-legal.py 由 docs/*.md 生成）
    │   ├── Legal.ets           # 按界面语言返回隐私政策/用户协议正文、PRIVACY_VERSION
    │   ├── Store.ets           # 全局状态与业务逻辑（对应 MainViewModel）
    │   ├── Prefs.ets           # preferences 设置存储
    │   ├── CrashLog.ets        # 闪退日志
    │   ├── FileUtil.ets        # 文件、剪贴板、分享
    │   ├── Format.ets          # 格式化
    │   └── Theme.ets           # 浅色/深色配色、主题色预设
    ├── components/             # 通用组件（徽标、搜索框、分段、折线图、设置行、后端表单、毛玻璃顶栏 GlassHeader）
    └── views/                  # 概览、代理、连接、日志、规则、设置
```

## 与安卓版的差异

- 图标使用 HarmonyOS 系统 Symbol 图标（`sys.symbol.*`）代替 Material Icons
- 壁纸模糊在所有支持的系统版本上可用（安卓版需要 Android 12+）
- 日志/闪退日志“保存”使用系统“另存为”选择器，由用户选择保存位置（安卓版直接写入“下载”目录）
- 闪退日志只捕获 ArkTS/JS 层未捕获异常；Native 崩溃（C++）不在 App 内记录，可通过 DevEco Studio 的 FaultLog 查看
- 代理节点图标支持网络 URL 与 base64 data URI；SVG 以系统 Image 组件能力为准

## 兼容性

- 与 mihomo 兼容的外部控制器 RESTful API
- 规则禁用（`PATCH /rules/disable`）需要 mihomo 1.19.x 以上；不支持时自动隐藏开关
- 部分客户端提供的受限控制器：会拒绝 `PATCH /configs`（405）、`PUT /configs`、`/configs/geo`、`/restart`（404），App 会标记并提示在客户端里修改

## 上架华为应用市场

以下步骤需要你本人用华为开发者账号完成（涉及实名认证与证书私钥，CI 和本仓库无法代办）：

1. **开发者账号与实名**：在 [华为开发者联盟](https://developer.huawei.com/consumer/cn/) 注册并完成个人或企业实名认证。
2. **创建应用**：在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) →“我的项目”创建项目，再添加 HarmonyOS 应用，包名填 `com.zhisibi.mimipanel`。如果要换包名，只需改 `AppScope/app.json5` 的 `bundleName`，并与 AGC 中保持一致。
3. **发布证书**：DevEco Studio `Build → Generate Key and CSR` 生成密钥库 `.p12` 与证书请求 `.csr`；在 AGC“证书、APP ID 和 Profile”中上传 `.csr` 申请**发布证书**，下载 `.cer`。妥善保存 `.p12` 和密码，丢失后无法再用同一证书更新应用。
4. **发布 Profile**：在 AGC 为该应用申请**发布 Profile**（选择上一步的发布证书），下载 `.p7b`。
5. **签名**：在 DevEco Studio `File → Project Structure → Signing Configs` 取消自动签名，填入 `.p12`、`.cer`、`.p7b`、别名与密码；或者把这 3 个文件的 base64 与别名/密码配置成仓库 Secrets（见“自动发布”），由 GitHub Actions 签名。不要把这些文件或密码提交到仓库。
6. **APP 备案**：在中国大陆上架需要先完成 APP 备案（ICP）。在 AGC 或接入商的备案系统中提交，需要填写应用包名 `com.zhisibi.mimipanel` 以及**发布证书的公钥 / 证书 MD5 指纹**（AGC 的证书详情页可查看；本地也可用 `keytool -printcert -file 发布证书.cer` 查看）。备案通过后在 AGC 提交备案号。
7. **隐私政策网址**：AGC 的“应用信息 → 隐私政策网址”需要一个公开可访问的链接。本仓库的 `docs/privacy.md` 就是应用内同款政策：在仓库 `Settings → Pages` 选择 `main` 分支的 `/docs` 目录后，可使用 `https://zhisibi.github.io/<仓库名>/privacy.html`；未开 Pages 时也可直接使用该文件在 GitHub 上的链接。修改政策时先改 `docs/*.md`，再运行 `python3 scripts/gen-legal.py` 同步到应用内，有实质变更时递增 `entry/src/main/ets/common/Legal.ets` 里的 `PRIVACY_VERSION`，用户会被要求重新同意。
8. **构建 .app 并上传**：AGC 只接受 `.app` 包。DevEco Studio `Build → Build Hap(s)/APP(s) → Build APP(s)`，或命令行：

   ```bash
   hvigorw --mode project -p product=default -p buildMode=release assembleApp --no-daemon
   # 输出：build/outputs/default/<项目目录名>-default-signed.app
   ```

   配置了签名 Secrets 时，Release 附件里的 `MimiPanel-HarmonyOS-<版本>-signed.app` 也可以直接上传。
9. **填写上架信息**：应用名称、简介、分类、1024×1024 图标、截图、隐私政策网址、备案号等，提交审核。

当前构建配置：`compatibleSdkVersion` 为 `6.0.0(20)`（HarmonyOS 6.0 及以上可安装），`targetSdkVersion` 为 `26.0.0`，使用 SDK 26.0.0.821（Release）构建；release 包的 `debug` 为 `false`，只申请 `ohos.permission.INTERNET`。
