# Diff two graphs: structure and tracked field values

Returns a pure diff with no workflow semantics: which node, edge, and
gate ids were added or removed going from `before` to `after`, which ids
present in both graphs had tracked fields change, and (with
`include_values = TRUE`) the before/after values of every changed field.
Nodes are keyed by `names(graph$nodes)`; edges by
[`dagri_edge_ids()`](https://sims1253.github.io/dagriculture/reference/dagri_edge_ids.md)
so both named-map storage and unnamed edge lists with embedded ids are
supported; gates by `names(graph$gates)`.

## Usage

``` r
dagri_graph_diff(before, after, include_values = FALSE)
```

## Arguments

- before:

  A `dagri_graph` (the prior state).

- after:

  A `dagri_graph` (the new state).

- include_values:

  Single `TRUE` or `FALSE`, default `FALSE`. When `TRUE`, the result
  additionally carries a `values` element with the before/after values
  of every changed field.

## Value

A named list, in this order:

- `added_nodes`, `removed_nodes`, `added_edges`, `removed_edges`,
  `added_gates`, `removed_gates`: character vectors of ids present in
  only one of the two graphs. The first four keep the exact semantics of
  the original structural-only diff: plain
  [`setdiff()`](https://rdrr.io/r/base/sets.html) over node names and
  [`dagri_edge_ids()`](https://sims1253.github.io/dagriculture/reference/dagri_edge_ids.md).

- `changed_nodes`, `changed_edges`, `changed_gates`: character vectors
  of ids present in both graphs (by key) where at least one tracked
  field differs. Deterministic: ids appear in the named-map insertion
  order of `after`.

- `values`: only present when `include_values = TRUE`. A named list with
  elements `nodes`, `edges`, and `gates`; each is a named list keyed by
  the changed ids (same ids and order as the matching `changed_*`
  vector), and each entry is a named list of only the differing fields,
  each field `list(before = <value>, after = <value>)`. Ids that were
  only added or removed do not appear in `values`.

## Details

Tracked fields, compared per field with
[`identical()`](https://rdrr.io/r/base/identical.html) on the stored
in-memory values (`NULL` vs `NULL` compares equal):

- nodes: `kind`, `label`, `params`, `state`, `block_reason`, `metadata`

- edges: `from`, `to`, `type`, `metadata`

- gates: `edge_id`, `status`, `metadata`

`graph$version` is ignored: it is derived bookkeeping, not content.

Because comparison is
[`identical()`](https://rdrr.io/r/base/identical.html)-based on
in-memory values, two graphs that serialize identically can still diff
when their in-memory shapes differ (for example `NULL` vs `""`, or list
attribute differences). Callers diffing JSON-round-tripped graphs should
normalize values before diffing; the serialization rules live in
`design/persistence-spec.md`.

## Examples

``` r
reg <- dagri_registry(dagri_kind("source"), dagri_kind("fit"))
before <- dagri_graph(reg) |>
  dagri_add_node("data", "source") |>
  dagri_add_node("fit", "fit", label = "Fit") |>
  dagri_add_edge("data", "fit", id = "e1")
after <- dagri_add_node(before, "diag", "fit")
diff <- dagri_graph_diff(before, after)
diff$added_nodes
#> [1] "diag"

# A relabel is invisible to the structural vectors but shows up as a
# change; include_values = TRUE carries the before/after values along.
relabeled <- dagri_update_node(after, "fit", label = "Posterior fit")
value_diff <- dagri_graph_diff(after, relabeled, include_values = TRUE)
value_diff$changed_nodes
#> [1] "fit"
value_diff$values$nodes$fit$label$before
#> [1] "Fit"
value_diff$values$nodes$fit$label$after
#> [1] "Posterior fit"
```
