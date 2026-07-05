# Get the structural closure of target nodes

Get the structural closure of target nodes

## Usage

``` r
dagri_target_closure(graph, targets = NULL, index = NULL)
```

## Arguments

- graph:

  A `dagri_graph`.

- targets:

  Optional target nodes.

- index:

  Optional pre-built adjacency index from
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md).

## Details

O(V+E).
