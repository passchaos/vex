# Vex 能力矩阵

本文档把“实现完整的超越 Graphviz 能力”拆成可验证的交付项。它不是功能宣传页，而是完成度审计清单。

## 状态定义

- **已验证**：存在原生实现、公开入口和直接覆盖该能力的测试或命令证据。
- **部分完成**：已有实用实现，但仍缺少明确列出的语义、规模或质量门槛。
- **未实现**：尚无可依赖的产品能力。
- **明确排除**：项目决定不实现，不计入完成门槛。

只有所有非排除项都达到“已验证”，长期目标才可以标记完成。`zig build test`、文档列表或单个示例通过都不能单独证明目标完成。

## 产品边界

| 能力 | 状态 | 当前证据 | 完成门槛 |
| --- | --- | --- | --- |
| 原生 Zig parser/layout/SVG 管线 | 已验证 | `src/root.zig` 的 `parseInput`、`layoutGraph`、`render`；`zig build test` | 正常 CLI/API 路径不调用 Graphviz |
| SVG 输出 | 已验证 | `OutputFormat.svg`、CLI/API 示例 | 保持 CLI/API 和测试覆盖 |
| PNG/PDF/HTML/terminal 输出 | 明确排除 | 项目只注册 SVG 后端 | 不加入兼容负担 |
| Graphviz HTML-like label 渲染 | 明确排除 | angle-string 纯文本测试 | angle-string 始终按纯文本和 XML 安全方式输出 |
| Graphviz 作为 oracle | 已验证 | SVG oracle/residual 测试与 `tools/svg_residual.py` | 只用于开发测试，不成为运行时依赖 |

## Graphviz 生态兼容

| 能力 | 状态 | 当前证据 | 尚缺内容 / 完成门槛 |
| --- | --- | --- | --- |
| DOT 实用语法 | 部分完成 | strict、named/anonymous scoped subgraph、ports、port-preserving node-list fanout、whitespace-free edge operators、edge chains、rank groups、Graphviz NAME/NUMBER lexical boundaries、BOM、字符串与注释测试；`src/testdata/dot_non_html_*.dot` corpus | 继续扩展非 HTML-like label 的目标 DOT grammar corpus；所有支持/拒绝项有诊断测试 |
| 核心图模型与 Zig API | 已验证 | `Graph`、`NodeId`、typed attrs、API 示例与测试 | 保持 `NodeId` 身份、`label` 显示语义和 parser 局部 textual-id 映射 |
| strict / keyed edge identity | 已验证 | Graphviz `agedge` source oracle；strict DOT/API duplicate-edge、non-strict same-key reopen、different-key parallel edge、undirected canonicalization 和 file corpus 测试 | strict 保持端点唯一；`key` 仅留在 parser 边界 |
| layered/Sugiyama 布局 | 部分完成 | rank、crossing、coordinate、long-edge、compound 与 cluster 测试 | 完整目标 cluster 语义 corpus；大图质量与性能门槛 |
| force-directed 布局 | 已验证 | independent neato stress-majorization；independent fdp spring-electrical with K/T0/len/weight and cluster boxes；independent sfdp deterministic coarsen/prolongate/refine with levels/K/repulsiveforce；deterministic Fruchterman-Reingold；规模、能量、属性、引擎区分和预算测试 | 保持四条引擎路径独立，持续扩展规模基准 |
| radial/twopi 布局 | 已验证 | explicit/auto root、BFS rings、ranksep、subtree angular spans、component packing、CLI/Zig/C/Python 和 SVG smoke | 保持 root `NodeId` 与 textual id/display label 分离 |
| circular/circo 布局 | 已验证 | Tarjan biconnected blocks、block-cut circles、root/mindist/oneblock、component packing、CLI/Zig/C/Python 和 SVG smoke | 持续补充复杂 articulation oracle corpus |
| treemap/patchwork 布局 | 已验证 | hierarchical squarified treemap、typed node/subgraph area、nested containment、area override、edge independence、CLI/Zig/C/Python 和 SVG smoke | 持续补充大层级与 label-fit corpus |
| array/osage 布局 | 已验证 | recursive child-subgraph-first packing、intrinsic node/cluster rectangles、typed `pack`/`packmode`/`sortv`、row/column-major 与 alignment flags、nested containment、edge independence、CLI/Zig/C/Python 和 SVG smoke | 持续补充复杂异形节点与 Graphviz residual corpus |
| pre-positioned nop/nop2 布局 | 已验证 | required node `pos`、typed `NodePosition`、`!` pin parsing、`notranslate`、nop edge reroute、nop2 `3n+1` cubic edge spline preservation/fallback、typed `EdgeSplineSegmentInput`、input cluster `bb`、graph/subgraph/node/edge `lp`/`xlp`/`head_lp`/`tail_lp`、deterministic `overlap` families 与 typed `sep`、nop2 final-geometry isolation、CLI/Zig/C/Python 和 SVG smoke | 持续补充 Graphviz residual corpus |
| rankdir、rank constraints、spacing | 已验证 | TB/BT/LR/RL、same/min/max/source/sink、ranksep/nodesep 测试 | 所有方向持续通过 |
| records、ports、compound edges | 已验证 | record field、compass port、scoped ltail/lhead 与 clipping 测试 | DOT/API 与 metadata 语义一致 |
| parent-scoped subgraph identity | 已验证 | Graphviz `agsubg` source oracle；same-parent reopen merge、different-parent isolation 和 file corpus 测试 | 保持成员/属性合并和最近作用域引用语义 |
| Graphviz 常用 shapes/styles/colors/fonts/images | 部分完成 | shapes、SBOLv、markers、gradients、layers、fonts、images 测试 | 用支持清单和 oracle corpus 明确剩余非 HTML 渲染差异 |
| SVG canvas 与对象分组 | 已验证 | size/ratio/dpi/rotate/center/outputorder/id/class 测试 | XML 安全与 Graphviz-style group 结构持续通过 |

