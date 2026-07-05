# Print a dagriculture structural plan

Prints a concise multi-line summary of a `dagri_plan` produced by
[`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md):
counts of targets, the topological order length, and the
eligible/blocked/terminal sets plus the number of pending gates. Matches
the style of base R print methods.

## Usage

``` r
# S3 method for class 'dagri_plan'
print(x, ...)
```

## Arguments

- x:

  A `dagri_plan`.

- ...:

  Unused; for S3 generic compatibility.

## Value

The input `x`, invisibly.
