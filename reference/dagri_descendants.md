# Get all descendants

Returns all node ids reachable from `node_id` by following edges
downstream.

## Usage

``` r
dagri_descendants(graph, node_id)
```

## Arguments

- graph:

  A `dagri_graph`.

- node_id:

  Node ID.

## Details

O(V+E).
