# Vex C API v1

Vex 提供稳定的 C ABI v1，用于 C、C++、Python FFI、Rust FFI 和其他运行时绑定。

## 构建产物

`zig build` 安装：

- `zig-out/include/vex.h`
- `zig-out/lib/libvex_c.a`

运行真实 C 客户端 smoke：

```sh
zig build test-c-api
```

## 版本与兼容

- `VEX_C_API_VERSION` 和 `vex_c_api_version()` 当前为 `1`。
- v1 允许新增函数、enum 值和带 size/version 的新 options struct。
- v1 不改变既有函数签名、status 数值、enum 数值或 buffer ownership。
- 破坏性变化必须发布新的 ABI major version。
- caller 应处理未知 status/enum 值，不应假定枚举永远穷尽。

## 字符串与内存

- `vex_string` 是 `(data, len)` view，不要求 NUL 结尾，调用期间有效即可。
- `vex_buffer` 由 Vex 分配，可能不以 NUL 结尾。
- 所有非空 `vex_buffer` 必须用 `vex_buffer_free` 释放。
- `vex_graph_destroy(NULL)` 和 `vex_buffer_free({NULL, 0})` 安全。

## API 面

- `vex_graph_create` / `vex_graph_destroy`
- `vex_graph_add_node`
- `vex_graph_add_edge`
- `vex_graph_render_svg`
- `vex_dot_render_svg`
- `vex_buffer_free`

`vex_render_options` 支持 dot/neato/fdp/sfdp/fr/twopi/circo/patchwork/osage/nop/nop2、迭代预算、work budget 取消和
SVG metadata v1。
