# Define a dagriculture kind

Define a dagriculture kind

## Usage

``` r
dagri_kind(
  name,
  input_contract = NULL,
  output_type = NULL,
  param_schema = NULL
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
