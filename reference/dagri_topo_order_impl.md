# Internal topological-order worker

Pure worker shared by
[`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)
and the planning/state internals. Callers must validate the graph and
build (or pass) the adjacency `index`.

## Usage

``` r
dagri_topo_order_impl(graph, subset = NULL, index)
```

## Arguments

- graph:

  A `dagri_graph`.

- subset:

  Optional subset of nodes; validated via
  [`dagri_validate_node_ids()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_node_ids.md)
  when non-NULL.

- index:

  Adjacency index from
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md).

## Value

Character vector of node ids in topological order.
