# Eros-FE
[English](./README.md) | 简体中文

## 应用简介

一个使用 Flutter 编写的非官方 E-Hentai 客户端。

## 相比 master 的 fork 增强

本 fork 基于 Eros-FE 上游 master，重点增强 iOS／iPadOS 体验：整合原生液态玻璃导航、
网格标签，并改进下载恢复、收藏、分享、历史、头像、触感与操作无障碍语义。

`custom` 从固定 master `2fe86b737` 起步，保留 `1.9.2+566`，整合以下 11 个可独立交付的模块：

| 模块 | 使用方式 | 独立分支 |
| --- | --- | --- |
| 瀑布流稳定性 | 设置 → 布局 → 瀑布流／瀑布流大卡片；稳定封面尺寸、回滑及分页列表／控制器复用 | `codex/custom-waterfall` |
| 下载 | 暂停、继续或移回下载目录后重新检查，先认领已有文件再调度缺失图片 | `codex/custom-downloads` |
| 收藏 | 传统／玻璃表单、服务器读回确认、账号隔离及备注编辑保护 | `codex/custom-favorites-verified` |
| 分享 | iOS／iPadOS 链接、图片、文件和导出，处理弹层时序及展示锚点 | `codex/custom-sharing` |
| 历史 | 共享初始化、串行本地写入／清理、等待同步 | `codex/custom-history` |
| 可见分组索引 | 可见 UUID／页面对应、重排／删除和重启恢复 | `codex/custom-group-index` |
| 操作语义 | 传统控件操作标签，排除无效装饰前缀 | `codex/custom-accessibility` |
| 触感 | 原生桥接、渐进下拉、应用开关及操作反馈 | `codex/custom-haptics` |
| 头像 | 相册／文件／URL、论坛验证重试、本机预览与安装后路径恢复 | `codex/custom-avatar` |
| 网格标签 | 等高卡片、两行横滑标签、独立宽度和恢复 | `codex/custom-grid-tags` |
| 液态玻璃 | 设置 → 样式：原生导航、双行／单行顶栏、弹窗、安全区和滚动同步；修复玻璃接入造成的传统导航回归 | `codex/custom-liquid-glass-verified` |

表中每个正式交付业务分支都只有一个直接基于固定 master 的完整提交。原有按序的十次非快进
合并全部保留，随后显式合入收藏修正版，再合入玻璃，保留全部 11 个正式独立提交编号。
正式模块分支、整合分支 `custom` 及对应的带说明 tag 已发布到 `boitar/eros_fe`。
旧收藏、旧玻璃分支及 tag 仅在本地保留用于追溯，不作为当前交付分支发布；独立投递使用
表中的 verified 修正版。网格标签的当前独立 tag 为
`2026-10-15-custom-grid-tags-independent-verifier`，不是旧的
`2026-10-15-custom-grid-tags-independent`。

组合接入保留收藏与头像的账号／版本保护、下载恢复保护、
可见分组 UUID 对应以及历史数据操作的串行时序。共享启动入口在界面订阅收藏状态前完成账号
初始化，覆盖已保存玻璃模式下的冷启动。

完整整合树于 2026-10-16 通过全量 486 项测试；相对同工具链 master 基线，静态分析零错误、
无新增诊断。
正式 `lib/main.dart` 的 7 个 ARM64 Debug-SimulatorUI 版本构建通过，包含有／无离线定义构建。
在最高已安装且可用的 iOS 27.0（24A434）上，iPhone 18 Pro 和 iPad Pro 11-inch（M5）
通过 10 项导航／表单检查、玻璃与收藏、头像、可见分组索引、触感、下载的 30 项组合检查，
以及 2 项传统界面冷启动先设置后收藏检查，共 42 项原生用例。
手机使用浅色默认字号，iPad 使用深色 accessibility-medium 字号；每个组合均验证实际原生
玻璃导航已启用，重启阶段读取应用持久化状态。

2026-10-17 发布前，另在 iPhone 18 Pro 和 iPad Pro 11-inch（M5）上补跑 4 项原生冒烟检查，
均使用相同的 iOS 27.0 运行时及源码一致的正式入口构建。两个设备均通过冷启动先进入设置再
进入收藏、导航模式切换后点击原生分类的检查；这不代表重新执行了一次完整的 486 项测试。

完整收藏独立修正版通过 121 项测试、2 种正式入口构建及 6 项冷启动／表单／重启原生检查。
启动账号初始化包含在这个可独立运行的模块内，并通过修复合并进入 custom。
玻璃独立修正版通过 194 项测试及最终源码的 10 项原生检查，包含模式切换后立即点击原生分类；
回归覆盖传统重选时序、缓存／当前子页、真实滚动位置、刷新次数、
模式切换、不支持平台回退与销毁；普通画廊卡片支持随大字体增高。各业务分支记录自身早期验收。

### 2026-10-18：画廊图片保存到相册

版本保持 `1.9.2+566`。修复 tag 为 `2026-10-18-gallery-save-cache`，
`custom` 整合 tag 为 `2026-10-18-custom-gallery-save-cache`。

