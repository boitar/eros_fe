# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立网格标签模块

本分支 `codex/custom-grid-tags` 直接基于固定 master `2fe86b737`，保留 `1.9.2+566`。
在设置 → 样式 → 列表样式选择“网格 - 标签”，也可为自定义分组单独选择。
相同列宽下，卡片为封面、标题、标签和元信息保留一致空间；无标签、长标题和不同封面比例
不会改变同排卡片高度。标签支持两行横向浏览。原有封面、分类、收藏标记、数量和操作入口保留。
在“自定义宽度”中选择网格标签模式，单独调整其宽度；设置立即更新预览并持久化，
与普通网格、瀑布流各自保存。

工具链 Flutter 3.47.1、Xcode 27.0，Bundle ID `cn.honjow.fehv`：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub --concurrency=1
bash benchmark/grid_tags_ui_tests/run-native.sh "$DEVICE_UUID" "$OUTPUT_DIRECTORY" grid-tags
```

23 项全量测试通过，分析 0 error，相对同工具链适配 master 无新增诊断；
正式 `lib/main.dart` ARM64 Debug-SimulatorUI 有／无离线定义构建通过。
最高已安装可用的 iOS 27.0（24A434），隔离 iPhone 18 Pro、iPad Pro 11-inch（M5）
浅色默认字号／深色 accessibility-medium 共 12 项正式入口原生检查通过：等高卡片、横屏、
实际模式切换、真实宽度滑块改值和精确数值的进程重启恢复。

离线数据仅 Debug 生效，使用隔离空账号。先启动最高 runtime 的空白隔离设备，再运行原生脚本；
日志、截图和结果输出到仓库外。本模块不依赖玻璃、收藏状态、历史或增强触感模块。
Debug-SimulatorUI 不注册 MLKit／旧归档下载插件；真机、Release、LiveContainer、OCR、
旧归档下载和其他未测平台不在验收范围。本次不生成 IPA、不推送。
master 传统顶栏在 iPad 窄栏 accessibility-medium 下仍有约 22px 溢出；该顶栏未随网格模块修改。
网格卡片、设置与恢复检查通过。

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
