# Assemble a tabular accessor's data.frame

Internal helper shared by
[`dagri_nodes_df()`](https://sims1253.github.io/dagriculture/reference/dagri_nodes_df.md),
[`dagri_edges_df()`](https://sims1253.github.io/dagriculture/reference/dagri_edges_df.md),
and
[`dagri_gates_df()`](https://sims1253.github.io/dagriculture/reference/dagri_gates_df.md).
The scalar character columns go through
[`data.frame()`](https://rdrr.io/r/base/data.frame.html); the
list-columns are attached afterwards because
[`data.frame()`](https://rdrr.io/r/base/data.frame.html) would spread a
list argument across several columns. Row names stay the plain automatic
sequence — record ids are data in the `id` column, never row names. When
every column is zero-length this returns the empty skeleton: a zero-row
frame with identical column names and per-column classes as the
populated case.

## Usage

``` r
dagri_table_frame(scalar_columns, list_columns)
```

## Arguments

- scalar_columns:

  Named list of equal-length character vectors.

- list_columns:

  Named list of list-columns (one cell per row).

## Value

A base `data.frame` with the scalar columns followed by the
list-columns.
