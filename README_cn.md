# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立收藏模块

本地 `codex/custom-favorites` 直接以固定 `master` `2fe86b737` 为基线重建，
保留 `1.9.2+566`。包含收藏标记解析、列表与详情共享的账号隔离状态、服务器结果确认、
缓存失效及备注编辑保护，使用传统收藏表单，不要求先合入其他 custom 业务模块。

从画廊卡片或详情页打开修改收藏夹。弹窗先响应，再加载原有服务器备注；用户输入优先于迟到的
备注读取。保存后以新请求确认分类，再更新彩色心形；确认失败保留之前的状态。切换账号会清除
原账号收藏信息，新账号确认的状态可同步到已挂载的卡片和详情。本地收藏保留在设备上。
标题长按沿用原有列表／滚轮表单偏好设置。

### 独立构建与验证

验证工具链为 Flutter 3.47.1、Xcode 27.0，最低 Flutter 3.41。
iOS 全部配置使用 `cn.honjow.fehv`。分支包含最小 Scene 生命周期、ARM64 Simulator 配置、
依赖锁文件和测试 SDK。构建前使用上游公开空配置：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

当前 121 项单元／组件测试通过；全量分析 0 error，相对同工具链适配后的 master 无新增诊断。
测试覆盖十种分类、缺失／异常收藏标记、请求竞争、
账号隔离、确认失败、备注加载与输入冲突、传统列表／滚轮表单，以及切换账号后已挂载卡片和详情的更新。

安装 CocoaPods、XcodeGen，启动隔离模拟器，使用唯一运行名并将输出保留在 checkout 外：

```sh
bash benchmark/favorites_ui_tests/run-native.sh   "$DEVICE_UUID" "$OUTPUT_DIRECTORY" favorites-light
xcrun simctl ui "$DEVICE_UUID" appearance dark
xcrun simctl ui "$DEVICE_UUID" content_size accessibility-medium
bash benchmark/favorites_ui_tests/run-native.sh   "$DEVICE_UUID" "$OUTPUT_DIRECTORY" favorites-dark-large
```

iPhone 和 iPad 均执行。脚本以正式 `lib/main.dart` 入口构建，仅 Debug 启用离线夹具与虚构账号，
阻断所有写操作及未知请求；从真实表单编辑后取消、切换表单样式、通过新进程重启，检查样式持久化及横屏。
隔离 iPhone 18 Pro、iPad Pro 11-inch（M5），iOS 27.0（24A434）的浅色默认字号、
深色系统 accessibility-medium 字号四组配置共 8 次原生测试通过，两阶段记录了不同的启动 PID。
不使用真实账号；关闭离线定义后的普通正式入口构建也通过。

`Debug-SimulatorUI` 排除 MLKit 和旧归档下载插件注册。真机、真实服务器写入、LiveContainer、
Release、OCR 及其他平台尚未验收。保留 master 的分类栏和固定高度传统卡片布局限制：iPad 窄栏的普通列表卡片在
accessibility-medium 字号下出现 90 像素底部溢出，收藏表单仍可操作。本功能验收不代表全部大字体布局无缺陷。本次重建不生成 IPA。

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
