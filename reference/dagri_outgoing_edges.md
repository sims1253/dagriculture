# Outgoing edges for a node

Returns the edge objects whose `from` endpoint is `node_id`, preserving
the container names of `graph$edges`. Unlike
[`dagri_downstream()`](https://sims1253.github.io/dagriculture/reference/dagri_downstream.md),
which returns neighbor node ids, this returns the full edge objects so
callers can inspect edge ids, types, and metadata.

## Usage

``` r
dagri_outgoing_edges(graph, node_id)
```

## Arguments

- graph:

  A `dagri_graph`.

- node_id:

  Single character string naming a node in `graph`.

## Value

A named list of edge objects (possibly empty).

## Examples

``` r
graph <- dagri_graph(dagri_registry(dagri_kind("source"), dagri_kind("fit")))
graph <- dagri_add_node(graph, "data", "source")
graph <- dagri_add_node(graph, "fit", "fit")
graph <- dagri_add_edge(graph, "data", "fit", id = "e1")
outgoing <- dagri_outgoing_edges(graph, "data")
length(outgoing) == 1
#> [1] TRUE
```