- 长按图片和工具栏的保存菜单统一为“保存当前图片／保存原图”。当前图片优先复用本地、
  临时文件或与浏览器一致的缓存 key；缓存可用时无需联网。选择原图只复用已确认属于原版的文件，
  否则通过原图入口下载；不以“优先原图”设置推断实际画质。
- 固定弹出菜单时的图片来源，避免翻页后保存错图；原图入口缺失或确认来源相同时不显示重复选项。
  下载按图片身份与画质隔离，验证状态、长度和图片内容后才使用完成文件，不再误取公共临时目录文件。
- iOS 通过 PhotoKit 以仅添加照片权限导入编码文件，保留系统支持的格式、透明度和动画。
  区分权限拒绝、无效文件、下载、格式和相册写入错误；写入完成后才提示成功，并阻止并发保存。
- 全量 511 项测试、最终相关功能 38 项测试通过；相对相同源码基线无新增静态诊断。
  最高已安装可用 iOS 27.0（24A434）／iPhone 18 Pro 验证缓存保存零下载、原图下载与复用、
  拒绝添加权限不写入相册，以及 HTML／HTTP 错误分类；相册 PNG、JPEG、GIF 与源文件 SHA-256 一致。
- 正式 `lib/main.dart` 的模拟器构建、Release arm64 无签名构建及本机 IPA 串号 67 包体检查通过。
  IPA 为本机交付，未随源码上传到仓库或 GitHub Releases；版本号未递增。
  LiveContainer 真机宿主权限和容器内保存、Android 真机仍待验收；模拟器结果不替代这些验收。

### 2026-10-26：收藏表单兼容与保存确认修复

版本保持 `1.9.2+566`。修复 tag 为 `2026-10-26-favorite-form-fix`；
`custom` 合入及 Release tag 为 `2026-10-26-custom-favorite-form-fix`。

- 匿名 EH／EX 对照确认 multipart 文本表单触发行政规则 HTTP 403 后，收藏提交改用
  普通 URL 编码表单。归档下载（本地／H@H）、My Tags、站点设置／个人资料及评论
  同步修正已验证的同类编码问题；论坛登录与文件上传保留原编码。
- 保存必须通过新鲜服务端回读确认目标分类及完整备注后，才更新共享收藏状态；
  删除必须确认服务端明确未收藏，不再将弹窗默认分类 0 当作保存成功依据。
- 每次操作只发送一次 POST；不确定结果仅有限回读，不重复写入。登录跳转、验证页及
  HTTP 拒绝显示简短错误，并保留账号／版本守卫，阻止迟到结果覆盖当前状态。
- Flutter 全量 554 项通过，静态分析零错误、零警告。iOS 27.0（24A434）上的
  iPhone 18 Pro 与 iPad Pro 11-inch (M5) 传统／液态玻璃共 8 项原生用例通过，
  覆盖分类 0／7、备注编辑／清空、列表刷新、进程重启、删除及 HTTP 403 拒绝；
  正式入口干净安装、启动及进程存活检查通过。发布前在本机最高已安装可用的
  iOS 27.1（24A94425）／iPhone Duo 补充传统、玻璃及重启／拒绝共 4 项用例通过；
  测试驱动使用卡片可见上部区域长按，避开原生底栏覆盖。
- Release 复用 2026-10-23 构建的已校验 arm64 无签名 IPA 串号 68，应用源码一致，
  使用公开配置样例且无验收 define。真实账号及 LiveContainer 验收仍待完成；
  匿名协议对照与合成服务 UI 用例不能替代该项结论。

### 构建与验证

工具链为 Flutter 3.47.1、Xcode 27.0；原生公开手势策略要求最低 Flutter 3.47.0。
iOS Bundle ID 统一为 `cn.honjow.fehv`。首次检出代码后，先根据上游公开示例准备本机配置，再执行：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

原生复现使用正式 `lib/main.dart` 和仅 Debug 生效的中性离线夹具。先启动隔离的 iOS 27
模拟器，将验证结果输出到代码目录之外，运行名保持唯一，各验收串行执行：

```sh
mkdir -p "$OUTPUT_DIRECTORY/harness"
bash benchmark/waterfall_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" waterfall
bash benchmark/downloads_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" downloads
bash benchmark/downloads_ui_tests/run-recovery.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" recovery
bash benchmark/favorites_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" favorites
bash benchmark/sharing_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" sharing
bash benchmark/history_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" history
bash benchmark/group_index_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" group-index
bash benchmark/accessibility_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" accessibility
bash benchmark/haptics_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" haptics
bash benchmark/avatar_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" avatar
bash benchmark/grid_tags_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" grid-tags
bash benchmark/glass_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" glass
```

玻璃组合复现时，在收藏、头像、分组索引、触感或下载的原生命令前添加 `EROS_VERIFY_GLASS=1`。
该模式通过真实设置启用玻璃并断言原生导航，不向业务夹具混入玻璃种子数据；每个用例日志中的
`EROS_CROSS_GLASS_ACTIVE` 证明已启用。
额外冷启动回归使用新安装的收藏夹具，执行
`benchmark/favorites_ui_tests/verify-installed.sh`，依次传入设备、仓库外输出目录、唯一运行名和
第四个参数 `bootstrap`；该传统入口检查不设置 `EROS_VERIFY_GLASS`。

