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
  outright (see Details).

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
