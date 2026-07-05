# Structural diff of two graphs

Returns a pure structural diff with no workflow semantics: which node
and edge ids were added or removed going from `before` to `after`. Nodes
use `names(graph$nodes)`; edges use
[`dagri_edge_ids()`](https://sims1253.github.io/dagriculture/reference/dagri_edge_ids.md)
so both named-map storage and unnamed edge lists with embedded ids are
supported.

## Usage

``` r
dagri_graph_diff(before, after)
```

## Arguments

- before:

  A `dagri_graph` (the prior state).

- after:

  A `dagri_graph` (the new state).

## Value

A list with `added_nodes`, `removed_nodes`, `added_edges`, and
`removed_edges` (each a character vector).

## Examples

``` r
reg <- dagri_registry(dagri_kind("source"), dagri_kind("fit"))
before <- dagri_graph(reg) |>
  dagri_add_node("data", "source") |>
  dagri_add_node("fit", "fit") |>
  dagri_add_edge("data", "fit", id = "e1")
after <- dagri_add_node(before, "diag", "fit")
diff <- dagri_graph_diff(before, after)
diff$added_nodes
#> [1] "diag"
```
