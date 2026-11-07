# 念日 · iOS

念日的原生 iOS 版本，SwiftUI 编写，iOS 17+。功能覆盖 Android 2.3.x 的主要部分，并增加锁屏小组件。

> 当前环境是 Windows，**无法在这里编译或签名 iOS App**。这是一套可在 Mac 上用 Xcode 打开的完整源码工程；最后一步需要你在 Mac 上完成。

## 快速打开

需要 macOS、Xcode 15+、iOS 17 模拟器或真机。

### 用全能签安装

1. 在 Mac 上构建无签名 IPA：

```bash
cd ~/Downloads/NianRi-iOS-1.2.0-mac
zsh scripts/build-ipa.sh
```

2. 把 `NianRi-1.2.0-unsigned.ipa` 通过 AirDrop / 文件传到 iPhone。
3. 打开全能签 → 导入 IPA → 选择证书 → 签名安装。

**锁屏小组件说明：** 小组件和 App 通过 App Group `group.com.nianri.app` 共享数据。全能签的证书/描述文件必须包含这个 App Group，并同时给 App 和 Widget 签名；普通共享证书通常没有这个能力，这时 App 可以正常用，但小组件可能显示空状态。若你的全能签支持自定义 entitlement，需要保留：

```text
com.apple.security.application-groups
group.com.nianri.app
```

并且描述文件里也要有这个 group。否则小组件无法读取 App 里的纪念日。

**如果证书没有 App Group：** 使用不依赖共享数据的「念日 · 手动倒计时」桌面小组件。长按桌面 → 左上角 + → 搜索「念日」→ 选择「念日 · 手动倒计时」→ 添加后长按组件 → **编辑小组件**，填写标题和日期即可。它每天午夜刷新，未来日期显示“还有 N 天”，当天显示“就是今天”，过去日期显示“已经 N 天”。手动版只支持桌面小/中尺寸，不支持锁屏。

### GitHub Actions 自动出 IPA（无需本地 Mac）

工程已包含 `.github/workflows/ios-unsigned.yml`。把 **这个目录作为 GitHub 仓库根目录** 上传，让 `project.yml`、`NianRi/`、`NianRiWidget/` 和 `.github/` 保持同级。

1. push 到 `main` 或 `master`
2. 打开仓库 **Actions → Build unsigned iOS IPA**
3. 进入最新一次运行，在 **Artifacts** 下载 `NianRi-iOS-1.2.0-unsigned`
4. 解压后得到 `NianRi-1.2.0-unsigned.ipa`，AirDrop 到 iPhone
5. 用全能签签名安装

打标签会自动创建 Release：

```bash
git tag v1.2.0
git push origin v1.2.0
```

Release 里会直接带无签名 IPA。

说明：

- 工作流只构建**无签名 IPA**，不会替你签名
- GitHub 的 macOS runner 需要消耗 Actions 额度；私有仓库会按 macOS 倍率计费，公开仓库通常免费，具体以 GitHub 当前政策为准
- 自动版锁屏/桌面小组件仍需要 App Groups 开发者签名；**手动倒计时小组件不受影响**
- 不要把证书、密码或 `.p12` 上传到仓库
- 如果想把 iOS 放到现有 Android 仓库的子目录，需要给 workflow 加 `working-directory`；更简单的是单独建一个 `nianri-ios` 仓库

### 没有 Mac / GitHub macOS runner 排队失败：Codemagic

GitHub Actions 的免费 macOS runner 可能长时间拿不到机器。工程已包含 `codemagic.yaml`，可以改用 Codemagic 的云端 Mac：

1. 打开 https://codemagic.io/ ，用 GitHub 登录
2. **Add application** → 选择 `nianri-ios`
3. 构建配置选择 **Codemagic YAML**
4. 选择 workflow **NianRi iOS unsigned IPA**，点 **Start new build**
5. 构建完成后在 Artifacts 下载 `NianRi-1.2.0-unsigned.ipa`

Codemagic 个人免费计划每月有 500 分钟 macOS 构建额度，不需要本地 Mac；构建产物仍然是无签名 IPA，下载后用全能签签名安装。