## 超越 Graphviz 的能力

| 能力 | 状态 | 当前证据 | 尚缺内容 / 完成门槛 |
| --- | --- | --- | --- |
| 自包含交互 SVG | 已验证 | layer、collapse、filter、labels、focus、inspector、search、viewport、minimap、stats 和 `interactive-all` 测试 | 键盘/ARIA 与静态模式回归持续通过 |
| 机器可读 SVG 对象索引 | 已验证 | graph/node/edge/subgraph 结构、attrs、rank constraints、ports、waypoints、geometry；`SVG_METADATA_V1.md` namespace/version/features/additive policy；静态模式与 CLI/API smoke | v1 只做 additive 扩展，破坏性变化发布新 namespace major |
| 精确解析诊断 | 已验证 | line/column/source/caret/hint；`parseDotDiagnostics` statement recovery、max cap、UTF-8、lexical stop；CLI `--validate-all` smoke | 持续随目标 grammar 增加语义诊断 |
| 可配置布局/输入预算 | 部分完成 | parse-only、max input、iterative engine budgets、layered pass budgets；所有当前引擎 `LayoutControl` / `LayoutWorkBudget` 取消和 CLI exit-2 smoke；sfdp Barnes-Hut 精度/交互次数门槛和 512-node SVG smoke | 增加稳定时间/峰值内存观测和更大规模基准门槛 |
| 增量布局与心理地图稳定性 | 已验证 | `layoutGraphIncremental`；layered/force 共享节点位移门槛、无重叠/边界和 `stability=0` 等价测试 | 保持 NodeId 驱动；共享节点位移显著低于完整重排 |
| 多语言/运行时绑定 | 部分完成 | stable C ABI v1；installed header/static/shared library；Zig ABI 和真实 C smoke；dependency-free Python ctypes builder/DOT/error/cancel smoke | 按产品需求继续提供 WASM 或 JS 原生绑定 |
| 流式/并行大图管线 | 未实现 | 当前 parser/layout 为内存内串行流程 | 建立代表性规模、吞吐、峰值内存和取消门槛 |
| 清晰模块边界 | 部分完成 | 已拆出 `src/layout/*`、`src/svg/*` | `src/root.zig` 仍承载 parser/model/layout/render 大量实现；继续按稳定边界拆分 |

## 验证门槛

每个功能增量至少需要：

1. 聚焦测试直接覆盖新增语义，而不是只检查命令退出码。
2. `zig fmt --check` 和 `git diff --check`。
3. `zig build test`。
4. 涉及 CLI/SVG 交付时，运行真实 CLI smoke。
5. 涉及 Graphviz parity 时，使用本机 Graphviz oracle 或 residual 证据；不得在产品运行时调用 `dot`。
6. 更新本矩阵中的状态、缺口或证据。

## 当前优先级

1. 目标 DOT grammar/corpus 与完整 cluster 语义。
2. 大图性能、内存和取消门槛。
3. 继续收敛 parser/model/layout/SVG 模块边界。
