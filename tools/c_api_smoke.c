#include "vex.h"

#include <stdio.h>
#include <string.h>

static int contains(const char *data, size_t len, const char *needle) {
    const size_t needle_len = strlen(needle);
    if (needle_len == 0) {
        return 1;
    }
    if (needle_len > len) {
        return 0;
    }
    for (size_t i = 0; i + needle_len <= len; i++) {
        if (memcmp(data + i, needle, needle_len) == 0) {
            return 1;
        }
    }
    return 0;
}

static vex_string view(const char *text) {
    vex_string result = {text, strlen(text)};
    return result;
}

static int check(vex_status status, vex_buffer *error) {
    if (status == VEX_OK) {
        return 1;
    }
    if (error->data != NULL) {
        fwrite(error->data, 1, error->len, stderr);
        fputc('\n', stderr);
        vex_buffer_free(*error);
        error->data = NULL;
        error->len = 0;
    }
    return 0;
}

int main(void) {
    if (vex_c_api_version() != VEX_C_API_VERSION) {
        return 1;
    }

    vex_graph *graph = NULL;
    vex_buffer error = {0};
    if (!check(vex_graph_create(true, view("C Smoke"), &graph, &error), &error)) {
        return 2;
    }

    size_t start = 0;
    size_t finish = 0;
    size_t edge = 0;
    if (!check(vex_graph_add_node(graph, view("Start"), &start, &error), &error) ||
        !check(vex_graph_add_node(graph, view("Finish"), &finish, &error), &error) ||
        !check(vex_graph_add_edge(graph, start, finish, view("flow"), &edge, &error), &error)) {
        vex_graph_destroy(graph);
        return 3;
    }

    vex_buffer svg = {0};
    vex_render_options options = {
        .layout = VEX_LAYOUT_DOT,
        .iterations = 0,
        .work_budget = 0,
        .metadata = true,
    };
    if (!check(vex_graph_render_svg(graph, options, &svg, &error), &error)) {
        vex_graph_destroy(graph);
        return 4;
    }
    const int ok = svg.len > 0 &&
        contains(svg.data, svg.len, "<title>C Smoke</title>") &&
        contains(svg.data, svg.len, "data-vex-schema-version=\"1\"");
    vex_buffer_free(svg);

    options.layout = VEX_LAYOUT_TWOPI;
    options.metadata = false;
    svg.data = NULL;
    svg.len = 0;
    if (!check(vex_graph_render_svg(graph, options, &svg, &error), &error)) {
        vex_graph_destroy(graph);
        return 6;
    }
    const int twopi_ok = svg.len > 0;
    vex_buffer_free(svg);
    vex_graph_destroy(graph);
    return ok && twopi_ok ? 0 : 5;
}
