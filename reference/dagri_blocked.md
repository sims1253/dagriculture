# Get blocked nodes

Returns a named list of blocked nodes mapped to their block reasons.
Call
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md)
before using this function to ensure node states are current.

## Usage

``` r
dagri_blocked(graph)
```

## Arguments

- graph:

  A `dagri_graph`.
