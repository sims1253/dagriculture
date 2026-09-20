# Update a gate in a dagriculture graph

Update a gate in a dagriculture graph

## Usage

``` r
dagri_update_gate(graph, gate_id, metadata = NULL)
```

## Arguments

- graph:

  A `dagri_graph`.

- gate_id:

  Gate ID.

- metadata:

  Gate metadata. When non-`NULL`, **replaces** the existing `metadata`
  outright (see Details); must be a named list of plain data (closures,
  environments, formulas, language objects, S4 objects, external
  pointers, and weak references are rejected recursively).

## Value

A new `dagri_graph` with the gate updated and `version` bumped by 1 (the
bump happens even when `metadata` is `NULL`); the input graph is not
modified.

## Details

`metadata` (when non-`NULL`) **replaces** the gate's `metadata`
outright; it is NOT merged into the existing metadata. To merge partial
updates, do it in the caller, e.g.
`dagri_update_gate(graph, gate_id, metadata = utils::modifyList(old_metadata, new_metadata))`.
A `NULL` `metadata` leaves the field untouched. This mirrors
[`dagri_update_node()`](https://sims1253.github.io/dagriculture/reference/dagri_update_node.md)'s
replace-not-merge primitive. Gate `status` is not updatable here: use
[`dagri_resolve_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_resolve_gate.md)
/
[`dagri_reopen_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_reopen_gate.md),
which own the status lifecycle.

Known boundary:
[`dagri_graph_diff()`](https://sims1253.github.io/dagriculture/reference/dagri_graph_diff.md)
is a structural id diff — it reports only added/removed node and edge
ids, so metadata edits made here do not surface in its output.

## Errors

- `dagri_error_invalid_argument` when `graph` is malformed, `gate_id` is
  not a single non-empty string, or `metadata` is not a named list of
  plain data.

- `dagri_error_not_found` when `gate_id` is not a gate in the graph.

## Examples

``` r
reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
g <- dagri_graph(reg) |>
  dagri_add_node("raw", "source") |>
  dagri_add_node("fit", "process") |>
  dagri_add_edge("raw", "fit", id = "e1") |>
  dagri_add_gate("e1", id = "g1", metadata = list(approver = "reviewer_a"))

g2 <- dagri_update_gate(g, "g1", metadata = list(approver = "reviewer_b"))
g2$gates[["g1"]]$metadata
#> $approver
#> [1] "reviewer_b"
#> 
```
