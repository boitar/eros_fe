# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立头像模块

本分支 `codex/custom-avatar` 直接基于固定 master `2fe86b737`，保留 `1.9.2+566`。
在设置 → E·H → 上传头像选择相册、文件或图片 URL，再选择上传论坛或仅本机使用。
独立版本使用传统弹窗。文件入口打开系统文档选择器；相册入口打开系统照片选择器。
支持实际解码通过的 JPEG、PNG、GIF、WebP，大小为 1 字节至 9 MB。
本机头像使用账号所属的独立持久化副本，支持预览、重启恢复和 iOS 更新后的数据容器路径恢复。URL 仅接受无内嵌凭据的
HTTP(S) 地址，下载图片不携带论坛 Cookie。切换账号和迟到结果不会覆盖当前头像，
更新头像资料也不会重建收藏缓存或覆盖更新过的收藏分类。

上传使用论坛会话和实际表单；只有确认响应才报告成功。遇到 Cloudflare 验证时，
在应用内论坛页面完成验证、等待验证 Cookie 同步后最多重试一次；取消或不完整验证不重试。
真实论坛上传和 Cloudflare 在线链路尚未验收；本次使用本地 HTTP 服务覆盖认证、
表单上传、错误／空响应、403、重试与账号竞争。

工具链 Flutter 3.47.1、Xcode 27.0，Bundle ID `cn.honjow.fehv`。复制公开空配置后执行：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub --concurrency=1
bash benchmark/avatar_ui_tests/run-native.sh "$DEVICE_UUID" "$OUTPUT_DIRECTORY" avatar
```

41 项全量测试通过，分析 0 error，相对同工具链适配 master 无新增诊断。
正式 `lib/main.dart` ARM64 Debug-SimulatorUI 有／无离线定义构建通过。
原生验收使用最高已安装可用的 iOS 27.0（24A434）、隔离 iPhone 18 Pro 和
iPad Pro 11-inch（M5），分别检查浅色默认字号、深色 accessibility-medium、旋转与重启。
共 16 项原生检查通过，覆盖 URL／相册／实际文件选择、输入失败、取消、本机预览、
旋转、重启及重复安装后的头像路径恢复。

验收夹具仅 Debug 生效，限隔离账号；运行原生脚本前启动最高可用 runtime 的空白隔离设备，
脚本会导入中性图片并安装应用。日志、截图、结果写入仓库外。
Debug-SimulatorUI 不注册 MLKit／旧归档下载插件；真机、Release、LiveContainer、OCR、
旧归档下载与其他未测平台不在验收范围。本次不生成 IPA、不推送。

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
