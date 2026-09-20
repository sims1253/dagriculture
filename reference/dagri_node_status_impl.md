# Build the per-node status view for a plan

Pure worker shared by
[`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md):
assembles the per-node `node_status` map — one entry per node in
`topo_order`, each carrying the derived structural state, its block
reason, the pending gates on the node's inbound edges, the propagated
external hold reason, the direct structurally blocked upstream
neighbors, and final structural eligibility.

## Usage

``` r
dagri_node_status_impl(graph, topo_order, external_blocked, index)
```

## Arguments

- graph:

  A `dagri_graph` with derived states from
  [`dagri_recompute_state_impl()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state_impl.md).

- topo_order:

  Character vector of node ids in topological order (the plan's target
  closure).

- external_blocked:

  Named list from
  [`dagri_external_blocked()`](https://sims1253.github.io/dagriculture/reference/dagri_external_blocked.md).

- index:

  Adjacency index from
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md).

## Value

A named list keyed by node id, in `topo_order` order; each entry is a
named list with `state`, `block_reason`, `pending_gates`,
`external_hold`, `upstream_blockers`, and `eligible`.

## Details

Structural eligibility and external blocking stay separate: `eligible`
is `TRUE` whenever the derived state is "ready", even when the node
carries an `external_hold` (mirroring the deliberate overlap between
`plan$eligible` and `plan$external_blocked`).

Deterministic ordering: entries follow `topo_order`; `pending_gates`
follows incoming-edge insertion order, then gate insertion order within
each edge; `upstream_blockers` follows incoming-edge insertion order and
is unique.
