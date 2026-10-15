# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立历史模块

`codex/custom-history` 直接基于固定 master `2fe86b737`，保留 `1.9.2+566`。
复用初始化 Future，等待迁移与数据库读取后通知界面，并串行处理本地写入和清理。
同步等待本地初始化及已排队写入完成；画廊条目的历史控制器改为延迟取用，
不依赖其他 custom 业务模块。

独立版本全量 14 项单元／组件测试通过；分析零错误，相对同工具链 master 无新增诊断。延迟存储测试先复现四项失败：清理过早、
同步过早、初始化覆盖新访问记录，以及迟到写入在清理后回填；修复后回归通过。
正式 `lib/main.dart` 有／无离线定义构建通过。最高可用 iOS 27.0 (24A434) 上，
隔离 iPhone 18 Pro、iPad Pro 11-inch (M5) 的浅色默认／深色 accessibility-medium
冷启动顺序、横屏、清理及新进程读取空数据库共 8 项原生检查通过。

### 构建与验证

使用 Flutter 3.47.1、Xcode 27.0，最低 Flutter 3.41，应用标识为 `cn.honjow.fehv`。
准备公开空配置：

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
bash benchmark/history_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" history
```

使用隔离 iPhone／iPad 实例测试浅色默认字号和深色系统 accessibility-medium 字号；
先完成有记录的列表检查，再执行清理。
原生脚本按既有配置将历史作为首个标签，从正式入口检查真实 Isar 记录和顺序、横屏，
通过原有确认框清理，再重启读取空数据库。仅 Debug 存在的就绪标识来自真实初始化完成，
避免把尚未加载的空白帧当作清理成功；种子标记防止重启重新生成已清理的测试记录。
所有输出留在 Git 外。

master 原有固定高度历史卡片在 iPad 窄栏的 accessibility-medium 字号下仍有 29px 底部溢出。
本数据模块保留该布局；初始化、顺序、清理及重启检查仍通过。

`Debug-SimulatorUI` 排除 MLKit 和旧归档下载插件注册。离线检查不覆盖真实云端账号、真机、
Release、LiveContainer、OCR 或其他平台。本次不生成 IPA。

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
