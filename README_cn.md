# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立触感模块

本分支 `codex/custom-haptics` 直接基于固定 master `2fe86b737`，保留 `1.9.2+566`。
在设置 → 高级 → 震动反馈控制增强反馈；下拉刷新每轮准备并按进度发出有限 tick，
功能按钮、阅读动作、下载状态及收藏／评分结果接入反馈。独立版本使用传统界面。

iOS 六种反馈、prepare／tick 使用单功能 `eros/haptics` 原生桥接，每次请求均返回结果；
selection 沿用 Flutter 接口。关闭开关时先跳过所有增强调用和能力查询；桌面安全跳过，
缺失或异常插件安全降级。Android 保留来源时长及能力降级；未做 Android 实机验收。

工具链 Flutter 3.47.1、Xcode 27.0，Bundle ID `cn.honjow.fehv`。先复制公开空配置：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub --concurrency=1
bash benchmark/haptics_ui_tests/run-native.sh "$DEVICE_UUID" "$OUTPUT_DIRECTORY" haptics
```

独立版本 25 项全量测试通过，分析 0 error，相对同工具链适配 master 无新增诊断。
ARM64 Debug-SimulatorUI 正式 `lib/main.dart` 有／无离线定义构建通过。
最高已安装可用 iOS 27.0（24A434），隔离 iPhone 18 Pro、iPad Pro 11-inch（M5），
浅色默认字号、深色 accessibility-medium 共 12 项原生检查通过：六种反馈及 prepare/tick
实际桥接计数、真实下拉、关闭开关、重启保持关闭、重新开启及旋转。原生计数表示接受调用，
不表示设备实际产生震动。Flutter 原有刷新控件的 armed mediumImpact 独立于应用增强反馈开关，
本模块不声明控制该 SDK 既有反馈。

离线夹具仅 Debug 生效，使用隔离空账号；日志、截图及结果保留在仓库外。
Debug-SimulatorUI 不注册 MLKit／旧归档下载插件；真机震感、Release、LiveContainer、OCR、
旧归档下载及其他未测平台不在验收范围。本次不生成 IPA、不推送。
master 大字体分类栏、普通列表固定卡片和瀑布流标签行的布局限制仍保留。

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
