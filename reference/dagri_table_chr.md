# Scalar character column from record fields

Internal helper for the tabular accessors. Extracts `field` from every
record in `records`; a missing or `NULL` field becomes `NA_character_`.
An empty record list yields `character(0)`, so the empty-graph skeleton
keeps the exact column type of the populated case.

## Usage

``` r
dagri_table_chr(records, field)
```

## Arguments

- records:

  Named list of records (nodes, edges, or gates).

- field:

  Name of the scalar field to extract.

## Value

Unnamed character vector with one entry per record, in record
(insertion) order.
