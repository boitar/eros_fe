# fix/waterfall-large-item-jump — 后续优化方案

> 基准：2026-09-05 运行时回归验证全部通过（详见
> [fix-waterfall-large-item-jump-验证进度记录.md](fix-waterfall-large-item-jump-验证进度记录.md)），
> 修复提交 `165ff971`（去除大卡占位符 + 复用列表对象）已在瀑布流-大模式下
> 通过"下滑→回滑""load more 追加→回滑""搜索页重复"及各列表模式回归共 4 组场景验证。
> 本文档将验证过程中暴露的隐患、未覆盖路径与可改进点整理为可执行的优化项。

---

## 一、目标与非目标

**目标**

1. 消除与本次修复同源的健壮性隐患（封面尺寸缺失时的比例计算异常）；
2. 为修复建立可自动执行的回归防线（仓库目前无任何 test/）；
3. 覆盖本次未验证的路径（loadPrevious 前插、帧预算）；
4. 收敛验证过程中发现的无障碍与代码卫生问题。

**非目标**

- 不改变已验证通过的"方案 A"主路径（大卡直接按真实比例布局、列表对象复用）；
- 不做瀑布流组件的大规模重构，不引入新依赖；
- 不处理 macOS 引擎级 AX 几何缺陷（见 §五，仅记录为 QA 已知问题）。

---

## 二、优化项清单

### P0-1 封面尺寸缺失时的比例守卫（紧邻修复点的暴露面）

**现状/问题**

修复移除了 keframe 占位符后，大卡首帧直接按
`gallery_item_flow_large.dart:194` 的 `aspectRatio: max(imgWidth / imgHeight, 1 / 2)`
布局；而入参来自 `gallery_item_flow_large.dart:119-120` 的
`imgWidth: galleryProvider.imgWidth ?? 0`，provider 侧解析时缺失字段直接落为
`?? 0`（`gallery_provider.dart:116-117`）。此前占位符恒定 1.0 把异常输入掩盖了，
现在异常值会直达布局层：

| imgWidth | imgHeight | 结果 |
|---|---|---|
| 0 | 0 | `0/0 = NaN` → `AspectRatio` 断言失败（debug 崩溃，release 布局未定义） |
| >0 | 0 | `Infinity` → 同上 |
| 0 | >0 | `max(0.0, 0.5) = 0.5` → 退化为 1:2 超长卡，列簿记被极端高度污染 |

本地收藏、历史记录等数据来源可能没有封面尺寸字段，属于可达路径。

**方案**

在 provider→item 的取值处（或 `_CoverWidget` 构造前）统一守卫：
`imgWidth/imgHeight` 任一非正值时回退到默认比例
（建议 `EHConst` 增加常量，取常规封面比例约 210/300，并保持 `max(…, 1/2)` 钳制逻辑不变）。

**涉及文件**：`lib/pages/item/gallery_item_flow_large.dart`（±10 行）

**验收标准**

- widget 测试：`imgWidth=0/imgHeight=0`、`imgWidth=300/imgHeight=0` 两种输入下
  大卡可正常构建，高度等于"默认比例"对应值而非 NaN/Infinity；
- 真机/桌面端打开一本无封面尺寸的本地收藏画廊不崩溃。

**预估**：0.5 人日（含测试）。

---

### P0-2 为本次修复建立自动化回归测试

**现状/问题**

仓库无 `test/` 目录。本次 bug 的根因是占位符比例表达式
`(_provider.imgWidth ?? 300) / (_provider.imgWidth ?? 400)`（分子分母同字段，恒 1.0）
——这正是最小 widget 测试即可拦截的缺陷类型；列表对象复用（`165ff971` 第 2 条）目前
也只有人工验证，无防回归手段。

**方案**（新建 `test/`，三项递进）

1. **比例不变式 widget 测试**：用已知比例的 provider（如 400×600）构建
   `GalleryItemFlowLarge`，断言首帧封面尺寸与比例一致；再断言
   `imgWidth=0` 等异常输入落到 P0-1 的默认比例。防止再次出现"占位/真身比例不一致"。
