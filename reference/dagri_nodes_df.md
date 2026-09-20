# Tabular view of graph nodes

Builds a base `data.frame` with one row per node, for reporting and
quick inspection. Rows follow graph insertion order (the order of the
`graph$nodes` map); sort or subset the result explicitly when a
different order is needed.

## Usage

``` r
dagri_nodes_df(graph)
```

## Arguments

- graph:

  A `dagri_graph`.

## Value

A base `data.frame` with one row per node and these columns, in this
exact order:

- `id`, `kind`, `state`, `block_reason`: character.

- `label`: character; `NA_character_` when the node has no label.

- `params`, `metadata`: list-columns; each cell is the node's stored
  `params`/`metadata` list, verbatim.

Node ids live in the `id` column as character values and the frame
carries plain automatic row names — ids never become row names. An empty
graph returns a zero-row frame with identical column names and
per-column classes.

## Details

Aborts with class `dagri_error_invalid_argument` when `graph` is not a
valid `dagri_graph`.

`state` and `block_reason` mirror the STORED node fields — whatever
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md)
last wrote (`"new"` / `"none"` until then). This is an accessor, not a
planner: it never derives state.

## Examples

``` r
registry <- dagri_registry(dagri_kind("source"), dagri_kind("fit"))
graph <- dagri_graph(registry) |>
  dagri_add_node("data", "source", label = "Data") |>
  dagri_add_node("fit", "fit", params = list(method = "lm")) |>
  dagri_add_edge("data", "fit", id = "e1")

nodes <- dagri_nodes_df(graph)
nodes[, c("id", "kind", "label", "state")]
#>     id   kind label state
#> 1 data source  Data   new
#> 2  fit    fit  <NA>   new
nodes$params
#> [[1]]
#> list()
#> 
#> [[2]]
#> [[2]]$method
#> [1] "lm"
#> 
#> 
```
