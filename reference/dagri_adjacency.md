# Build the internal adjacency index for a graph

Performs a single O(V+E+G) pass over `graph$edges` and `graph$gates` and
returns five named lists (each initialized to `character(0)` entries so
no NULL-guarding is needed):

## Usage

``` r
dagri_adjacency(graph)
```

## Arguments

- graph:

  A `dagri_graph`.

## Value

A named list with components `forward`, `reverse`, `forward_edges`,
`reverse_edges` (each a named list keyed by node id), and
`pending_gate_ids_by_edge` (a named list keyed by edge id).

## Details

- `forward`: node -\> unique vector of downstream neighbor ids
  (`edge$from -> edge$to`), keyed by every node id

- `reverse`: node -\> unique vector of upstream neighbor ids
  (`edge$to -> edge$from`), keyed by every node id

- `forward_edges`: node -\> vector of outgoing edge ids (not uniqued;
  each edge is distinct), keyed by every node id

- `reverse_edges`: node -\> vector of incoming edge ids (not uniqued),
  keyed by every node id

- `pending_gate_ids_by_edge`: edge -\> vector of pending gate ids on
  that edge in gate insertion order, keyed by every edge id

The index is derived per call and is never stored on the graph, so the
pure-value, immutable public API is unchanged. Internals that previously
re-scanned the full edge or gate lists per lookup instead index into
these pre-built maps.