2. **列表对象不变式 controller 测试**：对 `TabViewController.loadDataMore()` /
   `loadPrevious()` 各执行一次，断言 `identical(state, before)`（复用同一对象，
   `tabview_controller.dart:276-281 / 333-341` 的核心约定）。
3. **analyze 基线固化为 CI 步骤**：本次修复已人工 diff 过 analyze 基线
   （1605 → 1601 条，净减 4，无新增），将该比对脚本化，防止新增告警混入。

**涉及文件**：`test/`（新建）、CI workflow（analyze 基线步骤）

**验收标准**：`flutter test` 在 CI 与本地均可运行且全绿；故意把比例表达式改回
`imgWidth/imgWidth` 时测试 1 失败。

**预估**：1 人日。

---

### P1-1 loadPrevious（前插）路径专项验证与锚定

**现状/问题**

本次验证只覆盖了 append（loadDataMore）。前插路径
（`tabview_controller.dart:333-341`，postFrame 中 `insertAll(0)`）在瀑布流下有一个
未验证风险：`SliverWaterfallFlow` 不支持 `keepPosition`
（只有列表模式用的 `FlutterSliverList` 有，见 `sliver_list.dart:75/134`），
前插后已有内容整体下移、视口不锚定，用户视线位置会"跳"过新增项的高度。
热门页没有前插入口，但需要确认是否存在"瀑布流 + loadPrevious"组合的页面
（收藏/历史/订阅按时间排序等）。

**方案**

1. 排查所有调用 `loadPrevious` 的页面与其列表模式组合，列出矩阵；
2. 对存在的组合做一次与本次同方法的滚动验证（前插后视口内容不位移）；
3. 若确有跳位：优先用 `sliver_tools` 的 `keepScrollOffset`/`SliverAnchor` 包装，
   或在前插 postFrame 中按"新增项总高度"手动校正 `ScrollController.offset`
   （需要前插前先累计 resultList 对应行高，成本略高）。

**涉及文件**：排查为主；如需修，`lib/pages/tab/view/` 下对应列表包装层

**验收标准**：前插触发后，视口内原有条目在屏幕上的位置不变（AX 或截图双证）。

**预估**：排查 0.5 人日；如需修 1~2 人日。

---

### P1-2 keframe 移除后的帧预算测量

**现状/问题**

方案 A 移除了大卡占位符，首帧布局从"恒定 1.0 占位"变为"真实比例 + 信息区"，
布局本身开销极小，但未量化；keframe 的原始目的是隔离重 item 的构建帧。
低端设备 + 大列表（单页 50+、累计 200+ 项）场景需要一次数据说话。

**方案**

用 DevTools timeline 在低端 Android 真机（或 macOS debug profile）对比：
本次修复版本 vs 修复前版本，滚动加载 3 页过程中的
frame build/raster 时间分布（p50/p90/最长帧）。

**结果分支**

- 无显著劣化 → 维持现状，关闭本项；
- p90 超 16ms 且确因 item 首帧构建 → 启用**备选方案 B**：恢复
  `FrameSeparateWidget`，但占位符改为与真身**完全相同**的比例公式
  （含 `max(…, 1/2)` 钳制与信息区高度）。高度一致则列簿记不被破坏，
  可同时保住帧预算与不跳位。

**验收标准**：给出两版帧耗时数据结论；若走方案 B，需重跑本次 4 组验证场景。

**预估**：0.5 人日测量（方案 B 视结果另计）。

---

### P2-1 顶栏图标按钮补语义标签（验证中直接发现）

**现状/问题**

验证期间 AX 树里画廊页/搜索页顶栏按钮全部是
`button button 8 / button button 86 …`（无语义标签），读屏用户与自动化
均无法辨识（本次只能逐个试探，其中一个还误入了"Search image"页）。
这些按钮的功能包括搜索、图搜、刷新/更多等。

**方案**

给顶栏 `IconButton`/图标按钮包一层 `Semantics(label: …)` 或使用带
tooltip 的按钮（Flutter 会把 tooltip 并入语义标签），覆盖画廊页与搜索页顶栏
（含搜索提交、返回等）。

