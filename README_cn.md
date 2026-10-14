# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立瀑布流模块

本机 `codex/custom-waterfall` 分支直接基于 `master` 的 `2fe86b737` 重建
（2026-10-14），应用版本保留 `1.9.2+566`。这里只包含 boitar fork 的瀑布流
稳定性修复，不需要其他 custom 业务分支作为前置。上游基础介绍、功能、截图
和致谢均保留。

### 使用稳定的瀑布流列表

在“设置 → 样式 → 列表样式”选择“瀑布流”或“瀑布流 - 大”。封面尺寸缺失或
非法时使用有限的回退比例；大卡直接以真实高度布局，不再使用延迟占位卡。
分页追加及前插复用既有列表对象，未变化的画廊对象在重建时保留条目控制器。

### 独立构建和验证

需要 Flutter 3.41 或更新版本，本次工具链为 Flutter 3.47.1 / Xcode 27.0。
按上游编译说明使用公开的空白配置模板，不包含个人加密配置。所有 iOS
构建配置的应用标识为 `cn.honjow.fehv`。必要的 iOS 27 Scene 生命周期及
ARM64 Simulator 适配随本分支提供，不依赖其他业务分支。

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
# Flutter 自动迁移分析配置时，保留原基线的排除范围。
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

当前验证：29 项单元／组件测试通过，覆盖真实瀑布流卡片渲染、异常封面尺寸、
追加后控制器身份、回滑位置、横竖屏、明暗主题及 1.6 倍文字缩放。独立 ARM64
`Debug-SimulatorUI` 使用正式 `lib/main.dart`，有／无离线夹具定义均构建通过。
iPhone 18 Pro 与 iPad Pro 11-inch（M5）、iOS 27.0（24A434）共 8 次原生
XCTest 执行通过：每台设备在浅色／默认字号、深色／系统 accessibility-medium
字号下执行 2 项用例，检查重启后配置恢复、两种瀑布流、手势后的真实视口变化，
以及横竖屏回滑后卡片矩形恢复。与适配后的固定 master 比较，分析错误为零，
没有新增诊断；保留基线已有 warning／info，不扩大排除范围。

原生复现需要 CocoaPods、XcodeGen、公开空白配置以及新建并启动的隔离 iOS 27
模拟器。日志和结果目录放在仓库外，每次使用不同的运行名：

```sh
bash benchmark/waterfall_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" waterfall-light
# 在隔离设备上设置外观和系统字号后重跑：
xcrun simctl ui "$DEVICE_UUID" appearance dark
xcrun simctl ui "$DEVICE_UUID" content_size accessibility-medium
bash benchmark/waterfall_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" waterfall-dark-large
```

离线适配器提供中性的画廊 HTML 和小尺寸封面，拒绝未知 API 请求及修改请求，
仅在 debug 构建指定 `EROS_OFFLINE_ACCEPTANCE=true` 时启用。测试标识同样仅用于
调试；小瀑布流卡片原本就不显示标题。

继承的 UI 限制：未修改的 master 分类栏文字宽度测量未跟随系统缩放，大字体下
会溢出；原有固定高度的瀑布流标签行也可能裁切放大的文字。原生功能检查不表示
这些既有读屏／布局问题已修复，也不表示整个 UI 已达到发布验收条件。

`Debug-SimulatorUI` 明确跳过 MLKit 和旧下载插件的注册，仅用于隔离 UI 验收，
不能验证完整下载／OCR 或发布业务功能。真实账号、真机行为、LiveContainer
及其他未测平台不在本次验收结论内。

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
