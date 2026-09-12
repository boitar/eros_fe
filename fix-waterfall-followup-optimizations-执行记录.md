# fix/waterfall-followup-optimizations — 优化修复清单执行记录

> 更新时间：2026-09-05
> 分支：`fix/waterfall-followup-optimizations`（基于 `fix/waterfall-large-item-jump` / 08995071）
> 依据：[fix-waterfall-large-item-jump-优化方案.md](fix-waterfall-large-item-jump-优化方案.md) 全部 8 项
> 状态：**代码项全部完成并通过 analyze 基线与 flutter test；P1-1 完成排查（修复按方案门槛待运行时验证）；P1-2 输出测量协议（需真机）**

---

## 一、总览

| 项 | 内容 | 状态 |
|---|---|---|
| P0-1 | 封面尺寸缺失比例守卫 | ✅ 完成（含测试） |
| P0-2 | 自动化回归测试基建 | ✅ 完成（test/ 15 用例全绿 + 变异验证） |
| P0-2 第 3 项 | analyze 基线比对脚本化 + CI | ✅ 完成（scripts/ + workflow） |
| P1-1 | loadPrevious 前插路径排查与锚定 | ✅ 排查 + 运行时验证完成（跳位实锤）；修复决策见 §三.3 |
| P1-2 | keframe 移除后帧预算测量 | ✅ 测量完成（macOS profile 真实帧耗时，两版对比数据见 §四），结论：维持现状 |
| P2-1 | 顶栏图标按钮补语义标签 | ✅ 完成（画廊/收藏/搜索三处顶栏 + 搜索框前后缀共 20 个控件），并经运行时 AX 树复核（按钮均以功能名可读） |
| P2-2 | 搜索输入框语义提交通路 | ✅ 核验完成：代码已满足，无需改动（§五） |
| P3-1 | 普通瀑布流 `_getHeight` 分支守卫 | ✅ 完成 |
| P3-2 | item builder 内 Get 注册短路 | ✅ 完成（身份守卫版，见 §六风险说明） |

## 二、代码改动明细

### P0-1 封面尺寸缺失比例守卫

- 新建 `lib/pages/item/cover_ratio.dart`：
  - `kDefaultCoverAspectRatio = 210 / 300`（常规封面比例常量，EHConst 方案要求等价落地为独立常量文件，便于测试导入）；
  - `coverAspectRatio({imgWidth, imgHeight})`：任一非正值回退默认比例，正常值保持 `max(imgWidth/imgHeight, 1/2)` 钳制逻辑不变。
- `lib/pages/item/gallery_item_flow_large.dart` `_CoverWidget`：
  `AspectRatio(aspectRatio: max(imgWidth/imgHeight, 1/2))` → `coverAspectRatio(...)`。
  消除 `imgWidth=0/imgHeight=0 → NaN`、`imgHeight=0 → Infinity` 直达布局层的路径
  （本地收藏、历史记录等数据源可能缺封面尺寸字段）。

### P0-2 自动化回归测试（仓库原无 test/，已启用 dev_dependencies 注释掉的 flutter_test）

- `test/cover_ratio_test.dart`：比例不变式单测（正常比例/钳制/异常输入回退，共 9 例）。
- `test/cover_ratio_layout_test.dart`：布局层 widget 测试——大卡同款
  `AspectRatio(aspectRatio: coverAspectRatio(...))` 在真实布局中构建，
  断言 `0×0`、`300×0` 输入高度等于"默认比例对应值"而非 NaN/Infinity
  （AspectRatio 对非法比例会 debug 断言崩溃，本测试即拦截该缺陷形态）。
- `test/tabview_controller_list_test.dart`：列表对象不变式 controller 测试——
  `loadDataMore()` 追加、`loadPrevious()` 前插后均断言
  `identical(state, before)`（复用同一 List 对象，165ff971 第 2 条的核心约定）。
  测试基建说明：EhSettingService.onInit 依赖 Isar、TagController.onReady 会拉取
  mytag，均以空实现子类替代；GetX 按注册时显式泛型索引，须以基类类型注册。
