# 工作时钟 / Work Clock for macOS

**版本 / Version:** 1.4.0 (Build 10)  
**平台 / Platform:** macOS 14+ (Native AppKit)

[中文说明](#中文说明) | [English](#english)

---

## 中文说明

**工作时钟（Work Clock for macOS）** 是一款纯本地运行的 macOS 原生 AppKit 工作时间记录与统计工具。它通过检测用户的实际输入活动来计算有效工作时长，并提供直观的数据统计与年度热图展示。

### 核心功能

- **主动输入自动计时**：检测到鼠标、触控板或键盘活动后自动开始或继续计时；若 2 分钟内没有新的主动操作，计时自动停止。
- **排除后台干扰**：仅统计用户真实交互，后台程序自行运行不会触发计时。
- **手动续算时长**：支持手动点击按钮续算 2 分钟工作时长。
- **自定义手动项目**：支持记录 3 种可自定义的手动工作项目，每个项目均可修改名称及单次增加的分钟数。
- **今日目标与本周日均**：内置今日 10 小时进度目标展示，并实时计算本周日均工作时长。
- **多维度分类统计**：支持按周、月、年查看分类工作时长统计。
- **近一年活动热图**：提供近一年的工作时长热图，支持鼠标悬停查看每日详细数据。
- **双语即时切换**：支持中文 / English 界面即时切换，并自动记住语言偏好。
- **开机自启**：支持配置登录 Mac 时自动启动。

### 隐私与数据安全

- **纯本地存储**：所有统计数据与配置仅保存在本地路径 `~/Library/Application Support/WorkTime/work-time.json`，不会上传至服务器，无需联网即可完整使用。
- **无第三方内容读取**：此版本仅检查基础输入活跃状态，**不读取、不检测任何 Codex 或 ChatGPT 消息内容**。

### 系统要求

- macOS 14.0 或更高版本
- Xcode Command Line Tools（仅从源码构建时需要）

### 从源码构建

1. 确保已安装 Xcode Command Line Tools：

   ```bash
   xcode-select --install
   ```

2. 进入源码目录并执行构建脚本：

   ```bash
   cd 01_source
   ./build.sh
   ```

3. 构建完成后，生成的应用位于：

   ```text
   02_build/工作时钟.app
   ```

### 签名与安装说明

- 当前构建版本采用**本地临时签名（Ad-hoc Signing）**。
- 本项目**未进行** Apple 公证，**未使用** Developer ID 正式签名，也**未上架** Mac App Store。
- 若首次打开时遇到 macOS Gatekeeper 提示，可在“系统设置 → 隐私与安全性”中手动允许运行，或在本地自行执行构建脚本生成应用。

---

## English

**Work Clock for macOS (工作时钟)** is a local-only, native macOS AppKit application designed to track and visualize your active working time. It measures actual user interaction rather than idle screen time, paired with multi-dimensional statistics and a yearly activity heatmap.

### Features

- **Active Input Tracking**: Starts or continues timing upon detecting mouse, trackpad, or keyboard activity; automatically pauses if no new active input occurs within 2 minutes.
- **No Background False Positives**: Processes running on their own in the background do not trigger or extend the timer.
- **Manual Time Extension**: Continue the timer for 2 minutes with a single manual click.
- **Customizable Manual Tasks**: Record up to 3 customizable manual work items, each with a configurable name and minutes-per-completion value.
- **Daily Goal & Weekly Average**: Tracks daily progress toward a 10-hour target and calculates your daily average for the current week.
- **Categorized Statistics**: View categorized breakdowns of your working time by week, month, and year.
- **Yearly Heatmap**: Visualizes the past year's activity in a heatmap with interactive hover tooltips for daily details.
- **Instant Bilingual Switch**: Switch between Chinese (中文) and English on the fly, with your language preference automatically saved.
- **Launch at Login**: Supports starting automatically when you log in to your Mac.

### Privacy & Data Storage

- **100% Local Data**: All data is stored exclusively on your device at `~/Library/Application Support/WorkTime/work-time.json`. No data is uploaded or shared over the network.
- **No Codex/ChatGPT Inspection**: This version does **not** read, monitor, or detect Codex or ChatGPT messages.

### Requirements

- macOS 14.0 or later
- Xcode Command Line Tools (required for building from source)

### Build from Source

1. Make sure Xcode Command Line Tools are installed:

   ```bash
   xcode-select --install
   ```

2. Navigate to `01_source` and run the build script:

   ```bash
   cd 01_source
   ./build.sh
   ```

3. The compiled application bundle will be output to:

   ```text
   02_build/工作时钟.app
   ```

### Code Signing Notice

- The application is currently built using **local ad-hoc signing**.
- It is **not** notarized by Apple, **not** signed with a formal Developer ID certificate, and **not** distributed via the Mac App Store.
- If macOS Gatekeeper blocks the app on first launch, you can allow it in **System Settings → Privacy & Security**, or build the app locally from source using `./build.sh`.

For detailed instructions, see [docs/USER_GUIDE.md](docs/USER_GUIDE.md).
