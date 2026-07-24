#ifndef VEX_H
#define VEX_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define VEX_C_API_VERSION 1u

typedef struct vex_graph vex_graph;

typedef struct vex_string {
    const char *data;
    size_t len;
} vex_string;

typedef struct vex_buffer {
    char *data;
    size_t len;
} vex_buffer;

typedef enum vex_status {
    VEX_OK = 0,
    VEX_ERROR_INVALID_ARGUMENT = 1,
    VEX_ERROR_OUT_OF_MEMORY = 2,
    VEX_ERROR_PARSE = 3,
    VEX_ERROR_INVALID_NODE = 4,
    VEX_ERROR_UNKNOWN_LAYOUT = 5,
    VEX_ERROR_LAYOUT_CANCELED = 6,
    VEX_ERROR_INTERNAL = 255
} vex_status;

typedef enum vex_layout {
    VEX_LAYOUT_DOT = 0,
    VEX_LAYOUT_NEATO = 1,
    VEX_LAYOUT_FDP = 2,
    VEX_LAYOUT_SFDP = 3,
    VEX_LAYOUT_FR = 4,
    VEX_LAYOUT_TWOPI = 5,
    VEX_LAYOUT_CIRCO = 6
} vex_layout;

typedef struct vex_render_options {
    vex_layout layout;
    size_t iterations;
    size_t work_budget;
    bool metadata;
} vex_render_options;

uint32_t vex_c_api_version(void);

vex_status vex_graph_create(
    bool directed,
    vex_string name,
    vex_graph **out_graph,
    vex_buffer *out_error
);

void vex_graph_destroy(vex_graph *graph);

vex_status vex_graph_add_node(
    vex_graph *graph,
    vex_string label,
    size_t *out_node_id,
    vex_buffer *out_error
);

vex_status vex_graph_add_edge(
    vex_graph *graph,
    size_t from,
    size_t to,
    vex_string label,
    size_t *out_edge_id,
    vex_buffer *out_error
);

vex_status vex_graph_render_svg(
    const vex_graph *graph,
    vex_render_options options,
    vex_buffer *out_svg,
    vex_buffer *out_error
);

vex_status vex_dot_render_svg(
    vex_string dot,
    vex_render_options options,
    vex_buffer *out_svg,
    vex_buffer *out_error
);

void vex_buffer_free(vex_buffer buffer);

#ifdef __cplusplus
}
#endif

#endif
