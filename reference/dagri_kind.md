# Define a dagriculture kind

Creates a kind record describing one node type: its input contract,
output type, and parameter schema. The record is plain data and carries
an opaque caller-owned `metadata` field.

## Usage

``` r
dagri_kind(
  name,
  input_contract = NULL,
  output_type = NULL,
  param_schema = NULL,
  metadata = list()
)
```

## Arguments

- name:

  The name of the kind.

- input_contract:

  Input contract list.

- output_type:

  Output type string.

- param_schema:

  A named list describing expected parameters. Arbitrary nested list
  structure is allowed, but executable closures are rejected for safety.

- metadata:

  Opaque caller-owned extension data: a named list of plain data (nested
  lists, vectors, and scalars are fine). Closures, environments,
  formulas, language objects, S4 objects, external pointers, and weak
  references are rejected recursively.

## Value

A kind record: a named list with fields `name`, `input_contract`,
`output_type`, `param_schema`, and `metadata`.

## Errors

- `dagri_error_invalid_argument` when `name` is not a single non-empty
  string, `input_contract` is not a named list of single strings/`NULL`,
  `param_schema` is not a named list free of closures, or `metadata`
  fails the plain-data check (see
  [`dagri_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_graph.md)).

## Examples

``` r
dagri_kind("source", output_type = "data.frame")
#> $name
#> [1] "source"
#> 
#> $input_contract
#> NULL
#> 
#> $output_type
#> [1] "data.frame"
#> 
#> $param_schema
#> NULL
#> 
#> $metadata
#> list()
#> 
dagri_kind(
  "fit",
  input_contract = list(data = "data.frame"),
  metadata = list(owner = "team_a", revision = 2)
)
#> $name
#> [1] "fit"
#> 
#> $input_contract
#> $input_contract$data
#> [1] "data.frame"
#> 
#> 
#> $output_type
#> NULL
#> 
#> $param_schema
#> NULL
#> 
#> $metadata
#> $metadata$owner
#> [1] "team_a"
#> 
#> $metadata$revision
#> [1] 2
#> 
#> 
```
