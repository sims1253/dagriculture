# Build the internal adjacency index for a graph

Performs a single O(V+E) pass over `graph$edges` and returns four named
lists keyed by every node id in `names(graph$nodes)` (each initialized
to `character(0)` so no NULL-guarding is needed):

## Usage

``` r
dagri_adjacency(graph)
```

## Arguments

- graph:

  A `dagri_graph`.

## Value

A named list with components `forward`, `reverse`, `forward_edges`, and
`reverse_edges`, each a named list keyed by node id.

## Details

- `forward`: node -\> unique vector of downstream neighbor ids
  (`edge$from -> edge$to`)

- `reverse`: node -\> unique vector of upstream neighbor ids
  (`edge$to -> edge$from`)

- `forward_edges`: node -\> vector of outgoing edge ids (not uniqued;
  each edge is distinct)

- `reverse_edges`: node -\> vector of incoming edge ids (not uniqued)

The index is derived per call and is never stored on the graph, so the
pure-value, immutable public API is unchanged. Internals that previously
re-scanned the full edge list per neighbor lookup instead index into
these pre-built maps.
