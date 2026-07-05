# Get all ancestors

Returns all node ids reachable from `node_id` by following edges
upstream.

## Usage

``` r
dagri_ancestors(graph, node_id)
```

## Arguments

- graph:

  A `dagri_graph`.

- node_id:

  Node ID.

## Details

O(V+E).
