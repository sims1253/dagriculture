# Create a structural plan

Create a structural plan

## Usage

``` r
dagri_plan(graph, targets = NULL, external_holds = list())
```

## Arguments

- graph:

  A `dagri_graph`.

- targets:

  Optional target nodes.

- external_holds:

  Optional named list mapping node ids to external hold reason strings.
  These affect planning output without mutating graph state.

## Value

A `dagri_plan` (a named list with S3 class `c("dagri_plan", "list")`)
with components `targets`, `topo_order`, `eligible`, `blocked`,
`external_blocked`, `terminal`, and `pending_gates`.

## Details

O(V+E). State is derived internally, so the plan is always current even
if the input graph was never passed through
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md);
the input graph value itself is not mutated.

The result carries S3 class `c("dagri_plan", "list")` so
[`print.dagri_plan()`](https://sims1253.github.io/dagriculture/reference/print.dagri_plan.md)
dispatches; underneath it remains a plain named list with the fields
documented below. Field access (`plan$targets`, etc.) and serialization
are unchanged.
