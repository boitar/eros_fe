# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立分享模块

`codex/custom-sharing` 直接从固定 master `2fe86b737` 重建，保留 `1.9.2+566`。
画廊链接、阅读器图片、种子、快速搜索导出、下载 ZIP／EPUB、应用配置和日志导出接入统一分享服务。
iOS／iPadOS 通过本分支自带的原生插件展示 UIKit 分享面板，其他平台保留 share_plus 路径。

分享等待 Flutter 弹层关闭，再寻找可用原生展示控制器，使用非空窗口坐标锚点，并阻止重复请求。
取消后释放操作锁。原生失败会提示错误；文字／链接可回退为复制所提供的内容。
应用配置导出沿用既有移除个人用户信息的处理。

### 独立验证

当前候选版本 23 项单元／组件测试通过，覆盖文字／URI 元数据、图片和文件路径、异常锚点、
重复请求、取消、失败回退、已卸载上下文、弹层关闭时序、完整归档输出及进度对话框成功／失败／取消。
iOS ZIP／EPUB 导出在无 Android 外部缓存时使用应用临时目录，等待归档写完；
失败退出进度框，取消后的迟到回调不再关闭其他页面。全量分析 0 error，
相对同工具链适配 master 无新增诊断；有／无离线定义的正式 `lib/main.dart` ARM64 Simulator 构建通过。
隔离 iPhone 18 Pro、iPad Pro 11-inch（M5），iOS 27.0（24A434）的浅色默认／深色
accessibility-medium 四组配置共 16 项正式入口 XCTest 通过，覆盖链接取消后重开、
配置文件、阅读器图片和 ZIP／EPUB 导出。两类设备实际生成的归档均通过目录项和 CRC 核对。
iPad 系统辅助功能快照曾超时，同入口重启隔离模拟器后通过，失败证据保留。

工具链为 Flutter 3.47.1、Xcode 27.0、CocoaPods、XcodeGen，最低 Flutter 3.41，
iOS 标识为 `cn.honjow.fehv`。准备公开空配置，解析依赖时保留分析规则：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
bash benchmark/sharing_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" sharing-light
```

使用隔离 iPhone、iPad，另跑深色和系统 accessibility-medium 字号；运行名唯一，输出位于 checkout 外。
原生脚本通过新进程打开正式入口，验证画廊链接分享、取消后重开、应用配置文件导出，
以及关闭 Flutter 弹层后的本地阅读器图片分享和 ZIP／EPUB 导出；取消系统分享，不向任何收件人发送内容。
仅 Debug 启用中性本地文件和空账号夹具，未知 HTTP 请求及写操作均被阻断。

旧 Debug 下载任务信息生成器在 master 和来源快照中均未实现；本模块只迁移其分享调用，
不把该生成器声明为可用导出。

`Debug-SimulatorUI` 排除 MLKit 和旧归档下载插件注册。真机、接收应用、实际对外发送、
LiveContainer、Release、OCR 及其他平台未验收；本次不生成 IPA，不远程发布。

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
