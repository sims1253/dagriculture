# Tabular view of graph gates

Builds a base `data.frame` with one row per gate, for reporting and
quick inspection. Rows follow graph insertion order (the order of the
`graph$gates` map); sort or subset the result explicitly when a
different order is needed.

## Usage

``` r
dagri_gates_df(graph)
```

## Arguments

- graph:

  A `dagri_graph`.

## Value

A base `data.frame` with one row per gate and these columns, in this
exact order:

- `id`, `edge_id`, `status`: character.

- `metadata`: list-column; each cell is the gate's stored `metadata`
  list, verbatim.

Gate ids live in the `id` column as character values and the frame
carries plain automatic row names — ids never become row names. An empty
graph returns a zero-row frame with identical column names and
per-column classes.

## Details

Aborts with class `dagri_error_invalid_argument` when `graph` is not a
valid `dagri_graph`.

## Examples

``` r
registry <- dagri_registry(dagri_kind("source"), dagri_kind("fit"))
graph <- dagri_graph(registry) |>
  dagri_add_node("data", "source") |>
  dagri_add_node("fit", "fit") |>
  dagri_add_edge("data", "fit", id = "e1") |>
  dagri_add_gate("e1", id = "review")

gates <- dagri_gates_df(graph)
gates[, c("id", "edge_id", "status")]
#>       id edge_id  status
#> 1 review      e1 pending
gates$metadata
#> [[1]]
#> list()
#> 
```
