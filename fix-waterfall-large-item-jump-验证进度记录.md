# fix/waterfall-large-item-jump — 瀑布流-大跳位修复 进度记录

> 更新时间：2026-09-05 16:00 左右（本机）
> 分支：`fix/waterfall-large-item-jump`（基于 `fix/android-16-scoped-storage-crash` / c667fb31）
> 状态：**代码修复已完成并提交；静态检查全部通过；macOS release 构建成功；运行时回归验证全部完成，结论：通过 ✅**

---

## 一、代码改动（已完成，2 个提交）

### 提交 1 `165ff971` fix: stop waterfall large items jumping on scroll back

1. **`lib/pages/tab/view/list/waterfall_flow.dart`**
   - 移除 large 分支外层的 keframe `FrameSeparateWidget`（任务必改项 2 方案 A），
     直接返回 `GalleryItemFlowLarge`。
   - 连带删除了仅被该占位符使用的私有类 `_WaterfallFlowPlaceHolder` 及
     `keframe` / `theme_service` / `item_base` 三个 import。
   - 说明：占位符宽高比 bug（`(_provider.imgWidth ?? 300) / (_provider.imgWidth ?? 400)`
     恒为 1.0）随占位符一并移除——条目首帧即以真实封面比例
     `max(imgWidth/imgHeight, 1/2)`（`gallery_item_flow_large.dart:194`）布局，
     高度不再经历"占位→真身"两次变化，SliverWaterfallFlow 列簿记不再失真。
   - 普通瀑布流分支（`GalleryItemFlow`）保持原样，未改动。
2. **`lib/pages/tab/controller/tabview_controller.dart`**（任务必改项 3，选择"复用同一列表对象"方案）
   - `loadDataMore()`：`change([...?state, ...resultList])` → `state!.addAll(resultList); change(state, ...)`。
   - `loadPrevious()`：`change([...resultList, ...?state])` → `state!.insertAll(0, resultList); change(state, ...)`。
   - 每次加载更多不再生成新 List 对象。
3. **`lib/pages/tab/view/list/tab_base.dart`**
   - 删除 `getGallerySliverList` 中"计算但从未使用"的死代码
     `final _key = key ?? ValueKey(galleryProviders.hashCode);`。
   - 备注：审查发现该 key 在当前代码中并未被真正应用到任何 sliver 上
     （switch 各分支都没有传 key），所以"整树重建"的实际消除由第 2 条承担；
     该行删除同时消除了 1 条 `unused_local_variable` 告警 + 1 条命名告警。
   - 各调用方传入的 `key`（如 search 页的 sliverAnimatedListKey）行为保持原样（被忽略），
     不影响 SliverAnimatedList 等其他模式。

### 提交 2 `08995071` chore: bump version to 1.9.3+567

- `pubspec.yaml`：`1.9.2+566` → `1.9.3+567`（沿仓库惯例与 changelog 成对提交）。
- 新增 `changelog/v1.9.3+567.md`（中英双语，按 changelog/ 目录既有格式）。

### 建议项核查结果（未改动，理由如下）

- `grid.dart`：SliverGrid 单元格尺寸由 `childAspectRatio: 1/1.8` 固定，
  keframe 占位与真身同尺寸，不存在瀑布流的列簿记问题 → 无需改。
- `sliver_list.dart`：列表模式使用的 `FlutterSliverList` 自带 `onItemKey`(gid) +
  `keepPosition`，非本次 bug 范围，未动以免引入回归。

## 二、静态验证（全部通过）

| 项 | 结果 |
|---|---|
| flutter pub get | ✅（Flutter 3.41.7 stable，与 CI release.yml macos target 一致；本机原无 SDK，已装至 `~/development/flutter`） |
| flutter analyze | ✅ 基线 1605 → 修改后 1601 条（净减 4：删掉的死代码自身告警），**无新增告警**（diff 过基线比对） |
| flutter test | ✅ 仓库无 test/ 目录（任务允许） |
| flutter build macos --release | ✅ `Built build/macos/Build/Products/Release/fehviewer.app (86.5MB)` |

构建期处理（与本修复无关的环境问题）：

- `lib/config/config.dart` 是 **git-crypt 加密文件**，本 clone 无密钥（CI 用 secrets 解锁）。
  已写**本地桩**（`FeConfig.sentryDsn=null, openLapikey=null`，代码对空值已有分支）。
  ⚠️ 该桩仅存在于工作区，**绝不提交**；提交时已排除。
- `macos/Flutter/GeneratedPluginRegistrant.swift` 由 pub get 重新生成后含
  `none.register(...)` 非法代码，按 CI "Fix system_network_proxy desktop registrants"
  步骤同款 sed 修补后构建通过（该文件同样不提交，CI 会自行生成+修补）。
- 首次 CodeSign 失败（"resource fork, Finder information... not allowed"），
  `xattr -cr` 清理扩展属性后构建成功。
- CocoaPods 未安装，已 `brew install cocoapods`（1.17.0），`pod install` 成功。

## 三、运行时验证（2026-09-05 完成，全部通过 ✅）

### 环境与方法说明

- 上次受阻的屏幕捕获/像素滚动通道当日仍故障（screenshot 超时、坐标事件无光栅帧可用），
  本次改用 **AX 语义动作 `AXScrollToVisible`** 驱动列表滚动（Flutter 引擎暴露的
  ensure-visible 语义动作，走与用户滚动相同的 sliver 布局路径），效果良好。
