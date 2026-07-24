# Vex Python Binding

This dependency-free binding uses Python `ctypes` and the stable Vex C API v1.

Build the shared library:

```sh
zig build
```

Use it from the repository:

```python
from bindings.python.vex import Graph, RenderConfig, render_dot

with Graph("Python", directed=True) as graph:
    start = graph.add_node("Start")
    finish = graph.add_node("Finish")
    graph.add_edge(start, finish, "flow")
    svg = graph.render_svg(RenderConfig(layout="dot", metadata=True))

svg = render_dot(
    "graph G { a -- b }",
    RenderConfig(layout="neato", iterations=40),
)

svg = render_dot(
    "graph G { graph [root=center]; center -- a; center -- b }",
    RenderConfig(layout="twopi"),
)

svg = render_dot(
    "graph G { a -- b -- c -- a; c -- d -- e -- c }",
    RenderConfig(layout="circo"),
)

svg = render_dot(
    "graph G { a [area=1]; b [area=4] }",
    RenderConfig(layout="patchwork"),
)
```

Library lookup order:

1. `VEX_LIBRARY`
2. repository `zig-out/lib`
3. platform dynamic-loader search path

Run the real binding smoke:

```sh
zig build test-python-api
```
