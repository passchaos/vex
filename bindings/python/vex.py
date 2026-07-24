"""Dependency-free ctypes binding for the Vex C API v1."""

from __future__ import annotations

import ctypes
import os
import pathlib
import sys
from dataclasses import dataclass
from typing import Final


class VexError(RuntimeError):
    """Base Vex binding error."""


class ParseError(VexError):
    """DOT parse failure."""


class LayoutCanceled(VexError):
    """Layout work budget exhausted."""


class _String(ctypes.Structure):
    _fields_ = [("data", ctypes.c_void_p), ("len", ctypes.c_size_t)]


class _Buffer(ctypes.Structure):
    _fields_ = [("data", ctypes.c_void_p), ("len", ctypes.c_size_t)]


class _RenderOptions(ctypes.Structure):
    _fields_ = [
        ("layout", ctypes.c_int),
        ("iterations", ctypes.c_size_t),
        ("work_budget", ctypes.c_size_t),
        ("metadata", ctypes.c_bool),
    ]


_STATUS_OK: Final = 0
_STATUS_PARSE: Final = 3
_STATUS_LAYOUT_CANCELED: Final = 6
_LAYOUTS: Final = {
    "dot": 0,
    "neato": 1,
    "fdp": 2,
    "sfdp": 3,
    "fr": 4,
    "twopi": 5,
    "circo": 6,
    "patchwork": 7,
}


def _library_names() -> tuple[str, ...]:
    if sys.platform == "darwin":
        return ("libvex_c.1.dylib", "libvex_c.dylib")
    if os.name == "nt":
        return ("vex_c.dll", "libvex_c.dll")
    return ("libvex_c.so.1", "libvex_c.so")


def _load_library() -> ctypes.CDLL:
    explicit = os.environ.get("VEX_LIBRARY")
    candidates: list[pathlib.Path | str] = []
    if explicit:
        candidates.append(pathlib.Path(explicit))

    root = pathlib.Path(__file__).resolve().parents[2]
    candidates.extend(root / "zig-out" / "lib" / name for name in _library_names())
    candidates.extend(_library_names())

    errors: list[str] = []
    for candidate in candidates:
        try:
            return ctypes.CDLL(str(candidate))
        except OSError as error:
            errors.append(f"{candidate}: {error}")
    raise OSError("unable to load Vex C API library\n" + "\n".join(errors))


_lib = _load_library()
_lib.vex_c_api_version.argtypes = []
_lib.vex_c_api_version.restype = ctypes.c_uint32
_lib.vex_graph_create.argtypes = [
    ctypes.c_bool,
    _String,
    ctypes.POINTER(ctypes.c_void_p),
    ctypes.POINTER(_Buffer),
]
_lib.vex_graph_create.restype = ctypes.c_int
_lib.vex_graph_destroy.argtypes = [ctypes.c_void_p]
_lib.vex_graph_destroy.restype = None
_lib.vex_graph_add_node.argtypes = [
    ctypes.c_void_p,
    _String,
    ctypes.POINTER(ctypes.c_size_t),
    ctypes.POINTER(_Buffer),
]
_lib.vex_graph_add_node.restype = ctypes.c_int
_lib.vex_graph_add_edge.argtypes = [
    ctypes.c_void_p,
    ctypes.c_size_t,
    ctypes.c_size_t,
    _String,
    ctypes.POINTER(ctypes.c_size_t),
    ctypes.POINTER(_Buffer),
]
_lib.vex_graph_add_edge.restype = ctypes.c_int
_lib.vex_graph_render_svg.argtypes = [
    ctypes.c_void_p,
    _RenderOptions,
    ctypes.POINTER(_Buffer),
    ctypes.POINTER(_Buffer),
]
_lib.vex_graph_render_svg.restype = ctypes.c_int
_lib.vex_dot_render_svg.argtypes = [
    _String,
    _RenderOptions,
    ctypes.POINTER(_Buffer),
    ctypes.POINTER(_Buffer),
]
_lib.vex_dot_render_svg.restype = ctypes.c_int
_lib.vex_buffer_free.argtypes = [_Buffer]
_lib.vex_buffer_free.restype = None

