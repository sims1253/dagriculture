# Update a node in a dagriculture graph

Update a node in a dagriculture graph

## Usage

``` r
dagri_update_node(graph, id, label = NULL, params = NULL, metadata = NULL)
```

## Arguments

- graph:

  A `dagri_graph`.

- id:

  Node ID.

- label:

  Node label. `NULL` leaves the field unchanged.

- params:

  Node parameters. When non-`NULL`, **replaces** the existing `params`
  outright (see Details).

- metadata:

  Node metadata. When non-`NULL`, **replaces** the existing `metadata`
  outright (see Details); must be a named list of plain data (closures,
  environments, formulas, language objects, S4 objects, external
  pointers, and weak references are rejected recursively).

## Value

A new `dagri_graph` with the node updated and `version` bumped by 1 (the
bump happens even when every field argument is `NULL`); the input graph
is not modified.

## Details

`params` (when non-`NULL`) **replaces** the node's `params` outright; it
is NOT merged into the existing params. Likewise `metadata` (when
non-`NULL`) **replaces** the node's `metadata` outright. To merge
partial updates, do it in the caller, e.g.
`dagri_update_node(graph, id, params = utils::modifyList(old_params, new_params))`.
A `NULL` `params`/`metadata`/`label` leaves that field untouched.
Keeping this a primitive (replace, not merge) means consumers (e.g.
bayesgrove's `bg_update_node()`) must opt into merge explicitly, instead
of silently having their partial update destroy sibling fields.

## Errors

- `dagri_error_invalid_argument` when `graph` is malformed, `id` is not
  a single non-empty string, or `metadata` is not a named list of plain
  data.

- `dagri_error_not_found` when `id` is not a node in the graph.

## Examples

``` r
reg <- dagri_registry(dagri_kind("source"))
g <- dagri_add_node(dagri_graph(reg), "raw", "source")
g2 <- dagri_update_node(g, "raw", metadata = list(reviewed = TRUE))
g2$nodes[["raw"]]$metadata
#> $reviewed
#> [1] TRUE
#> 
```
