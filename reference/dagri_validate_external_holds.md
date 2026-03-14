# Validate external holds

Checks that external holds is a valid named list mapping node IDs to
single-character reason strings.

## Usage

``` r
dagri_validate_external_holds(graph, external_holds)
```

## Arguments

- graph:

  A `dagri_graph`.

- external_holds:

  Named list mapping node IDs to reason strings.

## Value

Validated external holds list.
