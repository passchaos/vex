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
| C ABI、Python/其他语言 FFI | 明确排除 | 构建只安装 Vex CLI，并公开 Zig package API；无 header、外语 library 或 binding 目标 | 不维护跨语言 ABI 兼容负担 |
| Graphviz 作为 oracle | 已验证 | SVG oracle/residual 测试与 `tools/svg_residual.py` | 只用于开发测试，不成为运行时依赖 |

## Graphviz 生态兼容

| 能力 | 状态 | 当前证据 | 尚缺内容 / 完成门槛 |
| --- | --- | --- | --- |
| DOT 实用语法 | 部分完成 | strict、named/anonymous scoped subgraph、ports、port-preserving node-list fanout、whitespace-free edge operators、edge chains、rank groups、Graphviz NAME/NUMBER lexical boundaries、`chkNum` ambiguous-number token split、balanced angle-string、BOM、字符串、注释与多 top-level graph stream 测试；named subgraph textual ID 仅在 parser 内承担 parent-scoped reopen / compound 引用，未显式设置 `label` 时 model label 为空、SVG 不输出文字且布局不预留标题带；Graphviz `labels.c` AGRAPH object-escape 语义：subgraph label 中 `\G` 展开当前 textual ID、`\N` 保持字面量、`\L` 单次替换原始 label，并有 nested corpus / SVG 回归；Graphviz 七种 Latin-1 aliases 与 `big5` / quoted `big-5` 在 per-graph model boundary 原生转为 UTF-8，Big-5 使用内嵌 Graphviz lead/trail 范围映射、malformed bytes 转 U+FFFD，覆盖 graph/default/node/edge/subgraph/record-port text、UTF-8 no-op 和真实 Latin-1 corpus XML-valid SVG smoke；`parseDotGraphs` / `parseInputGraphs`、跨 graph 诊断、CLI 多 SVG 文档输出及 `src/testdata/dot_non_html_*.dot` corpus；Graphviz #2743 joined-attribute fixture 解析为 2 nodes / 1 edge；`zig build audit-dot-corpus -Dgraphviz-root=...` 用 ReleaseFast `--check` 固化本机小于 256 KiB 的 786-file baseline：722 个非 HTML DOT 直接通过、59 个 HTML-like label 排除、4 个已知 malformed 正确拒绝、1 个 plain output 排除、0 timeout、0 unexpected | 继续扩展非 HTML-like label 的目标 DOT grammar corpus；所有支持/拒绝项有诊断测试 |
| 核心图模型与 Zig API | 已验证 | `Graph`、`NodeId`、typed attrs、API 示例与测试；node/subgraph parser textual ID 与 display `label` 分离 | 保持 `NodeId` 身份、`label` 显示语义和 parser 局部 textual-id 映射 |
| strict / keyed edge identity | 已验证 | Graphviz `agedge` source oracle；strict DOT/API duplicate-edge、non-strict same-key reopen、different-key parallel edge、undirected canonicalization 和 file corpus 测试 | strict 保持端点唯一；`key` 仅留在 parser 边界 |
| layered/Sugiyama 布局 | 部分完成 | rank、crossing、coordinate、long-edge、compound、nested cluster、`clusterrank=local|global|none`、typed graph `newrank` / `remincross` / `mclimit` / `nslimit1` / `nslimit` / `searchsize` / `TBbalance` / numeric-fill-compress-auto-expand ratio 与 typed subgraph `compact` strong-rank 测试；cluster `margin` 按 Graphviz `dotgen/position.c` 的 `late_int` 使用整数 point-space，覆盖 22pt、整数前缀、负值钳零、小数截断、非法值回退，并与 graph/node inch-space margin 回归隔离；rank-simplex tight-tree 使用唯一 preorder subtree intervals，3×4 crossed parallel-rank 回归不再触发 `DisconnectedTightTree`；numeric/fill/expand 按 Graphviz `set_aspect` 拉伸 node centers、waypoints 和 subgraph bounds，horizontal rankdir 交换内部 axes，node/text 尺寸保持不变；`ratio=compress` 按 rankdir 使用 `size` 的 coordinate axis 目标压缩完整 virtual ranks，保留 same-rank 硬间距且不可行请求停在无重叠最小宽度；`ratio=auto` 按 Graphviz `idealsize(.5)` 使用 `page` 计算整数页网格，覆盖 TB/BT/LR/RL 和 typed `GraphAttr.page`，SVG 保持单完整文档而不分页；`TBbalance=min|max` 在所有 rankdir 中把无约束 source/sink floater 移到对应 boundary，显式 `rank=source|sink` 保持独占优先；`mclimit` 按 Graphviz MaxIter=24 / MinQuit=8 同时缩放最大 crossing passes 与连续无改进退出阈值，`.05` 对照 fixture 从默认 0 crossing 降低 effort 到残留 1 crossing，`vex_crossing_passes` 保留直接 override；`nslimit1` 按 `floor(value * node_count)` 限制 normal/strong rank network-simplex pivots，0/非法值禁用 simplex，quality fixture 的 weighted rank-span cost 从默认 167 变为 170，并覆盖 Graphviz 1902 / #2391 zero-budget smoke；`searchsize` 默认30，限制 ordinary rank simplex 每次 pivot 比较的负 cut-value tree-edge candidates，旋转 cursor 测试与修复后 quality fixture 覆盖 `1 => cost 604`、`30 => cost 569`；`nslimit` 按相同 node-count 规则限制 coordinate refinement passes，0/非法值跳过 refinement，quality fixture 默认 coordinate stress 至少比 zero-budget 低 2 倍，`vex_coordinate_passes` 保留直接 override；默认 integrated `newrank=true` 允许 rank constraints 横跨 sibling subgraphs，显式 false 恢复 Graphviz local recursive ranking 的 rank-constraint scope，rank constraint model/metadata 保留 named-subgraph scope，并覆盖 Graphviz 705 / #1221 / #2521 语义；`compact=true` 使用 Graphviz newrank 的 1000 权重 rank-span 目标、weak cross-edge penalty、nested strong envelope，并覆盖 internal `minlen`、重叠 rank set 与显式 boundary rank；`remincross` absent/true 在 cluster grouping 后运行第二次全局 crossing minimization，false 保留稳定 first-pass block order，非法显式文本按 Graphviz mapbool 关闭；global/none 保留 rank constraints 并禁用特殊 subgraph ranking/box/spacing/compound-boundary routing | 继续完整目标 cluster 语义 corpus；更大图质量门槛 |
| force-directed 布局 | 已验证 | independent neato stress-majorization；independent fdp spring-electrical with K/T0/len/weight and cluster boxes；independent sfdp deterministic coarsen/prolongate/refine with levels/K/repulsiveforce；deterministic Fruchterman-Reingold；规模、能量、属性、引擎区分和预算测试 | 保持四条引擎路径独立，持续扩展规模基准 |
| radial/twopi 布局 | 已验证 | explicit/auto root、BFS rings、ranksep、subtree angular spans、component packing、CLI/Zig API 和 SVG smoke | 保持 root `NodeId` 与 textual id/display label 分离 |
| circular/circo 布局 | 已验证 | Tarjan biconnected blocks、block-cut circles、root/mindist/oneblock、component packing、CLI/Zig API 和 SVG smoke | 持续补充复杂 articulation oracle corpus |
| treemap/patchwork 布局 | 已验证 | hierarchical squarified treemap、typed node/subgraph area、nested containment、area override、edge independence、CLI/Zig API 和 SVG smoke | 持续补充大层级与 label-fit corpus |
| array/osage 布局 | 已验证 | recursive child-subgraph-first packing、intrinsic node/cluster rectangles、typed `pack`/`packmode`/`sortv`、row/column-major 与 alignment flags、nested containment、edge independence、CLI/Zig API 和 SVG smoke | 持续补充复杂异形节点与 Graphviz residual corpus |
| pre-positioned nop/nop2 布局 | 已验证 | required node `pos`、typed `NodePosition`、`!` pin parsing、`notranslate`、nop edge reroute、nop2 `3n+1` cubic edge spline preservation/fallback、typed `EdgeSplineSegmentInput`、input cluster `bb`、graph/subgraph/node/edge `lp`/`xlp`/`head_lp`/`tail_lp`、deterministic `overlap` families 与 typed `sep`、nop2 final-geometry isolation、CLI/Zig API 和 SVG smoke | 持续补充 Graphviz residual corpus |
| rankdir、rank constraints、spacing | 已验证 | TB/BT/LR/RL、same/min/max/source/sink、ranksep/nodesep、DOT/API `minlen=0` same-rank edge 与 Graphviz #162 inter-subgraph 单边测试；Graphviz mapbool 语义和 #258 `constraint=none` 单边测试；`weight=0` 保留 hard minlen、退出 rank/coordinate objective 但保留 crossing xpenalty 的 rank/metadata 测试 | 所有方向持续通过 |
| records、ports、compound edges | 已验证 | record field、compass port、scoped ltail/lhead 与 clipping 测试；Graphviz `compound.c` endpoint-membership oracle，目标 subgraph/后代必须包含对应 tail/head 且不能同时包含两端，无效 hint 保留 attr/metadata 但回退普通节点边界；DOT corpus 与 typed ancestor-membership 回归 | DOT/API 与 metadata 语义一致 |
| parent-scoped subgraph identity | 已验证 | Graphviz `agsubg` source oracle；same-parent reopen merge、different-parent isolation 和 file corpus 测试 | 保持成员/属性合并和最近作用域引用语义 |
| Graphviz 常用 shapes/styles/colors/fonts/images | 部分完成 | Graphviz shape 注册表差分仅排除 PostScript-only `epsf`，其余 canonical shapes/aliases、SBOLv、最多四段的复合 arrow marker grammar（open、gap、`l`/`r` half modifiers、typed `ArrowPart`）、完整 265 个 ColorBrewer palette variants / 1,689 indexed colors、gradients、layers、fonts、`image`/`shapefile`/`imagescale`/`imagepos` 与 graph `imagepath` first-readable search 均有 typed/API/SVG 测试；graph `quantum` 按 inch→point quantum 向上量化 estimated label dimensions，并覆盖 layered/force 与非法值 no-op；仅服务 image-map outline 的 `samplepoints` 不暴露 typed SVG API | 继续用 oracle corpus 收敛非 HTML 渲染几何差异 |
| SVG canvas 与对象分组 | 已验证 | size、numeric/fill/compress/auto/expand ratio、dpi、rotate、center、outputorder、id、class 测试；layered ratio modes 均先处理 layout coordinates，SVG 只应用最终 physical size / page-grid target 而不二次调整 viewBox aspect | XML 安全与 Graphviz-style group 结构持续通过 |

