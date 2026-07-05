# Print a dagriculture graph

Prints a concise multi-line summary of a `dagri_graph`: package name and
version, node/edge/gate counts, the graph's internal `$version`, and the
registry kind names. Matches the style of base R print methods (writes
to stdout via [`cat()`](https://rdrr.io/r/base/cat.html) with trailing
newlines).

## Usage

``` r
# S3 method for class 'dagri_graph'
print(x, ...)
```

## Arguments

- x:

  A `dagri_graph`.

- ...:

  Unused; for S3 generic compatibility.

## Value

The input `x`, invisibly.
