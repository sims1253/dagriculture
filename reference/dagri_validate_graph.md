# Validate a dagriculture graph object

Ensures the graph has all required top-level fields, validates component
types for `registry`, `nodes`, `edges`, and `gates`, checks that
`version` is a single integer, and enforces referential integrity: every
edge's `$from`/`$to` must reference a node in `graph$nodes`, and every
gate's `$edge_id` must reference an edge in `graph$edges`. An edge whose
`$from` equals its `$to` (a self-loop) aborts with class
`dagri_error_cycle`.

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
boundary, so it is kept to structural checks of each record. It does NOT
detect cycles longer than a self-loop, because that needs a traversal of
the graph and is only needed for topological operations;
[`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)
performs that check explicitly.
