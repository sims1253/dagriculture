# Add a node to a dagriculture graph

Nodes are created with state "new". Call
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md)
to compute structural readiness (state becomes "ready" or "blocked").

## Usage

``` r
dagri_add_node(
  graph,
  id,
  kind,
  label = NULL,
  params = list(),
  metadata = list()
)
```

## Arguments

- graph:

  A `dagri_graph`.

- id:

  Node ID.

- kind:

  Node kind.

- label:

  Node label.

- params:

  Node parameters.

- metadata:

  Opaque caller-owned extension data: a named list of plain data (nested
  lists, vectors, and scalars are fine). Closures, environments,
  formulas, language objects, S4 objects, external pointers, and weak
  references are rejected recursively.

## Value

A new `dagri_graph` with the node added and `version` bumped by 1; the
input graph is not modified.

## Errors

- `dagri_error_invalid_argument` when `graph` is malformed, `id`/`kind`
  is not a single non-empty string, params miss required
  `input_contract` fields, or `metadata` is not a named list of plain
  data.

- `dagri_error_unknown_kind` when `kind` is not in the registry.

- `dagri_error_duplicate_id` when `id` already exists.

## Examples

``` r
reg <- dagri_registry(dagri_kind("source"))
g <- dagri_add_node(
  dagri_graph(reg),
  id = "raw",
  kind = "source",
  metadata = list(uri = "source:observations_v1")
)
g$nodes[["raw"]]$metadata
#> $uri
#> [1] "source:observations_v1"
#> 
```