真实论坛上传和在线 Cloudflare 尚未验收；本地 HTTP 覆盖认证、多部分表单上传请求、错误、
403 及验证重试。
操作语义标签保留来源中文，模拟器检查不代表真机 VoiceOver 播报／焦点验收。原生触感接受调用
计数不代表真实震动或强度；Flutter 原有下拉刷新反馈仍独立于增强触感开关。

`Debug-SimulatorUI` 排除 MLKit 和旧归档下载插件注册。真机、Android 实机 SAF、OCR、旧归档下载、
LiveContainer、Release 及其他未测平台不在验收范围。master 的传统分类顶栏在 iPad 窄栏、
accessibility-medium 字号下仍有约 22px 溢出，固定高度瀑布流标签仍可能裁切；
未缩放测宽的传统分组栏在无障碍字号下可能使右侧标签点击无效，映射使用
既有 PageView 手势验证。未改动的历史卡片在 iPad 窄栏 accessibility-medium 下保留 29px 溢出。
旧 Debug 下载任务信息生成器在 master／来源中均未实现。

## iOS 安装

本次 fork 发布仅包含源码，不提供本 fork 的 IPA。下方 Releases 链接指向上游构建，
不包含这里列出的 custom 增强功能。

1. 下载最新 ipa 文件 [Releases](https://github.com/erosTeam/eros_fe/releases/latest).
2. 使用 [AltStore](https://altstore.io) 之类的 app 安装到设备上. 或者直接使用 [AltStore.json](https://config-feh.vercel.app/AltStore.json)


## 说明

UI 方面主要参考的[E-HentaiViewer](https://github.com/kayanouriko/E-HentaiViewer)


## 问题

**滑动掉帧**

- 一部分是flutter问题，一部分是开发水平问题，只能说尽力优化

## 感谢

应用借鉴和参考以下项目的部分代码和逻辑进行开发

- [E-HentaiViewer](https://github.com/kayanouriko/E-HentaiViewer)
- [EhViewer](https://github.com/seven332/EhViewer)

ehentai译文数据库

- [EhTagTranslation/Database](https://github.com/EhTagTranslation/Database)

翻译
- [KeepSOBP](https://github.com/KeepSOBP) -- 韩语翻译
- [pursel](https://github.com/pursel), [Gigas002](https://github.com/Gigas002) -- 俄语翻译
- [cristal-node](https://github.com/cristal-node) -- 日语翻译

## 应用截图

### 主页列表

<img width="200" src="./screenshot/home.png" >

### 设置

<img width="200" src="./screenshot/setting.png" >

### 画廊

<img width="200" src="./screenshot/gallery1.png" > <img width="200" src="./screenshot/gallery2.png" > 

### 搜索

<img width="200" src="./screenshot/search1.png" > <img width="200" src="./screenshot/search2.png" >

### 阅读

<img width="200" src="./screenshot/read1.png" > <img width="200" src="./screenshot/read2.png" >

## 功能

- [x] 热门,关注,主页,收藏
- [x] 自定义分组，组合多种条件，分组独立样式
- [x] 列表视图,瀑布流视图,网格视图等切换
- [x] 浅色深色模式
- [x] 画廊信息查看
- [x] 图片浏览
- [x] 自动翻页
- [x] 里站表站切换
- [x] 搜索，高级搜索，图片文件搜索
- [x] 标签翻译，自动匹配标签搜索
- [x] 用户登录
- [x] 缓存优化
- [x] 高级设置
- [x] 生物认证锁定
- [x] 发表评论，对评论赞和踩，评论翻译
- [x] 评论显示论坛头像，快速@回复(带锚点)，自动显示引用评论
- [x] EH设置，同步网站
- [x] Mytag设置，编辑关注、隐藏、颜色、权重等。长按Tag快速设置
- [x] 下载，下载原图，归档包下载，直接阅读已下载
- [x] WebDAV同步历史，快速搜索，阅读进度，分组配置
- [x] 可屏蔽带二维码的图片。可标记广告图片，记录pHash值，后续屏蔽相似图片


## TODO


## 依赖项目/插件（部分）

- 网络 [dio](https://pub.dev/packages/dio)
- 状态管理 [getx](https://pub.dev/packages/get)
- 数据库 [sqflite](https://pub.dev/packages/sqflite)
- 持久化 [shared_preferences](https://pub.dev/packages/shared_preferences)
- 国际化 [intl](https://pub.dev/packages/intl)
- 图片 [cached_network_image](https://pub.dev/packages/cached_network_image)、[extended_image](https://pub.dev/packages/extended_image)

## 编译相关

请使用前文[构建与验证](#构建与验证)中已验证的 Flutter／Xcode 版本和配置步骤，
不要直接使用版本未指定的最新 SDK。