- **变异验证**：将比例表达式临时改回 `imgWidth/imgWidth`（原 bug 模式），
  布局测试 2 例失败，确认测试有效拦截；恢复后 15 例全绿。
- 验收标准达成：`flutter test` 本地全绿；故意改回错误表达式时测试失败 ✓。

### P0-2 第 3 项 analyze 基线固化

- `scripts/parse_analyze_machine.py`：`dart analyze --format machine` 管道格式 →
  稳定签名（severity|code|相对路径|message，忽略行列号避免位移误报）。
- `scripts/check_analyze.sh`：比对 `scripts/analyze_baseline.txt`，**新增告警即失败**，
  `--update` 刷新基线；兼容 dart 新退出码（0=无告警 2=有 info/warning 3=有 error）。
- `scripts/analyze_baseline.txt`：1598 条（Flutter 3.41.7 stable）。
- `.github/workflows/analyze_test.yml`：push/PR 触发，git-crypt 解锁
  （`ENCODED_GIT_CRYPT`，与 release.yml 同 secret）→ pub get → 基线比对 → flutter test。
- 与改动前（HEAD）逐签名 diff：**无新增**；初版曾引入 2 条
  （directives_ordering import 顺序、test 子类 must_call_super）均已修复。
  基线在 config.dart 可解析（解锁/本地桩）状态下生成；加密态会多 4 条
  `uri_does_not_exist/undefined_identifier`（sentry.dart / translator_helper.dart），
  属环境差异，CI 解锁后不会出现。

### P2-1 顶栏按钮语义标签

顶栏图标控件全部为无语义的 `button button N`，已包 `Semantics(label:)`
（跟随同文件既有硬编码中文惯例，如"编辑分组/删除分组"；label 会合并进按钮
语义节点）：

- `custom_tabbar_page.dart`（画廊页顶栏）：搜索 / 回到顶部 / 跳转/搜寻 /
  刷新（桌面端）/ 分组管理（bars）。
- `favorite_tabbar_page.dart`（收藏页顶栏）：搜索 / 收藏排序（sort_down+序号）/
  回到顶部 / 跳转/搜寻 / 刷新 / 选择收藏夹。
- `search_page.dart`（搜索页 trailing）：回到顶部 / 跳转/搜寻 / 以图搜图 / 筛选。
- `search_page.dart` `SearchTextFieldIn`：搜索（放大镜）/
  刷新 / 打开画廊链接 / 加入快速搜索 / 清空搜索词 / 快速搜索列表。

### P3-1 普通瀑布流 `_getHeight` 分支守卫

`lib/pages/item/gallery_item_flow.dart`：

- 旧逻辑：`imgWidth >= maxWidth` 按比例；否则**裸用 `imgHeight` 像素值当逻辑高度**；
  `imgWidth == null` 时 height 为 null。
- 新逻辑：统一 `height = maxWidth / coverAspectRatio(...)`，
  缺失/非法尺寸走默认比例，窄图受 1/2 钳制，不再有"小图高度失真"分支。
- 行为变化说明（仅影响此前失真的路径）：
  - 小图（imgWidth < maxWidth）：由"像素高度直用"变为按宽度等比缩放；
  - 极窄图：高度被钳制为 ≤ 2×maxWidth（与 large 模式一致）；
  - imgWidth 缺失：由"height=null 交给图片内在比例"变为默认比例盒
    （首帧高度确定，消除列簿记不确定来源）。
  正常数据（imgWidth ≥ maxWidth 且比例 ≥ 1/2）数值不变。

### P3-2 item builder 注册短路（身份守卫版）

`lib/pages/tab/view/list/waterfall_flow.dart`：改为仅在
「provider 未注册」或「注册实例与当前不是同一对象（刷新产生同 gid 新数据）」时
`lazyReplace`，列表对象复用后的每次重建不再 delete/lazyPut 抖动注册表。

