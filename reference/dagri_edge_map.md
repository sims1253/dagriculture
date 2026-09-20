# Key an edge collection by id, preserving storage order

Internal building block for the graph diff: returns the edge objects as
a named list keyed by edge id in storage (insertion) order. Follows the
same dual path as
[`dagri_edge_ids()`](https://sims1253.github.io/dagriculture/reference/dagri_edge_ids.md)
— container `names(edges)` when every name is non-empty, otherwise the
embedded `edge$id` fields — so both the canonical named-map storage
shape and unnamed edge lists with embedded ids are supported.

## Usage

``` r
dagri_edge_map(edges)
```

## Arguments

- edges:

  A named or unnamed list of edge objects.

## Value

A named list of edge objects keyed by edge id (possibly empty).

## Details

Aborts with `dagri_error_invalid_argument` when neither path yields
complete non-empty ids, since unidentifiable edges cannot be diffed.
