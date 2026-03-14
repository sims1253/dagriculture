# Compute external block propagation

Propagates external holds through the topological order, marking
downstream nodes as blocked by the nearest upstream hold.

## Usage

``` r
dagri_external_blocked(graph, targets, topo_order, external_holds)
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

## Value

Named list of externally blocked nodes and their reasons.