> ⚠️ 方案原拟"前置 `if (!Get.isRegistered(...))` 短路"。核实 GetX 4.7.2 源码后
> 发现 `lazyReplace` = `delete(force: permanent)` + `lazyPut`——即现状每次重建
> 都会删旧注册再建新 builder，这正是"刷新后数据能更新"的机制；裸 isRegistered
> 短路会让同 gid 的新对象（reloadData 场景）拿不到注册，**导致刷新后旧数据残留**。
> 故采用 identical 身份守卫，两全。

## 三、P1-1 loadPrevious（前插）排查矩阵

**触发链**：`TabViewController.onRefresh()`（tabview_controller.dart:395）是
`loadPrevious()` 的唯一调用方，条件 `(prevGid.isNotEmpty || prevPage >= 0) && afterJump`
——即"跳转/搜寻（loadFrom）之后下拉刷新"才走前插。

| 页面（控制器） | loadPrevious 可达 | keepPosition 传参 | 瀑布流/网格下前插锚定 |
|---|---|---|---|
| 画廊-自定义标签分组（CustomSubListController，custom_sub_page） | ✓ | ✓（仅 list/simpleList 生效） | ✗ 无锚定 |
| 收藏夹子页（FavoriteSubListController，favorite_sub_page） | ✓ | ✓（仅 list/simpleList 生效） | ✗ |
| 搜索页（SearchPageController） | ✓ | ✓（仅 list/simpleList 生效） | ✗ |
| 排行榜（TopListViewController，toplist_page） | ✓ | ✗ 未传 | ✗ |
| 历史记录（HistoryViewController，history_page） | ✓ | ✗ 未传 | ✗ |
| 图搜（SearchImageController，search_image_page） | ✓ | ✗ 未传 | ✗ |

（keepPosition 仅 list / simpleList 两分支接进 `FlutterSliverList`；
`EhWaterfallFlow`、`EhGridView` 无此参数——tab_base.dart switch 各分支。）

**结论**：「瀑布流（大/小）/ 网格 + 跳转后下拉刷新」组合存在（搜索页、分组页、
收藏页顶栏都有跳转入口，且列表样式是用户级设置），前插后 `SliverWaterfallFlow`/
`SliverGrid` 无锚定，视口内容整体下移，跳位在几何上确定发生。

### 3. 运行时验证（2026-09-06 补录，跳位实锤 ✅）

**环境**：macOS debug 构建（本分支），搜索结果页（瀑布流-大，4 列
x=568/766/964/1162，列宽 190，AX y/height 真实可用——按 QA 结论采用
"新推页面"取数）。

**方法**：搜索 blue archive → 顶栏"跳转/搜寻"按 GID 跳转
（`loadFrom next 4170420, prev 4170992`，afterJump=true）→ 触发
`onRefresh()`（走与下拉刷新完全相同的 `EhCupertinoSliverRefreshControl →
TabViewController.onRefresh` 代码路径）。触发方式说明：本机的像素滚动/
键盘注入通道间歇性故障（与既往验证记录一致），临时在搜索页加了 debug-only
按键钩子直调 `controller.onRefresh()`；**该钩子仅存在于验证用临时构建，
已回退，不在任何提交中**。

**AX 双快照证据**（full 视图，条目身份 + 真实 y/height）：

| | 视口首屏（y=336）四列 |
|---|---|
| 前插前基线 | [Pixiv] Xinとobiwan (h=433) / [Pixiv] 小柴胡 (h=238) / [Pixiv] Koni (h=263) / [Pixiv] 光怪陆离 (h=397) |
| 前插后 | [Fanbox] カカポ (h=251) / [Kyou Asuka] 生殖機能！？ (h=399) / [YurulomI] Niyaniya (h=384) / [nameka446] キサキNTRセックス見学40p (h=223) |