- 证据形式为 AX 树快照对比：条目身份（标题）、语义树顺序、列 x 坐标（508/717/926，
  列宽 201，对应"自定义宽度 202 → 恰好 3 列"的 bug 场景）。
- 已知环境干扰（与修复无关，属 Flutter macOS 引擎 AX 几何实现问题）：
  - 对运行中的窗口 resize 后，旧页面语义节点的 y/height 报告退化为窗口底边钳制值
    （y=769,h=1）；重启应用后新建的页面（如搜索结果页）y/height 真实可用。
    因此证据以"条目集合 + 列归属 + 真实页面的高度对比"为准。
  - AX compact 视图按优先级排序且隐藏低优先级节点，跨快照对比一律以 full 视图为准。

### 场景 1：瀑布流-大 下滑约 2 屏 → 回滑到顶（通过 ✅）

- 重启应用（新 pid），窗口 635×620，列表顶部基线（offset 0）：
  - 列0(x=508)：Sakura fishing boat、PINKUBUS、YoruAkari Rain
  - 列1(x=717)：SAYAMINA BLOOMERS、Cornelia、Lady Mira
  - 列2(x=926)：HUWA、Misaya collection 14、RockMan Villetta
- 经 3 次 AXScrollToVisible 下滚约 2 屏（首条目变为 AI小穴图鉴，新条目
  SayaMinastuki/AI小穴图鉴/Yumenekoya/Yukikaze/カクシ盗リ/DDK00/Revy/… 依次进入），
  再回滚到顶：首屏 9 条目的集合、顺序、列归属、列宽与基线完全一致 → 无跳动、无重排。

### 场景 2：滑到列表末尾触发 load more（通过 ✅）

- 继续下滚至已加载列表末尾（止于 SecreArt MHA），再推一屏触发 load more，
  新条目 ANdoN / MOONPIE Saori-chan / MoomooDairy Tsunade & Naruto 出现。
- 完整树证实：新条目以新批次出现在文档序末尾（纯追加，无中途插入）；
  列结构不变（仍 3 列 x=508/717/926，宽 201）。
- load more 后回滚到顶：首屏与最初基线完全一致（9 条目、同序、同列、131 个语义元素
  与基线快照结构相同）→ 已有条目未因追加而重排。

### 场景 3：搜索页重复（通过 ✅，且有最直接的"高度不变"证据）

- 搜索页输入 "blue archive"（AX set_value 不会真正写入 Flutter 编辑控制器，
  改为点击聚焦 + app 级键盘输入 + Return 提交），结果页同为瀑布流-大、3 列。
- 搜索结果页为重启后新建页面，y/height 真实可用。基线（首屏）：
  - 列0：ANdoN y=276 **h=463**；6A Seeds（其下）
  - 列1：DriveShot y=276 **h=422**；Tony Welt y=709
  - 列2：朱音 Akane y=276 **h=350**；羽川莲实 y=637；Makoto Hanuma
- 下滚 2 步（新条目 stykg Cos/Ani、Kazusa、mipjeas、Zorusoru、Mayoi、Miyu 等进入）
  再回滚到顶：ANdoN **h=463**、DriveShot **h=422**、朱音 **h=350** 高度逐一相同，
  列归属相同，列内间距全部保持 11pt（唯一差异是整列统一的 8pt 停点偏移，
  为 ensure-visible 停点差异而非布局变化）→ **大条目回滑无高度变化、无跳位**，
  即修复所针对的核心症状在真实布局上未复现。

### 场景 4：其他列表模式回归（通过 ✅）

通过 设置→样式→列表样式 依次切换（共用同一 tabview_controller.loadDataMore 路径）：

- **瀑布流（小，普通）**：3 列 x=504/714/924（宽 207）。下滚 2 步回滚到顶，
  15 个条目集合与顺序与基线一致。
- **网格**：卡片网格渲染正常。下滚（追加 DDK00/Revy/ikuu/kikipig/DriveShot 等 8 项，
  顺序保持）回滚到顶，16 项与基线完全一致。
- **列表 - 中**：条目含标题/上传者/页数/日期/标签。下滚回滚到顶，5 项与基线完全一致。
- 验证结束后已把列表样式恢复为"瀑布流 - 大"。

### 结论

运行时回归验证全部通过：瀑布流-大在"下滑→回滑"与"load more 追加→回滑"两种
路径下条目身份、列归属、条目高度均保持稳定，未复现修复前的占位符比例错误
（原 bug：`imgWidth/imgWidth` 恒 1.0 导致首帧高度失真、列簿记错乱、回滑跳动）；
普通瀑布流/网格/列表模式无回归。搜索页路径亦无回归。

## 四、git 状态说明

- 已提交（本分支）：`165ff971` fix、`08995071` chore（作者/committer 均为 3003h）。
- 工作区当前未提交的本地差异（**均不应提交**）：
  - `lib/config/config.dart`（git-crypt 加密原文件 → 本地桩）
  - `macos/Flutter/GeneratedPluginRegistrant.swift`（本机再生+修补）
  - `macos/Podfile.lock`、`macos/Runner.xcodeproj/project.pbxproj`（pod install 产物）
  - `windows/flutter/generated_plugin_registrant.cc`、`generated_plugins.cmake`（再生）
  - 本记录文件
- master 分支未动。

## 五、剩余待办

1. ~~等自动化捕获通道恢复完成运行时验证~~ → 已于 2026-09-05 用 AXScrollToVisible
   语义动作方案完成全部场景（截图通道当日仍故障，证据以 AX 树快照为准）。
2. 验证通过后：`git push -u origin fix/waterfall-large-item-jump` 并开 PR（如需要）。
