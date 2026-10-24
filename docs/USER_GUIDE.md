# 工作时钟使用说明

## 1. 首次使用

- 本软件使用**本地临时签名**，**未公证**、**未进行 Developer ID 签名**，也**未上架 Mac App Store**。
- 首次启动时若遇到系统安全拦截，请在系统设置中允许运行。

## 2. 自动计时规则

- **滚动两分钟计时**：检测到键盘、鼠标或触控板操作后，会自动触发滚动两分钟计时；在两分钟内继续操作会持续顺延计时。
- **后台程序不算**：仅根据你的实际键鼠或触控板操作计时，后台程序运行不会计入工作时间。
- **不检测外部 AI 工具**：本软件**不读取、也不检测 Codex / ChatGPT 消息**。

## 3. 手动续算与自定义工作项目

- **手动续算两分钟**：当你在阅读、思考而没有操作键鼠时，可使用“电脑计时续算 2 分钟”按钮继续累计时间。
- **三个自定义手动工作项目**：在“类型设置”中选择项目，修改工作名称和每次计入的分钟数，然后点击“保存设置”。
- **记入今天**：在“今日总览”选择每个项目完成的次数，再点击“记入今天”，相应时间会加入今日总时长。

## 4. 统计与图表

- **周 / 月 / 年统计**：在“分类统计”中查看按周、月、年汇总的工作时长，也可以切换上一期、下一期或当前周期。
- **图表悬停查看**：周柱状图和近一年热图支持鼠标悬停，可以查看具体日期和准确工作时长。

## 5. 语言、启动与菜单栏

- **中文 / English 切换**：在“类型设置”页面底部选择中文或 English，切换立即生效并自动保存。
- **登录启动**：可以设置登录 Mac 时自动启动。
- **菜单栏与退出**：关闭窗口后，软件仍会在菜单栏继续运行。通过菜单栏可以重新打开界面、续算两分钟或退出软件。

## 6. 数据文件与备份

- **数据文件路径**：`~/Library/Application Support/WorkTime/work-time.json`
- **复制备份**：退出工作时钟后，直接复制该 JSON 文件即可备份。
- **重要提醒**：**软件运行时不要编辑该文件**，以免造成数据冲突、丢失或被程序覆盖。

## 7. 常见问题

**为什么首次打开时系统提示未验证开发者？**  
因为本软件仅使用本地临时签名，未公证、未使用 Developer ID 签名且未上架。首次使用时按系统提示放行即可。

**电脑后台有程序在运行，为什么没有计入工作时间？**  
计时仅由键盘、鼠标、触控板操作触发。后台程序运行不算工作时间，软件也不会读取或检测 Codex / ChatGPT。

**没有操作键盘鼠标时怎么记录工作时间？**  
可以点击“电脑计时续算 2 分钟”，或者通过三个可自定义的手动工作项目记入时间。

**怎么备份历史数据？**  
先从菜单栏退出软件，再复制 `~/Library/Application Support/WorkTime/work-time.json`。

---

# Work Clock User Guide

## First Use & Installation

Work Clock runs directly from your Mac menu bar.

Because this app uses **local ad-hoc signing**—meaning it is **not Developer ID signed**, **not Apple notarized**, and **not on the Mac App Store**—macOS may show a security warning on first use. If blocked, open **System Settings → Privacy & Security** and click **Open Anyway**, or right-click the app and select **Open**.

## How Time Tracking Works

- **Automatic Rolling 2-Minute Timer**: Whenever you use your keyboard, mouse, or trackpad, Work Clock starts or refreshes a rolling two-minute timer. As long as you stay active within two minutes, your work time continues to count.
- **Background Programs Do Not Count**: Only your physical input triggers the timer. Background programs, downloads, renders, or automated scripts do not count toward your work time.
- **Manual 2-Minute Continuation**: Use the manual two-minute continuation button when you need a short moment to read or think without touching your input devices.

## Manual Work Items

For offline tasks or work away from the keyboard, you can set up **three customizable manual work items**:

1. Open **Settings** and select one of the three items.
2. Enter a custom name and the minutes credited for each completion.
3. Click **Save**.
4. Return to **Overview**, select the completion count, and click **Add to Today**.

## Statistics & Visual Charts

- **Time Summaries**: View weekly, monthly, and yearly statistics.
- **Period Navigation**: Move to the previous or next period, or return to the current period.
- **Weekly Bars**: Check a bar chart of daily work time for the current week.
- **Last-12-Month Heatmap**: View long-term consistency across a 12-month activity grid.
- **Hover Details**: Hover over weekly bars or heatmap cells to see the exact date and work duration.

## Menu Bar Operation & Settings

- **Language Switching**: Open **Settings** and choose **中文** or **English**. The change applies immediately and is remembered after restart.
- **Launch at Login**: Turn on **Launch at Mac login** so Work Clock starts automatically when you log in.
- **Window and Menu Bar**: Closing the window does not quit the app. It continues to run in the menu bar.
- **Quitting**: Use the menu bar menu and choose **Quit** to stop the app completely.

## Local Data & Backup

All work records are stored locally at:

`~/Library/Application Support/WorkTime/work-time.json`

- **Backup**: Quit Work Clock first, then copy `work-time.json` to another folder or drive.
- **Important**: **Never edit this file while the app is running**, because the app may overwrite your changes or damage the data.

## FAQ

**Does Work Clock read or detect my Codex or ChatGPT messages?**  
No. Work Clock never reads, inspects, or detects your Codex or ChatGPT messages.

**Why don't background tasks increase my tracked work time?**  
Only active physical input counts, measured in rolling two-minute windows. Passive background tasks without physical input do not add time.

**How can I record offline work?**  
Use the three customizable manual work items, or use manual continuation for a short reading or thinking interval.

**How do I back up my data?**  
Quit Work Clock first, then copy `~/Library/Application Support/WorkTime/work-time.json` to your backup location.