## 超越 Graphviz 的能力

| 能力 | 状态 | 当前证据 | 尚缺内容 / 完成门槛 |
| --- | --- | --- | --- |
| 自包含交互 SVG | 已验证 | layer、collapse、filter、labels、focus、inspector、search、viewport、minimap、stats 和 `interactive-all` 测试 | 键盘/ARIA 与静态模式回归持续通过 |
| 机器可读 SVG 对象索引 | 已验证 | graph/node/edge/subgraph 结构、attrs、rank constraints、ports、waypoints、geometry；`SVG_METADATA_V1.md` namespace/version/features/additive policy；静态模式与 CLI/API smoke | v1 只做 additive 扩展，破坏性变化发布新 namespace major |
| 精确解析诊断 | 已验证 | line/column/source/caret/hint；`parseDotDiagnostics` statement recovery、max cap、UTF-8、lexical stop；CLI `--validate-all` smoke | 持续随目标 grammar 增加语义诊断 |
| 可配置布局/输入预算 | 部分完成 | parse-only、max input、iterative engine budgets、layered pass budgets；DOT textual ID 通过 `NodeId` 索引 O(1) 反查；`zig build test-parse-scale` 使用 ReleaseFast 运行 10,000-node / 9,999-edge chain 与 4,096-node / 4,095-edge / 64-subgraph dense-attribute 两类 gate，每类限制 1 秒和 32 MiB parser arena，并报告 source/arena bytes 与 elapsed time；连续 cached 实测分别为 `5–6ms / 20.3MiB` 与 `6–8ms / 14.3MiB`；`zig build test-layout-render-scale` 覆盖 layered/neato/fdp/fr/sfdp/twopi/circo/patchwork/osage 全部原生布局族，使用 256-node / 512-edge iterative、192-node / 388-edge crossed layered、2,048-node / 4,096-edge sfdp/radial/circular 和 4,096-node packing workloads，保持 layout 3 秒 / 8 MiB arena、SVG render 1 秒 / 4 MiB arena 原预算，验证对象分组和输出 hash，并通过归一化 `getrusage` 限制进程 peak RSS 为 96 MiB；连续实测最大 layout arena `4.94MiB`、最大 render arena `1.42MiB`、组合 peak RSS `12.40–12.42MiB`，所有输出 hash 稳定且 layered deterministic double-render 保持 byte-identical；所有当前引擎 `LayoutControl` / `LayoutWorkBudget` 取消和 CLI exit-2 smoke；sfdp Barnes-Hut 精度/交互次数门槛和 512-node SVG smoke | 增加长时间趋势和并行吞吐门槛 |
| 增量布局与心理地图稳定性 | 已验证 | `layoutGraphIncremental`；layered/force 共享节点位移门槛、无重叠/边界和 `stability=0` 等价测试 | 保持 NodeId 驱动；共享节点位移显著低于完整重排 |
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
