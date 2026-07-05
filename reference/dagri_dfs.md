# Depth-first traversal over a dagriculture graph

Internal helper. Callers must validate the graph and pass a pre-built
adjacency `index`. Neighbors are read from `index` (O(1) per lookup), so
the walk is O(V+E).

## Usage

``` r
dagri_dfs(start, direction = c("forward", "reverse"), index)
```

## Arguments

- start:

  Starting node ID.

- direction:

  One of `"forward"` (downstream, via `index$forward`) or `"reverse"`
  (upstream, via `index$reverse`).

- index:

  Adjacency index from
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md).

## Value

Character vector of visited node ids (excluding `start`).
