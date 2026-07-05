# Recompute graph state against a pre-built adjacency index

Pure worker shared by
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md)
and
[`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md).
Returns a new graph value with `state`/`block_reason` rewritten in
topological order.

## Usage

``` r
dagri_recompute_state_impl(graph, index)
```

## Arguments

- graph:

  A `dagri_graph`.

- index:

  Adjacency index from
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md).

## Value

A new `dagri_graph` value with derived node states.
