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

  Node metadata.
