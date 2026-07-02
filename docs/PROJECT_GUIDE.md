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
- 当前应覆盖实用 DOT 子集：`strict`、subgraph/cluster 语法外壳、subgraph 作为边操作数、ports、HTML-like labels/IDs 文本化、Graphviz 常见字符串转义（`\n`/`\l`/`\r`、引号、反斜杠、续行）、quoted string `+` 拼接、逗号节点列表、UTF-8 ID、简单布尔属性；后续再扩展完整 cluster 布局、HTML label 渲染和完整 DOT 语义。

## 编码接口要求

除了 DOT DSL，Vex 必须提供 Zig 代码里的图构建 API：

- 允许直接创建图对象。
- 允许添加节点、添加边、设置属性。
- 布局和渲染逻辑应面向这个统一图模型，而不是只绑定 DOT 文本输入。
- DOT 解析器应该只是把 DSL 转换为同一个图模型。
- 渲染输出需要后端化，CLI/API 同时面向 terminal、SVG、PNG、PDF 等格式；默认路径必须是 Vex 原生实现，Graphviz `dot` 只用于测试对照。

建议 API 方向：

```zig
var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "G" });
defer graph.deinit();

const a = try graph.node("A");
const b = try graph.node("B");
try graph.edge(a, b, .{ .label = "A to B" });

var layout = try vex.layoutSugiyama(allocator, graph);
defer layout.deinit();
try vex.renderSvg(writer, graph, layout, .{});
```

## 初期实现路线

1. 初始化 Zig 项目结构。
2. 建立本指南，记录目标、兼容策略、API 要求和迭代方式。
3. 实现核心图模型与可编程构建 API。
4. 实现 DOT 子集解析器。
5. 实现一个基础层次布局（优先服务 `digraph`）。
6. 输出 SVG 和 terminal 文本预览，作为最小可用渲染后端；SVG 文本必须做 XML 转义。
7. 添加 CLI：从 DOT 文件或 stdin 读取，按 `--format terminal|svg|png|pdf` 输出到文件或 stdout；PNG/PDF 可先以明确的 UnsupportedFormat 错误占位。
8. 添加测试和示例。
9. 建立 Graphviz oracle 对照测试：用 `dot` 生成期望语义/布局/渲染证据，但产品运行时不依赖 `dot`。

## 超越 Graphviz 的长期方向

- 更清晰的模块边界：parser / model / layout / renderer / CLI 分离。
- 支持多输出后端：terminal 快速预览、SVG、PNG、PDF，以及未来的 Web Canvas/WebGPU、可搜索/可折叠交互图。
- 更好的增量布局：大图局部更新时保持心理地图稳定。
- 更强的可编程接口：Zig 原生 API，后续可提供 C ABI、WASM、Python/JS 绑定。
- 更好的错误诊断：DOT 解析错误带位置、上下文和修复建议。
- 对大图友好：流式解析、可配置布局预算、并行布局阶段。