**涉及文件**：画廊页/搜索页顶部栏相关 view（约 6~8 个按钮）

**验收标准**：macOS Accessibility Inspector 中各按钮可读出功能名；
搜索提交可通过 AX 动作触发。

**预估**：0.5 人日。

---

### P2-2 搜索输入框的语义提交通路

**现状/问题**

验证中发现：通过 AX `set_value` 写入搜索框不会落到 Flutter 编辑控制器
（AX 显示有值、控制器为空）；AX `AXConfirm` 未触发提交，仅真实键盘
聚焦 + 输入 + Return 可用。桌面端读屏/自动化用户无法可靠完成搜索。

**方案**

在搜索 TextField 上显式声明 `textInputAction: TextInputAction.search` 并保持
`onSubmitted` 为唯一提交入口（现状已是），同时在 P2-1 完成后复测 AXConfirm；
若仍不通，在 QA 文档标注"搜索需键盘 Return"的已知限制即可，不再深挖引擎。

**验收标准**：AXConfirm 或 Return 二者之一可从语义层触发提交。

**预估**：0.25 人日。

---

### P3-1 普通瀑布流 `_getHeight` 分支审计（顺带核查）

**现状/问题**

`gallery_item_flow.dart:56-64`：`imgWidth >= maxWidth` 时按比例算高，
否则直接返回原始 `imgHeight`（像素值当逻辑高度用）。imgWidth 缺失或很小
（竖图小图）时高度可能严重失真——与本次修复同属"首帧高度失真 → 列簿记失真"
家族，只是普通分支无占位符包裹，问题直接呈现为卡片高度错误而非回滑跳动。

**方案**

与 P0-1 同套守卫统一：非正值/缺失走默认比例；非">= maxWidth"分支也按
比例计算而非裸用 `imgHeight`。普通瀑布流模式回归一次滚动场景。

**预估**：0.5 人日（含回归）。

---

### P3-2 item builder 内的 Get 注册短路

**现状/问题**

`waterfall_flow.dart:72-77` 在每个 item 的 build 中执行
`Get.lazyReplace(…, fenix: true)` 注册 provider 与 GalleryItemController
（列表每次重建都重复注册）。功能正确，但有注册表抖动开销。

**方案**

前置 `if (!Get.isRegistered<…>(tag: gid))` 短路，或改为在数据到达处注册。

**预估**：0.25 人日。

---

## 三、建议实施顺序

| 批次 | 内容 | 依据 |
|---|---|---|
| 第 1 批（随下个版本） | P0-1 比例守卫、P0-2 测试基建、P2-1 语义标签 | 均为小改动、直接防线 |
| 第 2 批 | P1-1 前插专项、P1-2 帧预算测量 | 需真机/专项时间 |
| 第 3 批（机会性） | P2-2、P3-1、P3-2 | 顺手收敛 |

## 四、风险与回滚

- P0-1/P3-1 的守卫只影响"尺寸缺失"的异常分支，正常数据路径的数值不变；
- P1-1 若走手动 offset 校正，需同时覆盖 `loadPrevious` 失败重试的边界
  （校正只应发生在 insert 成功后）；
- P1-2 若启用方案 B（恢复占位符），必须同步重跑验证记录中的 4 组场景，
  并保留比例不变式测试作为合并门槛。

## 五、QA 已知环境问题（不改代码，仅记录）

1. **对运行中的 Flutter macOS 窗口 resize 后**，已加载页面的 AX y/height 退化为
   窗口底边钳制值（y=769,h=1），重启或新推页面后恢复——影响自动化取数，
   证据采集应以"新建页面 + 条目身份/列 x 坐标"为准。
2. **AX compact 视图**按优先级排序且会隐藏低优先级节点，跨快照对比一律用
   `get_app_state(detail: full)`。
3. 截图/像素滚动通道故障期间，`AXScrollToVisible` 语义动作可作为替代滚动驱动
   （本验证已验证其有效性），建议沉淀为回归脚本的基础操作。
