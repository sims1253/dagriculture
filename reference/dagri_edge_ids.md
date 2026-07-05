# Sorted unique edge ids

Extracts edge ids from a list of edge objects. Prefers container
`names(edges)` when every name is non-empty; otherwise falls back to the
embedded `edge$id` field. This dual path keeps the helper usable both
for the canonical named-map storage shape and for unnamed edge lists
carrying embedded ids (for example after
[`unname()`](https://rdrr.io/r/base/unname.html)).

## Usage

``` r
dagri_edge_ids(edges)
```

## Arguments

- edges:

  A named or unnamed list of edge objects.

## Value

Sorted, de-duplicated character vector of edge ids (possibly empty).

## Details

Aborts with `dagri_error_invalid_argument` when neither path yields
complete non-empty ids, since unidentifiable edges cannot be diffed.

## Examples

``` r
edges <- list(
  e2 = list(id = "e2", from = "a", to = "b"),
  e1 = list(id = "e1", from = "c", to = "d")
)
dagri_edge_ids(edges)
#> [1] "e1" "e2"
```
