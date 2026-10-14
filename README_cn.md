# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立下载模块

本地 `codex/custom-downloads` 直接以固定 `master` `2fe86b737` 为基线重建，
保留 `1.9.2+566`。包含画廊下载恢复、断点续传、队列与终态传播、封面回退和传统下载卡片，
不要求先合入其他 custom 业务分支。

### 继续下载与恢复目录

在下载页暂停、继续任务。中断传输保留 `.part` 及元数据，通过 Range/If-Range 校验续传响应，
完整后再发布正式文件。调整并发数会等待旧队列退出；文件和异步完成写入都结束后才报告成功，
已取消或被替换执行器的迟到回调不能污染新任务。

目录移走时保留数据库记录，并显示“文件暂不可用”。移回目录后点击继续／重新检查，
先认领已有正式文件，再只调度缺失图片；显式重新下载仍是单独操作。

### 独立构建与验证

验证工具链为 Flutter 3.47.1、Xcode 27.0，最低 Flutter 3.41。
iOS 全部配置使用 `cn.honjow.fehv`；Scene 生命周期、ARM64 Simulator、测试 SDK 和依赖锁文件
均包含在本分支。使用上游公开空配置模板，不加入个人加密配置：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

当前 42 项单元／组件测试通过，覆盖本地 HTTP 续传响应、正式文件保护、取消和替换任务的迟到回调、
等待完成写入、恢复队列、封面回退，以及传统卡片的主题、横竖屏和 1.6 倍字号。
其中恢复测试含 15 个文件系统场景。全量分析 0 error，相对相同工具链适配后的 master 无新增诊断，
保留既有 warning／info。

隔离 iPhone 18 Pro、iPad Pro 11-inch（M5），iOS 27.0（24A434）的四组正式 `lib/main.dart`
入口 XCTest 通过，配置为浅色默认字号、深色系统 accessibility-medium 字号。每组均检查恢复列表、
缺失文件提示、横屏、重启，以及从已完成条目打开正式本地阅读器。
两类设备还分别通过 15 个真实 Isar／文件系统恢复场景，数据均位于隔离临时目录。

安装 CocoaPods、XcodeGen，启动隔离的 iOS 27 Simulator，将证据写到 checkout 外并使用唯一运行名：

```sh
bash benchmark/downloads_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" download-light
xcrun simctl ui "$DEVICE_UUID" appearance dark
xcrun simctl ui "$DEVICE_UUID" content_size accessibility-medium
bash benchmark/downloads_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" download-dark-large
bash benchmark/downloads_ui_tests/run-recovery.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" recovery
```

`run-native.sh` 使用正式入口和仅 Debug 生效的离线夹具，阻断未知请求及写操作。
恢复专用入口另建临时数据库和目录，JSON 单独报告 15 个真实 Isar／文件系统场景，不操作用户下载记录。
两类设备均应执行；此外也检查关闭离线定义后的正式入口独立编译。

`Debug-SimulatorUI` 排除 MLKit 和旧归档下载插件注册。结果适用于 Dio 画廊下载链路，
不代表 OCR、旧归档下载、Android 实机 SAF、真机、LiveContainer、Release 或其他平台验收。
上游分类栏的大字体溢出和固定瀑布流标签行裁切仍是继承限制。本次重建不生成 IPA。

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
