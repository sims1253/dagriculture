# Compute external block propagation

Propagates external holds through the topological order, marking
downstream nodes as blocked by the nearest upstream hold.

## Usage

``` r
dagri_external_blocked(
  graph,
  targets,
  topo_order,
  external_holds,
  index = NULL
)
```

## Arguments

- graph:

  A `dagri_graph`.

- targets:

  Target node IDs.

- topo_order:

  Topological ordering of nodes.

- external_holds:

  Named list mapping node IDs to hold reasons.

- index:

  Optional pre-built adjacency index from
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md).

## Value

Named list of externally blocked nodes and their reasons.

## Details

O(V+E).
