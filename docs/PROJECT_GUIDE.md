# Vex 项目指南

Vex 的目标是使用 Zig 实现一个面向未来的图可视化工具：先兼容 Graphviz/DOT 生态，再在布局、渲染、交互和可编程性上逐步超越 Graphviz。

## 核心目标

- **实现语言**：使用 Zig（当前项目锁定 Zig 0.16.0）。
- **产品定位**：构建一个“超越 Graphviz”的图可视化工具，而不是运行时调用 `dot` 的包装器；Graphviz 只能作为测试 oracle 和行为参考。
- **参考资料**：本机 Graphviz 源码位于 `~/Work/graphviz`，可以参考其 DOT 解析、布局引擎、插件划分和渲染管线设计；也参考 Zig 生态中的 zigraph，吸收其图 API/算法组织方式。
- **版本保存**：每次完成一个功能增量后，进行必要验证，并用 git 保存当前完成的变更。

## 兼容性要求

Vex 需要兼容 Graphviz 的 DOT 风格 DSL。对“结果必须 100% 等于 Graphviz”的目标，应通过原生 Zig parser/layout/renderer 逐步重实现 Graphviz 行为，并用本机 Graphviz `dot` 做测试 oracle；不要在正常 CLI 渲染路径中调用 `dot`。至少从一个实用子集开始：

- 支持 `graph` / `digraph`。
- 支持有向边 `->` 和无向边 `--`。
- 支持节点语句、边语句和图/节点/边属性。
- 支持常见属性：`label`、`color`、`shape`、`rankdir`、`weight` 等。
- 当前应覆盖实用 DOT 子集：`strict`、具名 subgraph 分组、subgraph 作为边操作数、ports、angle-bracket labels/IDs 文本化、Graphviz 常见字符串转义（`\n`/`\l`/`\r`、引号、反斜杠、续行）、quoted string `+` 拼接、逗号节点列表、UTF-8 ID、简单布尔属性；后续再扩展完整 subgraph 布局和完整 DOT 语义。Graphviz HTML-like label 渲染明确不在项目范围内，angle-string 始终按纯文本处理。

## 编码接口要求

除了 DOT DSL，Vex 必须提供 Zig 代码里的图构建 API：

- 允许直接创建图对象。
- 允许添加节点、添加边、设置属性。
- 图模型中的节点身份由 `NodeId` 决定，显示文本使用 `label`；DOT/Mermaid 的 textual id 由解析器局部维护。
- 布局和渲染逻辑应面向这个统一图模型，而不是只绑定 DOT 文本输入。
- DOT 解析器应该只是把 DSL 转换为同一个图模型。
- 渲染输出需要保留后端分发层；当前 CLI/API 只注册 SVG 输出，后续可以按需要增删输出后端。默认路径必须是 Vex 原生实现，Graphviz `dot` 只用于测试对照。后续应继续把 parser/model/layout/SVG 从 `src/root.zig` 分阶段拆出。

建议 API 方向：

```zig
var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "G" });
defer graph.deinit();

const a = try graph.addNode("A", .{});
const b = try graph.addNode("B", .{});
try graph.addEdge(a, b, .{ .label = "A to B" });

var layout = try vex.layoutGraph(allocator, &graph, .{});
defer layout.deinit();
try vex.render(writer, &layout, .svg, .{});
```

## 初期实现路线

1. 初始化 Zig 项目结构。
2. 建立本指南，记录目标、兼容策略、API 要求和迭代方式。
3. 实现核心图模型与可编程构建 API。
4. 实现 DOT 子集解析器。
5. 实现一个基础层次布局（优先服务 `digraph`）。
6. 输出 SVG，作为当前最小可用渲染后端；SVG 文本必须做 XML 转义。
7. 添加 CLI：从 DOT 文件或 stdin 读取，按 `--format svg` 输出到文件或 stdout。
8. 添加测试和示例。
9. 建立 Graphviz oracle 对照测试：用 `dot` 生成期望语义/布局/渲染证据，但产品运行时不依赖 `dot`。

## 超越 Graphviz 的长期方向

- 更清晰的模块边界：parser / model / layout / renderer / CLI 分离。
- 保持输出后端可插拔：当前只保留 SVG；未来可按产品需要新增 Web Canvas/WebGPU、可搜索/可折叠交互图或其他格式。SVG 后端已经开始提供 Vex 原生扩展，例如通过 `--interactive-all` / `vex_interactive_all=true` / `SvgOptions.interactive_all` 一次启用当前 SVG-native 工具面板和 metadata，通过 `--svg-metadata` / `vex_svg_metadata=true` / `SvgOptions.metadata` 生成包含 graph structure、rank constraints、subgraph parent/member 关系、edge record/compass ports、compound subgraph endpoints、effective edge layout values、custom/future object attributes、layout/canvas、渲染 graph/node/edge/subgraph 对象 `data-vex-object-*` 属性、object layer、effective `href` / `tooltip` / `target`、graph/node/edge/subgraph 对象几何、node ranks、edge waypoints 和 layer 信息的机器可读对象索引，通过 `--interactive-layers` / `vex_interactive_layers=true` / `SvgOptions.interactive_layers` 生成自包含图层可见性控制，通过 `--interactive-collapse` / `vex_interactive_collapse=true` / `SvgOptions.interactive_collapse` 生成自包含子图折叠控制，通过 `--interactive-filter` / `vex_interactive_filter=true` / `SvgOptions.interactive_filter` 生成自包含对象类型过滤控制，通过 `--interactive-labels` / `vex_interactive_labels=true` / `SvgOptions.interactive_labels` 生成自包含标签可见性控制，通过 `--interactive-focus` / `vex_interactive_focus=true` / `SvgOptions.interactive_focus` 生成自包含邻域聚焦控制，通过 `--interactive-inspector` / `vex_interactive_inspector=true` / `SvgOptions.interactive_inspector` 生成自包含对象检查器，通过 `--interactive-search` / `vex_interactive_search=true` / `SvgOptions.interactive_search` 生成自包含搜索和高亮控制，通过 `--interactive-viewport` / `vex_interactive_viewport=true` / `SvgOptions.interactive_viewport` 生成自包含平移、缩放和重置控制，通过 `--interactive-minimap` / `vex_interactive_minimap=true` / `SvgOptions.interactive_minimap` 生成自包含概览导航，并通过 `--interactive-stats` / `vex_interactive_stats=true` / `SvgOptions.interactive_stats` 生成自包含图统计面板。
- 更好的增量布局：大图局部更新时保持心理地图稳定。
- 更强的可编程接口：Zig 原生 API，后续可提供 C ABI、WASM、Python/JS 绑定。
- 更好的错误诊断：DOT 解析错误已经带基础位置、上下文和 caret；后续继续扩展修复建议和更多语义诊断。
- 对大图友好：流式解析、可配置布局预算、并行布局阶段。CLI 已经提供 `--check` / `--validate` 作为 parse-only 验证入口，用于在 CI 或大图预览流程中只检查 DOT/Mermaid 输入并报告 graph/node/edge/subgraph 计数，不进入 layout/render；`--max-input-bytes` 作为 DOT/Mermaid 输入读取预算；force/neato 布局已经提供 `--layout-iterations` / `vex_layout_iterations` / `LayoutConfig.force.iterations` 作为迭代预算入口；layered/Sugiyama 布局已经提供 `--crossing-passes` / `--coordinate-passes`、`vex_crossing_passes` / `vex_coordinate_passes` 和 `LayoutConfig.layered` 作为 pass 预算入口。
