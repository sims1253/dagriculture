# Add an edge to a dagriculture graph

Add an edge to a dagriculture graph

## Usage

``` r
dagri_add_edge(graph, from, to, type = "data", id = NULL, metadata = list())
```

## Arguments

- graph:

  A `dagri_graph`.

- from:

  Upstream node ID.

- to:

  Downstream node ID.

- type:

  Edge type.

- id:

  Optional Edge ID.

- metadata:

  Opaque caller-owned extension data: a named list of plain data (nested
  lists, vectors, and scalars are fine). Closures, environments,
  formulas, language objects, S4 objects, external pointers, and weak
  references are rejected recursively.

## Value

A new `dagri_graph` with the edge added and `version` bumped by 1; the
input graph is not modified.

## Errors

- `dagri_error_invalid_argument` when `graph` is malformed,
  `from`/`to`/`id` is not a single non-empty string, `type` is not a
  single non-empty string, or `metadata` is not a named list of plain
  data.

- `dagri_error_not_found` when `from` or `to` is not a node in the
  graph.

- `dagri_error_duplicate_id` when `id` already exists as an edge.

- `dagri_error_cycle` when the edge would create a cycle.

## Examples

``` r
reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
g <- dagri_graph(reg) |>
  dagri_add_node("raw", "source") |>
  dagri_add_node("fit", "process") |>
  dagri_add_edge("raw", "fit", metadata = list(weight = 2))
g$edges[["edge_raw_fit"]]$metadata
#> $weight
#> [1] 2
#> 
```
