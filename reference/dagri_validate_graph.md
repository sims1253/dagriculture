# Validate a dagriculture graph object

Ensures the graph has all required top-level fields, validates component
types for `registry`, `nodes`, `edges`, and `gates`, and checks that
`version` is a single integer.

## Usage

``` r
dagri_validate_graph(graph)
```

## Arguments

- graph:

  A `dagri_graph`.

## Value

The graph, invisibly, if valid.
