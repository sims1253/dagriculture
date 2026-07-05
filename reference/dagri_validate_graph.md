# Validate a dagriculture graph object

Ensures the graph has all required top-level fields, validates component
types for `registry`, `nodes`, `edges`, and `gates`, checks that
`version` is a single integer, and enforces referential integrity: every
edge's `$from`/`$to` must reference a node in `graph$nodes`, and every
gate's `$edge_id` must reference an edge in `graph$edges`.

## Usage

``` r
dagri_validate_graph(graph)
```

## Arguments

- graph:

  A `dagri_graph`.

## Value

The graph, invisibly, if valid.

## Details

This is the load-time / entry-point validator: it guards every public
boundary, so it is kept cheap and structural (O(V+E) referential
checks). It does NOT detect cycles, because cycle detection is O(V+E)
and only needed for topological operations;
[`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)
performs that check explicitly.
