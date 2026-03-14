# Validate node IDs against a graph

Checks that node IDs are valid character strings and exist in the graph.

## Usage

``` r
dagri_validate_node_ids(graph, node_ids, arg = "node_ids")
```

## Arguments

- graph:

  A `dagri_graph`.

- node_ids:

  Character vector of node IDs.

- arg:

  Argument name for error messages.

## Value

Unique, validated node IDs.
