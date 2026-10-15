# Eros-FE
[English](https://github.com/erosTeam/eros_fe/blob/master/README.md) | 简体中文

## 应用简介

一个 flutter 编写的 e-hentai app

## 独立可见分组索引模块

`codex/custom-group-index` 以一个完整提交直接基于固定 master `2fe86b737`，保留
`1.9.2+566`。页码按可见分组映射；重排保留当前 UUID，隐藏／删除当前分组时选择
相邻可见分组，限制恢复索引的边界，无可见分组时显示原有空态。传统分组栏与页面
使用同一份可见列表。继续使用分组栏的管理按钮重排和删除；导入配置中的隐藏标记
会得到尊重，启动时恢复上次可见索引。

全量 18 项单元／组件测试通过；分析零错误，相对同工具链 master 无新增诊断。
原生矩阵另复现“删除当前末页后元数据正确、实际内容空白”：重建视口可能恢复旧页码，
现在保留 PageView 及按 UUID 标识的子页，并断言真正显示相邻分组内容。
正式 `lib/main.dart` 有／无离线定义构建通过。最高可用 iOS 27.0（24A434）上，隔离
 iPhone 18 Pro、iPad Pro 11-inch（M5）共 12 项原生检查通过：四组浅色默认／深色
accessibility-medium 冷启动和旋转，以及每台设备的重排／删除当前分组、选择重启恢复、
仅剩隐藏分组的空态和空态重启恢复。

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
bash benchmark/group_index_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" group-index
```

使用全新隔离安装。正式入口夹具只初始化一次中性 A／B／C／D 分组，隐藏 B、选中可见 C；
之后从 Hive 恢复真实修改，不覆盖重启结果。原生检查将当前 UUID 与各分组独有的实际
画廊标题核对，不仅检查元数据。输出留在 Git 外；重排手势慢拖并停留，等待原有动画完成。

master 传统 LinkScrollBar 仍按未缩放文字测宽：无障碍大字号下会溢出，右侧标签点击可能
无效。默认字号标签点击通过，大字号的映射使用原有 PageView 横向翻页手势验证。
iPad 窄栏固定卡片仍有 90px 底部溢出和标签裁切；已记录为视觉限制，不声明视觉完全通过。
`Debug-SimulatorUI` 排除 MLKit／旧归档下载插件注册。真实云端同步、真机、Release、
LiveContainer、OCR 和其他平台未验收。不依赖玻璃、增强触感或其他 custom 业务模块，
本次不生成 IPA。

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