### 直接打 IPA（不安装模拟器）

只想要 `.ipa`、不下载模拟器 Runtime 时，用设备 SDK 构建：

```bash
cd ~/Downloads/NianRi-iOS-1.2.0-mac
zsh scripts/build-ipa.sh
```

会得到：

```text
NianRi-1.2.0-unsigned.ipa
```

无签名 IPA 不能直接双击安装，需要用自己的 Apple ID 通过 **Sideloadly / AltStore** 签名后安装。

如果有 Apple Developer Team，可以直接构建已签名版本：

```bash
TEAM_ID=你的TeamID zsh scripts/build-ipa.sh
```

得到：

```text
NianRi-1.2.0-signed.ipa
```

也可以用连接 iPhone 的方式直接安装：

```bash
xcrun devicectl list devices
xcrun devicectl device install app --device <设备ID> build/Build/Products/Release-iphoneos/NianRi.app
```

> App Group / 锁屏小组件需要正确的签名与 App Group capability。无签名 IPA 即使 Sideloadly 能装上，小组件也可能读不到共享数据。

### 全程终端（不打开 Xcode 工程界面）

```bash
cd ~/Downloads/NianRi-iOS-1.2.0-mac
zsh scripts/run-simulator.sh
```

指定其他模拟器：

```bash
zsh scripts/run-simulator.sh "iPhone 15"
```

如果有 Apple Developer Team，并希望 App 与锁屏小组件共享 App Group 数据：

```bash
TEAM_ID=你的TeamID zsh scripts/run-simulator.sh
```

脚本会执行：`xcodegen generate` → 启动 Simulator → `xcodebuild` → `simctl install` → `simctl launch` → 截图到 `screenshots/launch.png`。

注意：**iOS 的锁屏小组件无法完全通过终端添加**。编译、安装、启动、截图、看日志都可以在终端完成；最后在 Simulator 里长按锁屏 → 自定义 → 添加组件 → 搜索「念日」。这是 iOS 系统限制，不是脚本问题。

### 用 Xcode 打开

```bash
brew install xcodegen
xcodegen generate
open NianRi.xcodeproj
```

然后在 Xcode：

1. 选中 `NianRi` target → **Signing & Capabilities**，选择你的 Team。
2. 确认 `NianRi` 和 `NianRiWidget` 两个 target 都有 **App Groups**，并勾选 `group.com.nianri.app`。
3. 选择 iPhone 模拟器，运行。

如果不想安装 XcodeGen，也可以在 Xcode 新建一个 iOS App（SwiftUI、iOS 17），把 `NianRi/` 和 `NianRiShared/` 的 Swift 文件拖进去；再新建 Widget Extension，把 `NianRiWidget/` 添加进去，并按下面的小组件说明配置 App Group。

## 功能

- **首页**：纪念日 / 倒数日、照片封面、颜色、故事、每年/单次、左滑删除、每条纪念日自定义提醒时间
- **工作台**：天气（手动城市，Open-Meteo）、今日心情、每日打卡、今日一页
- **记录**
  - 日记：一天可写多篇、正文搜索、月份/心情筛选、完整阅读详情、编辑删除、删除撤销、往年今天、连续记录、本月心情分布
  - 打卡：日常 / 恋爱 / 追星、连续天数、7 天圆点、改名
  - 记账：月账单 / 年账单、分类占比、日常流水、年度柱状图、16 种支出 / 10 种收入分类、编辑
  - 生理期：周期状态、经期日历、周期分析、温馨语录与建议、历史左滑删除
  - 愿望清单：在路上的 / 已实现、编辑、完成进度
- **设置**：通知权限、数据与隐私、GitHub 反馈、作者微信、健康说明
- **小组件**：圆形、矩形、行内锁屏组件；自动桌面组件；以及无需 App Group 的「手动倒计时」桌面组件

数据保存在本机 Application Support 下的 JSON 文件中，照片保存在同目录；没有账号、广告或统计 SDK。天气只在你主动设置或刷新时联网。

## 小组件

### 自动版（需要 App Group）