if _lib.vex_c_api_version() != 1:
    raise RuntimeError("unsupported Vex C API version")


def _view(text: str) -> tuple[_String, ctypes.Array[ctypes.c_char]]:
    encoded = text.encode("utf-8")
    storage = ctypes.create_string_buffer(encoded, len(encoded) + 1)
    return _String(ctypes.cast(storage, ctypes.c_void_p), len(encoded)), storage


def _take_buffer(buffer: _Buffer) -> bytes:
    if not buffer.data or not buffer.len:
        return b""
    try:
        return ctypes.string_at(buffer.data, buffer.len)
    finally:
        _lib.vex_buffer_free(buffer)


def _check(status: int, error: _Buffer) -> None:
    if status == _STATUS_OK:
        if error.data:
            _lib.vex_buffer_free(error)
        return
    message = _take_buffer(error).decode("utf-8", errors="replace")
    if status == _STATUS_PARSE:
        raise ParseError(message)
    if status == _STATUS_LAYOUT_CANCELED:
        raise LayoutCanceled(message)
    raise VexError(message or f"Vex failed with status {status}")


def _options(
    layout: str,
    iterations: int,
    work_budget: int,
    metadata: bool,
) -> _RenderOptions:
    try:
        engine = _LAYOUTS[layout.lower()]
    except KeyError as error:
        raise ValueError(f"unknown layout: {layout}") from error
    if iterations < 0 or work_budget < 0:
        raise ValueError("iterations and work_budget must be non-negative")
    return _RenderOptions(engine, iterations, work_budget, metadata)


@dataclass(frozen=True)
class RenderConfig:
    layout: str = "dot"
    iterations: int = 0
    work_budget: int = 0
    metadata: bool = False

    def native(self) -> _RenderOptions:
        return _options(self.layout, self.iterations, self.work_budget, self.metadata)


class Graph:
    def __init__(self, name: str = "G", directed: bool = True):
        name_view, name_storage = _view(name)
        handle = ctypes.c_void_p()
        error = _Buffer()
        status = _lib.vex_graph_create(directed, name_view, ctypes.byref(handle), ctypes.byref(error))
        del name_storage
        _check(status, error)
        self._handle = handle

    def close(self) -> None:
        handle = getattr(self, "_handle", None)
        if handle:
            _lib.vex_graph_destroy(handle)
            self._handle = ctypes.c_void_p()

    def __enter__(self) -> Graph:
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def __del__(self) -> None:
        self.close()

    def add_node(self, label: str) -> int:
        view, storage = _view(label)
        output = ctypes.c_size_t()
        error = _Buffer()
        status = _lib.vex_graph_add_node(
            self._handle, view, ctypes.byref(output), ctypes.byref(error)
        )
        del storage
        _check(status, error)
        return output.value

    def add_edge(self, source: int, target: int, label: str = "") -> int:
        view, storage = _view(label)
        output = ctypes.c_size_t()
        error = _Buffer()
        status = _lib.vex_graph_add_edge(
            self._handle,
            source,
            target,
            view,
            ctypes.byref(output),
            ctypes.byref(error),
        )
        del storage
        _check(status, error)
        return output.value

    def render_svg(self, config: RenderConfig = RenderConfig()) -> str:
        output = _Buffer()
        error = _Buffer()
        status = _lib.vex_graph_render_svg(
            self._handle, config.native(), ctypes.byref(output), ctypes.byref(error)
        )
        _check(status, error)
        return _take_buffer(output).decode("utf-8")


def render_dot(dot: str, config: RenderConfig = RenderConfig()) -> str:
    view, storage = _view(dot)
    output = _Buffer()
    error = _Buffer()
    status = _lib.vex_dot_render_svg(
        view, config.native(), ctypes.byref(output), ctypes.byref(error)
    )
    del storage
    _check(status, error)
    return _take_buffer(output).decode("utf-8")
