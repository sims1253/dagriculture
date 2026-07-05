# Order edges deterministically by edge id

Returns a copy of `edges` sorted by the embedded `edge$id` field
(falling back to `""` when an edge has no `id`). Empty or length-1 lists
are returned unchanged. Container names are preserved. Used by consumers
that need a stable fingerprint of multi-input nodes.

## Usage

``` r
dagri_order_edges(edges)
```

## Arguments

- edges:

  A named or unnamed list of edge objects.

## Value

The same list, reordered by edge id.

## Examples

``` r
edges <- list(
  late = list(id = "edge_z", from = "a", to = "b"),
  early = list(id = "edge_a", from = "c", to = "d"),
  middle = list(id = "edge_m", from = "e", to = "f")
)
ordered <- dagri_order_edges(edges)
vapply(ordered, function(e) e$id, character(1))
#>    early   middle     late 
#> "edge_a" "edge_m" "edge_z" 
```
