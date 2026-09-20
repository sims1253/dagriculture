# Tabular view of graph edges

Builds a base `data.frame` with one row per edge, for reporting and
quick inspection. Rows follow graph insertion order (the order of the
`graph$edges` map); sort or subset the result explicitly when a
different order is needed.

## Usage

``` r
dagri_edges_df(graph)
```

## Arguments

- graph:

  A `dagri_graph`.

## Value

A base `data.frame` with one row per edge and these columns, in this
exact order:

- `id`, `from`, `to`, `type`: character.

- `metadata`: list-column; each cell is the edge's stored `metadata`
  list, verbatim.

Edge ids live in the `id` column as character values and the frame
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
  dagri_add_edge("data", "fit", id = "e1", metadata = list(weight = 2))

edges <- dagri_edges_df(graph)
edges[, c("id", "from", "to", "type")]
#>   id from  to type
#> 1 e1 data fit data
edges$metadata
#> [[1]]
#> [[1]]$weight
#> [1] 2
#> 
#> 
```
