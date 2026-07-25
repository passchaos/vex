# Vex SVG Metadata v1

Vex 的 opt-in SVG metadata 是面向工具的机器可读契约。启用入口为
`--svg-metadata`、`vex_svg_metadata=true` 或 `SvgOptions.metadata`。

## 版本发现

启用后，SVG 同时提供：

- `<metadata id="vex-metadata" data-vex-schema-version="1" data-vex-schema-uri="https://vex.graph/svg-metadata/1">`
- `<vex:graph xmlns:vex="https://vex.graph/svg-metadata/1" schema-version="1" ...>`
- 根渲染 group 的 `data-vex-object-*` 属性。

namespace URI 的最后一段是 schema major version。消费者必须按 namespace
选择解析器，不能只依赖元素局部名。

## v1 内容

`<vex:graph>` 包含：

- graph 方向、strict、rankdir、对象计数、layout/canvas/viewBox。
- `<vex:rank-constraints>`；每个 `<vex:rank>` 包含 kind、node IDs，并在
  约束声明于 named subgraph 时包含可选 `scope` subgraph ID。
- `<vex:attributes>`，保留 graph/node/edge/subgraph 的自定义和未来属性。
- `<vex:node>`，包含 shape、rank 和 geometry。
- `<vex:edge>`，包含端点、ports、compound subgraph endpoints、有效布局属性、
  geometry、`<vex:waypoint>`，以及 nop2 保留路径的 `<vex:spline>` /
  `<vex:point>`。
- `<vex:subgraph>`，包含 parent/member 关系和 geometry。

渲染 group 上的 `data-vex-object-*` 是同一对象索引的 DOM 快速访问面；
nop2 的保留路径通过 `data-vex-object-path` 暴露为 SVG path command。

## 兼容策略

- v1 内允许新增可选 element、attribute、feature token。
- 消费者必须忽略未知可选 element、attribute 和 feature token。
- v1 内不会改变既有字段含义或 ID 关联方式。
- 删除字段、改变字段含义、改变 ID 语义或改变必需结构属于破坏性变化，
  必须发布新的 namespace major version。
- 未启用 metadata 时，不输出 schema 标记和 `data-vex-object-*`。

## Feature Tokens

`features` 是空格分隔、可扩展的能力列表。v1 当前声明：

`attributes edge-geometry edge-layout edge-paths edge-ports edge-waypoints links object-geometry ranks subgraph-hierarchy`

消费者应以实际元素/属性为准，feature token 用于快速能力发现。
