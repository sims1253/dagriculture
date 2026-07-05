# Get topological order

Get topological order

## Usage

``` r
dagri_topo_order(graph, subset = NULL)
```

## Arguments

- graph:

  A `dagri_graph`.

- subset:

  Optional subset of nodes.

## Details

O(V+E).

Cycles are detected here: after the Kahn loop, any node that was not
emitted (i.e. still has non-zero in-degree) participates in a cycle, and
the function aborts with class `dagri_error_cycle`, naming the
cycle-participating nodes in `details$cycle_nodes`.
[`dagri_add_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_add_edge.md)
prevents cycles at edit time, but consumers (e.g. bayesgrove)
deserialize graphs from JSON, so a corrupted or hand-edited file can
smuggle a cycle past the editing layer; this check ensures a planner
never silently drops cycle-locked nodes from the order.
