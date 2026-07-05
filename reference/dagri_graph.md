# Create an empty dagriculture graph

Returns a new immutable graph carrying the given registry and empty
node/edge/gate collections. The result has S3 class
`c("dagri_graph", "list")` so
[`print.dagri_graph()`](https://sims1253.github.io/dagriculture/reference/print.dagri_graph.md)
dispatches; underneath it remains a plain named list and serializes
identically to before. Graph-mutating functions
([`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md),
[`dagri_add_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_add_edge.md),
...) preserve the class on the returned copy.

## Usage

``` r
dagri_graph(registry)
```

## Arguments

- registry:

  A `dagri_registry` object.

## Value

A `dagri_graph` (a named list with S3 class `c("dagri_graph", "list")`).