在 Xcode 中：

1. `NianRi` target → Signing & Capabilities → **+ Capability → App Groups** → 添加 `group.com.nianri.app`
2. `NianRiWidget` target 做同样的操作
3. 运行 App 后，长按锁屏 → **自定义** → 添加小组件 → 搜索「念日」
4. 桌面长按 → 左上角 **+** → 搜索「念日」

支持：

- `accessoryCircular`：圆形天数
- `accessoryRectangular`：标题 + 还有几天
- `accessoryInline`：锁屏时间上方的单行倒计时
- `systemSmall`：桌面小卡片

App 每次保存纪念日会通过 App Group 把“最近一个纪念日”写入共享 UserDefaults，并调用 `WidgetCenter.reloadAllTimelines()`。如果 App Group 未配置，小组件会显示空状态，不会崩溃。

### 手动版（不需要 App Group）

> 当前 App 和 Widget Extension 的 App Group entitlement 都已移除，方便全能签/免费 Apple ID 签名。自动版小组件因此无法读取 App 数据；请使用手动版。手动版只支持标题和日期，不支持照片；照片封面是 App 内的功能。
### 手动版（不需要 App Group）

1. 长按桌面空白处 → 左上角 **+**
2. 搜索「念日」→ 选择 **念日 · 手动倒计时**
3. 添加后长按组件 → **编辑小组件**
4. 填写标题和日期

组件在每天午夜重新生成时间线，因此跨天会自动更新。标题留空时显示「念日」。日期为空时会提示长按填写。

## iOS 与 Android 的差异

- iOS 不上架 APK，也没有内置 APK 更新器；更新走 App Store / Xcode 安装
- 不集成小米 HyperOS 的提醒保活说明
- 使用 iOS 原生 `DatePicker`（滚轮/日历中可直接选年份）
- 没有 iCloud 同步；当前版本只保存在本机
- 提醒需要用户允许通知；系统可能在上午 9:00 附近按自己的节奏送达
- 没有 Android 的“下载更新校验 SHA-256”流程，因为 iOS 不允许应用内安装 IPA
- 首页支持长按卡片拖动排序，顺序会保存到本地；空状态只保留一个「写下第一个日子」，有数据时才显示底部添加入口
- 首张卡和列表都支持左滑删除，删除后 5 秒内可撤销
- 删除纪念日后底部会出现 5 秒撤销条；横版照片完整显示，留白用同图柔化背景

## 生理期提示

周期预测仅根据本机记录和周期长度估算，不用于避孕或判断是否怀孕。应用内建议是一般生活提示，不替代医生诊断。出现剧烈疼痛、异常大量出血、经期超过 7 天，或伴发热、晕厥时，请及时就医。参考 NHS 与 ACOG 公开资料。

## 目录

```
NianRi-iOS-1.2.0-mac/
  project.yml                 XcodeGen 工程配置
  NianRi/                     App 源码
    NianRiApp.swift           入口与四个底部页签
    HomeView.swift            首页、纪念日编辑、照片、长按排序
    WorkbenchView.swift       工作台、天气、心情、打卡摘要
    DiaryView.swift           日记搜索、详情、撤销、往年今天
    RecordsView.swift         记录页框架、打卡
    LedgerView.swift          月账单 / 年账单
    PeriodWishView.swift      生理期与愿望清单
    SettingsView.swift        设置、反馈、隐私
    Models.swift              数据模型、本地存储、通知
    Services.swift            天气、分类、文案
    Theme.swift               颜色、卡片、日期、左滑组件
  NianRiShared/                App 与 Widget 共享的快照
  NianRiWidget/                WidgetKit 扩展（自动版 + 手动版）
    NianRiWidget.swift        自动版小组件与 WidgetBundle
    ManualWidget.swift        手动填写标题/日期的桌面小组件
```

## 说明

这是一个源码工程，包含 AppIcon 资源；不包含开发者证书、App Store 截图和 TestFlight 配置。签名、App Group 权限和真机安装需要在你的 Mac 上完成。Android 版 `nianri` 仓库和已发布 APK 不受影响。