前插后视口顶部出现的正是**搜索第 1 页的头部条目**（与首次搜索基线快照一致），
即 loadPrevious 前插的上一页内容；**前插前的原首屏四条目全部被推移出视口
下方**（offset 未按插入高度校正）。

**判定**：瀑布流-大在前插后视口**未锚定**，"跳位"实锤——与
list/simpleList 模式的 keepPosition 行为不一致。

### 4. 修复决策

1. **方案首选不可用**：`sliver_tools` KeepScrollOffset 经查在 0.2.12
   （pub 最新版）中不存在；在不引入新依赖（方案非目标）前提下无现成组件。
2. **备选（手动 offset 校正）成本/风险**：前插后以
   `maxScrollExtent` 前后差值做 `ScrollPosition.correct` 需要——控制器侧
   持有滚动位置句柄（涉及 custom_sub/favorite_sub/search/toplist/history/
   search_image 六类页面接线）；校正严格限定在 insert 成功之后（方案 §四
   风险节警示的失败重试边界）；waterfall 列布局与校正的时序需要专门验证。
   实现与回归成本约 1~2 人日（与方案预估一致）。
3. **决策：本轮不实施修复**，作为已知行为记录（"跳转后下拉刷新，视口显示
   更旧一页内容于顶部、原位置内容整体下移"）；上述备选设计 + 验收标准
   （前插后原首屏条目屏幕 y 不变，AX 双证）已在本节定义，留待专门轮次
   实施并复验。

## 四、P1-2 帧预算测量（2026-09-06 完成，结论：维持现状 ✅）

**方法**：合成数据基准 harness（`benchmark/frame_benchmark_main.dart`，已入库）
在真实 macOS 引擎上运行——瀑布流-大、120 个合成画廊条目（真实比例分布 200~300
× 280~400、含 tags/评分/页数等完整 item 数据）、ScrollController 驱动连续滚动
（预热 4 屏丢弃后测 13+ 屏、217~225 帧），`addTimingsCallback` 采集真实
FrameTiming，测完自动打印并退出。对比对象为同一 harness 分别跑：

- **keframe 占位版**：`165ff971^`（c667fb31，git worktree + 本地 config 桩）
- **真身直布局版**：本分支 HEAD

均为 `flutter build macos --profile`（profile 模式，Apple Silicon 本机）。

**数据**（各跑 2~3 次，波动 < ±0.7ms）：

| 指标 | keframe 占位版 (165ff971^) | 真身直布局版（本分支） |
|---|---|---|
| 帧数 | 225 | 217~218 |
| build p50 | 0.40~0.44 ms | **0.37~0.38 ms** |
| build p90 | **1.40~1.43 ms** | 1.69~2.37 ms |
| build max | **1.58~2.64 ms** | 4.64~7.09 ms |
| raster p50 / p90 | 0.62~0.65 / 0.90~0.96 ms | 0.60~0.62 / 0.92~1.03 ms |
| total (build+raster) p90 | **2.12~2.25 ms** | 2.60~3.08 ms |
| total max | **3.32~3.53 ms** | 5.64~7.95 ms |
| >16.7ms 卡顿帧 | **0** | **0** |

**结论**：按方案"结果分支"判定——**无显著劣化，维持现状（不启用方案 B），
关闭本项**。

- 两版本均无任何超帧预算（16.7ms）的帧；total p90 均 < 3.2ms，余量 > 5 倍。
- 新版 build p50 更低（省去占位构建）；build 尾部（p90/max）更高——keframe
  把每个条目的构建分摊为"占位帧 + 真身帧"两帧，单帧峰值更低，但总帧数更多
  （225 vs 217）、总构建工作量更高（每个条目构建两次）。该削峰收益在本测量
  中不构成恢复占位符的理由，且占位/真身高度不一致正是本次跳位 bug 的根因。
- 局限说明：测量为本机（Apple Silicon）profile 模式合成数据，低端 Android
  真机的绝对数值不可直接迁移；若未来低端设备出现滚动掉帧，可直接复跑
  `benchmark/frame_benchmark_main.dart` 复测（旧版本用 git worktree 检出
  `165ff971^` + 复制该文件 + 本地 config 桩即可）。

