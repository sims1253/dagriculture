# Validate caller-owned metadata

Metadata is opaque caller-owned extension data carried on every record
type (kind, registry, graph, node, edge, gate). To stay compatible with
the persistence contract it must be named plain data: a named list
(possibly empty) whose values contain no executable or reference-bearing
objects. Nested lists (objects and arrays) are allowed at any depth;
closures, environments, formulas, language objects, S4 objects, external
pointers, and weak references are rejected recursively.

## Usage

``` r
dagri_validate_metadata(x, arg = "metadata")
```

## Arguments

- x:

  The metadata value to validate.

- arg:

  Argument name used in error messages.

## Value

`x`, invisibly, if valid.
