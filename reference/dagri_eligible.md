# Get eligible nodes

Returns IDs of nodes whose state is "ready". Call
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md)
before using this function to ensure node states are current.

## Usage

``` r
dagri_eligible(graph)
```

## Arguments

- graph:

  A `dagri_graph`.
