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
with components:

- `targets`:

  Character vector of the planned target closure (the requested targets
  plus all their ancestors).

- `topo_order`:

  Character vector of `targets` in topological order.

- `eligible`:

  Character vector of structurally ready nodes within `targets`.
  External holds never remove a node from this set.

- `blocked`:

  Named list mapping each structurally blocked target to its derived
  block reason (`"gate"` or `"upstream_blocked"`).

- `external_blocked`:

  Named list mapping each externally held target — and every target
  downstream of it — to the propagated hold reason. A node can appear
  here and in `eligible` at the same time: structural eligibility and
  external blocking are separate.

- `terminal`:

  Character vector of targets with no downstream neighbors inside
  `targets`.

- `pending_gates`:

  Character vector of pending gate ids on inbound edges of the target
  closure, in gate insertion order.

- `node_status`:

  Named list keyed by node id covering exactly `targets`, ordered by
  `topo_order`. Each entry is a named list with:

  `state`

  :   Single string: the derived structural state (`"ready"` or
      `"blocked"`) after the internal recompute.

  `block_reason`

  :   Single string: the structural block reason (`"none"`, `"gate"`, or
      `"upstream_blocked"`).

  `pending_gates`

  :   Character vector of pending gate ids attached to the node's
      inbound edges, in deterministic order — edge insertion order, then
      gate insertion order within each edge; `character(0)` when none.

  `external_hold`

  :   `NULL` when the node is not externally blocked; otherwise the
      single-string propagated hold reason (the same value
      `external_blocked[[id]]` carries).

  `upstream_blockers`

  :   Character vector of direct upstream neighbor ids (incoming-edge
      sources) whose derived state is not `"ready"`; unique, in
      incoming-edge insertion order; `character(0)` when none.

  `eligible`

  :   Single logical: structural eligibility, identical to membership in
      the plan's `eligible` field. Deliberately remains `TRUE` when the
      node is externally held — structural eligibility and external
      blocking are separate axes, so an entry can carry
      `eligible = TRUE` together with a non-`NULL` `external_hold`.

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
