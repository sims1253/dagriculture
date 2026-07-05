# Get blocked nodes

Returns a named list of nodes whose stored state is "blocked" mapped to
their block reasons. Reflects the last
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md)
pass; call it again after structural or gate changes.
[`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md)
recomputes state internally and is always current.

## Usage

``` r
dagri_blocked(graph)
```

## Arguments

- graph:

  A `dagri_graph`.
