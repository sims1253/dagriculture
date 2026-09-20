# Update an edge in a dagriculture graph

Update an edge in a dagriculture graph

## Usage

``` r
dagri_update_edge(graph, edge_id, type = NULL, metadata = NULL)
```

## Arguments

- graph:

  A `dagri_graph`.

- edge_id:

  Edge ID.

- type:

  Edge type. When non-`NULL`, must be a single non-empty string and
  **replaces** the existing `type` (see Details).

- metadata:

  Edge metadata. When non-`NULL`, **replaces** the existing `metadata`
  outright (see Details); must be a named list of plain data (closures,
  environments, formulas, language objects, S4 objects, external
  pointers, and weak references are rejected recursively).

## Value

A new `dagri_graph` with the edge updated and `version` bumped by 1 (the
bump happens even when both field arguments are `NULL`); the input graph
is not modified. `from`/`to` cannot be changed — remove and re-add the
edge to rewire it.

## Details

`metadata` (when non-`NULL`) **replaces** the edge's `metadata`
outright; it is NOT merged into the existing metadata. To merge partial
updates, do it in the caller, e.g.
`dagri_update_edge(graph, edge_id, metadata = utils::modifyList(old_metadata, new_metadata))`.
A `NULL` `type`/`metadata` leaves that field untouched. This mirrors
[`dagri_update_node()`](https://sims1253.github.io/dagriculture/reference/dagri_update_node.md)'s
replace-not-merge primitive: consumers must opt into merge explicitly
instead of silently having a partial update destroy sibling fields.

Known boundary:
[`dagri_graph_diff()`](https://sims1253.github.io/dagriculture/reference/dagri_graph_diff.md)
is a structural id diff — it reports only added/removed node and edge
ids, so metadata and `type` edits made here do not surface in its
output.

## Errors

- `dagri_error_invalid_argument` when `graph` is malformed, `edge_id` is
  not a single non-empty string, `type` is not a single non-empty
  string, or `metadata` is not a named list of plain data.

- `dagri_error_not_found` when `edge_id` is not an edge in the graph.

## Examples

``` r
reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
g <- dagri_graph(reg) |>
  dagri_add_node("raw", "source") |>
  dagri_add_node("fit", "process") |>
  dagri_add_edge("raw", "fit", id = "e1", metadata = list(weight = 1))

g2 <- dagri_update_edge(g, "e1", type = "control", metadata = list(weight = 2))
g2$edges[["e1"]]$type
#> [1] "control"
g2$edges[["e1"]]$metadata
#> $weight
#> [1] 2
#> 
```
