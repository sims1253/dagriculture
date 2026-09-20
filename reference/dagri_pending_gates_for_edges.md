# Collect pending gate ids on a set of edges

Pure worker shared by
[`dagri_node_status_impl()`](https://sims1253.github.io/dagriculture/reference/dagri_node_status_impl.md)
and
[`dagri_recompute_state_impl()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state_impl.md):
returns the ids of gates with status "pending" attached to `edge_ids`,
in deterministic order — `edge_ids` order first (incoming-edge insertion
order), then gate insertion order within each edge. Reads the prebuilt
`pending_gate_ids_by_edge` map from the adjacency index instead of
rescanning `graph$gates` per edge.

## Usage

``` r
dagri_pending_gates_for_edges(index, edge_ids)
```

## Arguments

- index:

  Adjacency index from
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md).

- edge_ids:

  Character vector of edge ids in insertion order.

## Value

Unnamed character vector of gate ids; `character(0)` when none are
pending.
