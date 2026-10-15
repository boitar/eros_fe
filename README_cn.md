# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立操作语义模块

`codex/custom-accessibility` 以一个完整提交直接基于固定 master `2fe86b737`，保留
`1.9.2+566`。为传统画廊、收藏和搜索页面补充 20 项既有操作语义：搜索、回顶／跳转、
分组管理、收藏排序／选择、以图搜图／筛选、桌面刷新、快速搜索、清空输入及打开画廊链接。
标签沿用来源的中文措辞，保留既有回调及指针点击行为。搜索框前的装饰图标维持外观和
空回调，但从语义树排除，避免读出点击后没有动作的“搜索按钮”。

全量 13 项单元／组件测试通过；分析零错误，相对同工具链 master 无新增诊断。
先复现装饰图标的伪按钮，再验证修复；组件测试核对语义点击动作及搜索编辑、URL 输入、
桌面刷新、收藏导航的原回调，并覆盖大字号和深色主题。正式 `lib/main.dart` 有／无
离线定义构建通过。最高可用 iOS 27.0（24A434），隔离 iPhone 18 Pro、iPad Pro 11-inch
（M5）的浅色默认／深色 accessibility-medium 四组共 8 项原生检查通过：实际打开分组管理、
跳转和搜索，横竖屏检查操作标签，清空输入，URL 输入显示对应操作而非加入快速搜索。

### 构建与验证

使用 Flutter 3.47.1、Xcode 27.0（最低 Flutter 3.41），应用标识为 `cn.honjow.fehv`。
准备上游公开空配置：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
bash benchmark/accessibility_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" accessibility
```

使用隔离 iPhone／iPad 安装，分别设置浅色默认、深色 accessibility-medium。
仅 Debug 生效的夹具从正式入口配置中性离线 HTTP 响应，不使用登录账号；测试读取实际
Flutter／原生语义并触发原有控件，证据留在 Git 外。不依赖玻璃、增强触感或其他 custom
业务模块。中文标签沿用来源，未新增其他语言翻译。XCTest 不代表 VoiceOver 实际朗读或
真机焦点手势验收；以图搜图／OCR、真实账号操作、Release、LiveContainer 及其他未测平台
不在范围内。master 原有大字号栏／卡片布局限制保留。`Debug-SimulatorUI` 排除 MLKit 和
旧归档下载插件注册；本次不生成 IPA。

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
