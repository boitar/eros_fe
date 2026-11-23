# 项目协作约定

本文件是本项目的协作与 Git 操作约定。执行任何 Git 写操作前，先检查工作区状态并保留用户已有改动。

## 远端、分支与提交身份

- 远程推送只允许使用 `fork` 远端的 `custom` 分支，即 `fork/custom`。
- 禁止向 `origin` 或其他远端、其他分支推送。提交或合并前确认当前分支和上游关系；默认工作分支为 `custom`，上游为 `fork/custom`。
- 提交身份只能使用 `Codex <codex@openai.com>` 或 `boitar <49229338+boitar@users.noreply.github.com>`，不要生成其他作者或提交者身份。
- 沿用近期提交的身份习惯：由 Codex 产出的提交可使用 `Codex` 作为 Author、`boitar` 作为 Committer；由 boitar 直接完成的提交则使用 boitar 身份。

## Git 工作树

- 本项目新建的 Git 工作树统一放在 `/Volumes/nulre/DevCaches/eros_fe/worktree/` 下，每个工作树使用独立子目录。
- 确认新工作树的改动已合并回原始工作树的目标分支，并检查没有需要保留的本地改动或文件后，可用 `git worktree remove` 删除该工作树。

## 合并、提交与 tag

- 每次本地合并和每次远程提交/推送对应的迭代，都必须写清楚详情，同时创建 tag；不得只留下单行、无背景和验证信息的提交说明。
- 提交正文和 tag 说明参考近期提交，至少包含：问题背景、变更内容、验证结果、版本/发布信息、目标分支和关联 tag。
- 默认使用带说明的 annotated tag，命名沿用近期格式：`YYYY-MM-DD-<short-kebab-description>`，例如 `2026-09-18-ios-history-list-fix`。
- 远程同步时只同步到 `fork`；分支目标为 `custom`，tag 也只同步到 `fork`，不得向 `origin` 发布。

建议使用下面的说明结构：

```text
问题背景：
- ...

修复/变更：
- ...

验证结果：
- ...

发布信息：
- 版本：...
- 目标分支：custom，并同步至 fork/custom
- 关联 tag：...
```

## 打包约定

- iOS 应用的 Bundle ID 固定为 `cn.honjow.fehv`，开发、模拟器、Release 构建及交付 IPA 均使用此标识；工程配置、打包脚本与 UI 测试中的应用标识须保持一致。
- 新建并维护本机打包记录表 `打包记录.md`。该文件不加入 Git、不提交、不推送；每次迭代实际打包后追加记录，至少记录包名（含扩展名）、日期和打包串号。日期使用 `YYYYMMDD`，按 Asia/Shanghai 记录。
- **同一版本同次迭代的多端包共用同一个打包串号**：同一迭代产出的 iOS（`.ipa`）、Android（`.apk`）、macOS（`.dmg`）和 Windows（`.zip` / `.exe`）安装包必须使用相同的 `<打包串号>`（仅打包其中部分平台时同次迭代内也共用该串号），通过平台标识与扩展名区分，严禁在单次迭代内按平台拆分成多个连续串号；只有进入下一次新迭代或重打新批次时，串号才在上一轮串号基础上 `+1`。
- 默认 iOS 打包产物为无签名 IPA。开始打包前先读取 `打包记录.md`，沿用已有记录的文件名格式、版本信息和串号规则；默认不得覆盖已有包。用户明确要求沿用串号重打同平台包时，先备份原包，再替换交付包，并在打包记录中注明重打原因及备份位置。没有可参考记录时，使用 `Eros-FE_<version>-unsigned_<YYYYMMDD>_<打包串号>[-<构建来源>].ipa` 作为默认格式，实际构建来源后缀按需保留。
- 打包完成后，先确保项目根目录下的 `ipa/` 目录存在，再将 IPA 包体从构建输出移动到该目录；移动完成后以目标目录中的文件为准补写打包记录，并核对包名、日期和打包串号。
- Android APK 与桌面端安装包（Windows `.exe`、macOS `.dmg`）不再放入 `ipa/`，统一放到 `/Volumes/nulre/DevCaches/release/eros_fe/`（先确保目录存在）；同样以目标目录中的文件为准补写打包记录。`ipa/` 只存放 iOS IPA。
- 每次完成 Desktop 端（macOS / Windows）改造并构建后，默认直接将最新版本安装/更新到本机 Mac mini（`/Applications/fehviewer.app`）和 Windows 主机（`MIYUU`，通过 `~/.ssh/eros_windows_build.conf` 连接，若地址变更再核对 1Password 条目 `Eros FE - Windows SSH 构建机 - MIYUU`）；Windows 端禁止安装到 C 盘，改为按版本在 `D:\AI\eros_fe\` 下新建独立版本子目录（例如 `D:\AI\eros_fe\Eros-FE_<version>_<YYYYMMDD>_<打包串号>[-<描述>]\`，保留既有版本目录），并将开始菜单快捷方式 `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Eros-FE.lnk` 指向最新版 `fehviewer.exe`，无需等待用户手动安装；两端安装并核验完成后直接通知用户。

## 测试与交付约定

- 每次迭代交付前，必须使用本机已安装且可用的最高版本 iOS Simulator runtime 及对应模拟器设备完成测试；通过 `xcrun simctl list runtimes` 和 `xcrun simctl list devices available` 确认版本与设备，并记录设备型号、iOS 版本和测试结果。
- 最新 runtime 未安装、无法启动或测试未完成时，不得用旧版模拟器的结果替代交付依据；应先补齐或修复验证，或明确向用户报告尚未达到交付条件。

## 文档与 Git 跟踪

- 项目内新生成的 Markdown、设计说明、计划、状态、评审记录和其他迭代文档，除非用户明确要求，否则默认不加入 Git、不提交、不推送。
- 不要为了提交方便自动扩大 `.gitignore` 的范围；只对明确要求保留的项目文件进行暂存。
- 本文件是用户明确要求配置的项目协作规则，属于配置文件，不按普通迭代文档处理。

## 完成后的提醒

- 完成一次提交和合并后，必须向用户提醒并询问：本次迭代新增或调整的测试内容是否建议删除。
- 测试默认保留，不得仅因迭代完成就自动删除；只有用户明确同意后才删除，并说明删除的测试范围和理由。
