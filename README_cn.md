# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 本地 custom 整合

`custom` 从固定 master `2fe86b737` 起步，保留 `1.9.2+566`，当前已整合：

| 模块 | 使用方式 | 独立分支 |
| --- | --- | --- |
| 瀑布流稳定性 | 设置 → 布局 → 瀑布流／瀑布流大卡片；稳定封面尺寸、回滑及分页列表／控制器复用 | `codex/custom-waterfall` |
| 下载 | 暂停、继续或移回下载目录后重新检查，先认领已有文件再调度缺失图片 | `codex/custom-downloads` |
| 收藏 | 传统表单、服务器读回确认、账号隔离及备注编辑保护 | `codex/custom-favorites` |
| 分享 | iOS／iPadOS 链接、图片、文件和导出，处理弹层时序及展示锚点 | `codex/custom-sharing` |
| 历史 | 共享初始化、串行本地写入／清理、等待同步 | `codex/custom-history` |

每个业务分支都是直接基于同一固定 master 的完整单提交，通过显式合并保留原始提交编号。
其余六个计划业务模块尚未整合。

当前整合树 205 项测试通过；全量分析 0 error，相对适配 master 无新增诊断。
正式 `lib/main.dart` 有／无离线定义构建通过。最高可用 iOS 27.0（24A434）上，
iPhone 18 Pro、iPad Pro 11-inch（M5）另跑八项历史冷启动／顺序、旋转、清理和
新进程读取空数据库检查并通过。此前分享、收藏的整合验证记录保留在各独立分支；
真实云端账号和真机仍未验收。

### 构建与验证

工具链为 Flutter 3.47.1、Xcode 27.0（最低 Flutter 3.41），iOS 标识统一为 `cn.honjow.fehv`。
先准备上游公开空配置模板，再执行：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

原生复现使用正式 `lib/main.dart` 和仅 Debug 生效的中性离线数据。先启动隔离的 iOS 27 Simulator，
证据输出位于 checkout 外，运行名保持唯一：

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
```

各独立分支的中英文 README 记录本模块的实际检查和边界。整合树另跑测试及原生入口，
不能以来源 dev 的测试总数或安装包代替本分支验收。

`Debug-SimulatorUI` 排除 MLKit 和旧归档下载插件注册。真机、Android 实机 SAF、OCR、旧归档下载、
LiveContainer、Release 及其他未测平台不在验收范围。master 原有的大字体分类栏溢出及固定高度
瀑布流标签行裁切仍是继承限制。iPad 窄栏的固定高度普通列表卡片在系统
accessibility-medium 字号下也会溢出，收藏表单仍可操作。本次重建不生成 IPA，也不向远端发布分支或 tag。
旧 Debug 下载任务信息生成器在 master／来源中均未实现，不声明为可用导出。

历史页保留 master 固定卡片布局，iPad 窄栏 accessibility-medium 字号下仍有 29px 溢出；
历史顺序、清理及重启检查通过。

## iOS 安装
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

如果需要自行编译的话 \
复制 `lib/config.dart.sample` 为 `lib/config/config.dart` \
复制 `lib/firebase_options_sample.dart` 为 `lib/firebase_options.dart`
