# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立液态玻璃模块

本分支 `codex/custom-liquid-glass-verified` 直接基于固定 master `2fe86b737`，保留 `1.9.2+566`。
在设置 → 样式开启“iOS 液态玻璃”；可选择默认“两行展开”或“单行紧凑”顶栏，立即应用并保存。
iOS 使用 UIKit 原生玻璃导航、分类栏和弹层表面，支持系统／应用主题同步、安全区、滚动收束
及系统辅助外观；原生端按系统能力使用玻璃或传统模糊材质。关闭开关或不支持的平台保留传统界面。
顶栏横向浏览不会自动改选分类，选择、滚动和回顶通过实际当前子页同步。

本模块修复玻璃接入造成的传统导航回归：切换主标签不刷新，再次点击当前标签立即回顶，
800ms 内再点击才刷新并清空计时；超时重新按首次点击处理。玻璃模式保留当前画廊、收藏、
排行的单次重选回顶并刷新。标题仅回顶；下载／设置不新增刷新。主／子分类、导航模式变化及
销毁时清理点击序列，未挂载目标安全跳过，缓存子页不抢占当前滚动入口。
收藏恢复时同步上次的可见索引与分类标识，并处理越界值和未登录的本地收藏，保留有效的上次选择。

来源中的下载页玻璃分类栏与内容布局、通用弹窗、长按菜单、完整收藏分类与备注表单均包含在内。
收藏和下载的原有业务接口保留，独立版本不依赖增强下载、收藏状态、分组索引或触感模块；
基础反馈使用既有接口并安全降级。普通卡片在大字号下改用内容高度，正常字号保留固定高度设置。

要求 Flutter 3.47+，以使用底部原生栏按命中测试分发手势的接口，避免页面切换后
UIKit 选择手势停留在过期状态。实测工具链为 Flutter 3.47.1、Xcode 27.0，
Bundle ID `cn.honjow.fehv`：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub --concurrency=1
bash benchmark/glass_ui_tests/run-native.sh "$DEVICE_UUID" "$OUTPUT_DIRECTORY" glass
```

194 项全量测试通过；与同工具链 master 基线相比，静态分析零错误、零新增诊断。
有／无离线开关的正式 `lib/main.dart` 构建均通过。最高已安装 iOS 27.0（24A434）下，
iPhone 18 Pro（浅色／默认字号）与 iPad Pro 11-inch（M5，深色／辅助功能中号）
在最终源码上通过 10 项原生检查：传统／玻璃切换后立即选择原生分类、传统与缓存子页导航、
玻璃导航与表单、旋转、主题切换和真实进程重启。断言原生控件中心点击、实际页面、
客户端请求次数、真实内外滚动位置及首卡几何。

修正版解除已移除传统栏的控制器回调，避免原生分类选择调用旧栏的 setState 并中断实际换页；
更换控制器时转移绑定，旧栏销毁不会清除新栏绑定，包含 3 项生命周期回归测试。
原 `codex/custom-liquid-glass` 分支及 tag 保留追溯，本分支仍是直接基于固定 master 的完整单提交。

iPad 窄栏的原生底栏图标与文字保持上下排列；横屏保留窗口实际顶部安全区，灵动岛／刘海
收束仅在竖屏启用。使用中性数据与隔离模拟器，日志、截图、结果包均输出到仓库外。

离线夹具仅 Debug 生效，要求隔离账号且阻断实际修改请求。Debug-SimulatorUI 不注册
MLKit／旧归档下载插件。真机、Release、LiveContainer、OCR、旧归档下载和其他未测平台
不在验收范围。本次不生成 IPA、不推送。

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
