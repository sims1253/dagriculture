# Add a gate to a dagriculture graph

Add a gate to a dagriculture graph

## Usage

``` r
dagri_add_gate(graph, edge_id, id = NULL, metadata = list())
```

## Arguments

- graph:

  A `dagri_graph`.

- edge_id:

  Edge ID.

- id:

  Optional Gate ID.

- metadata:

  Opaque caller-owned extension data: a named list of plain data (nested
  lists, vectors, and scalars are fine). Closures, environments,
  formulas, language objects, S4 objects, external pointers, and weak
  references are rejected recursively.

## Value

A new `dagri_graph` with the gate added (status "pending") and `version`
bumped by 1; the input graph is not modified.

## Errors

- `dagri_error_invalid_argument` when `graph` is malformed,
  `edge_id`/`id` is not a single non-empty string, or `metadata` is not
  a named list of plain data.

- `dagri_error_not_found` when `edge_id` is not an edge in the graph.

- `dagri_error_duplicate_id` when `id` already exists as a gate.

## Examples

``` r
reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
g <- dagri_graph(reg) |>
  dagri_add_node("raw", "source") |>
  dagri_add_node("fit", "process") |>
  dagri_add_edge("raw", "fit", id = "e1") |>
  dagri_add_gate("e1", metadata = list(approver = "reviewer_a"))
g$gates[["gate_e1"]]$metadata
#> $approver
#> [1] "reviewer_a"
#> 
```