## 五、P2-2 搜索输入框语义提交通路核验

- `textInputAction: TextInputAction.search` **已存在**
  （search_page.dart `SearchTextFieldIn`，无需改动）；
- `onEditingComplete: controller.onEditingComplete` 为唯一提交入口（现状已是）；
- 遗留：AX `set_value` 不落 Flutter 编辑控制器、`AXConfirm` 不触发提交——
  属 Flutter macOS 引擎限制，按方案"P2-1 完成后复测，若仍不通标注已知限制"。
  本次未做运行时复测，QA 已知问题记录维持（fix-waterfall-large-item-jump-验证进度
  记录.md 场景 3：键盘 Return 提交可用）。桌面读屏用户暂以 Return 键提交。

## 六、验证与提交说明

- `flutter analyze`（签名集）相对 HEAD：无新增（净 -4 环境差异除外，见 §二）；
- `scripts/check_analyze.sh`：✓ 无新增告警（基线 1597 条）；
- `flutter test`：15/15 全绿（含变异验证往返）；
- P1-2 帧预算测量与 P1-1 前插运行时验证：见 §四 / §三（2026-09-06 补录）；
- 提交范围不含：`lib/config/config.dart`（git-crypt 本地桩）、
  `lib/models/user.dart`（无关本地改动）、再生插件注册文件、Podfile.lock、
  pbxproj、`lib/config/config 2.dart`、两个历史记录 md。

## 七、v1.9.4+568 更新记录与 iOS 未签名包（2026-09-06 补录）

- 更新记录已按仓库惯例新建 `changelog/v1.9.4+568.md`（中英双语），随版本 bump
  以惯例成对提交（`dad990c2 chore: bump version to 1.9.4+568`）。
- iOS 未签名 ipa 已产出：
  `build/Eros-FE-v1.9.4+568-ios-unsigned.ipa`（25MB，arm64 真机切片，
  `codesign -d` 报 "code object is not signed at all"，即完全未签名）。
- 构建环境说明（重要）：
  1. 本机 Xcode 26.6 缺 iOS 26.5 平台组件，已通过
     `xcodebuild -downloadPlatform iOS` 安装；
  2. 本仓库位于 iCloud 同步目录（~/Documents），构建目录会被 fileprovider
     进程加上 FinderInfo/fpfs 扩展属性，导致 flutter 脚本内 ad-hoc 签名报
     "resource fork, Finder information, or similar detritus not allowed"——
     改在 /private/tmp 的 detached worktree 中构建规避；
  3. `ios/Runner/GoogleService-Info.plist` 为 git-crypt 加密文件且本机无密钥，
     构建用 worktree 中以**空字典占位 plist** 替代。lib 代码（本分支）不引用
     Firebase，该替换不影响 app 功能；如需携带真实 Firebase 配置，需在持有
     git-crypt 密钥的环境（或 CI）解锁后重新构建。

## 八、遗留与建议

1. P1-1 修复（手动 offset 校正，设计见 §三.4）+ 运行时复验 —— 专门轮次执行；
2. ~~P1-2 真机帧预算测量~~ —— 已在本机 profile 模式完成（§四），如需低端
   Android 真机数据可复跑已入库的 harness；
3. P2-2 AXConfirm 复测 —— P2-1 合并后随手验证一次即可（本次运行时复核已确认
   P2-1 语义标签在 AX 树中生效：搜索/跳转/搜寻/刷新/分组管理/以图搜图/筛选/
   加入快速搜索/清空搜索词/快速搜索列表等均可读出功能名）；
4. 语义标签为硬编码中文，与同文件既有文案惯例一致；后续若做 l10n 收敛，
   建议连同"编辑分组/删除分组"一起走 arb（intl_utils CLI 与 IDE 插件生成格式
   不一致，重生成会带来 ~8000 行格式 diff，需单独处理）。
