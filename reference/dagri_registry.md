# Define a dagriculture registry

Bundles one or more
[`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md)
records into a registry keyed by kind name. The registry carries an
opaque caller-owned `metadata` field.

## Usage

``` r
dagri_registry(..., metadata = list())
```

## Arguments

- ...:

  `dagri_kind` objects.

- metadata:

  Opaque caller-owned extension data: a named list of plain data (nested
  lists, vectors, and scalars are fine). Closures, environments,
  formulas, language objects, S4 objects, external pointers, and weak
  references are rejected recursively.

## Value

A registry: a named list with fields `kinds` (a named map of kind
records) and `metadata`.

## Errors

- `dagri_error_invalid_argument` when `metadata` is not a named list of
  plain data.

## Examples

``` r
reg <- dagri_registry(
  dagri_kind("source"),
  dagri_kind("process"),
  metadata = list(origin = "hand-authored")
)
names(reg$kinds)
#> [1] "source"  "process"
reg$metadata
#> $origin
#> [1] "hand-authored"
#> 
```
