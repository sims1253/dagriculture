# List-column from record fields

Internal helper for the tabular accessors. Extracts `field` from every
record in `records`, verbatim, as one cell per row. Graphs store these
fields as plain lists, so the cells are plain lists; no graph or record
objects leak into cells. An empty record list yields the empty
[`list()`](https://rdrr.io/r/base/list.html) column of the empty-graph
skeleton.

## Usage

``` r
dagri_table_list(records, field)
```

## Arguments

- records:

  Named list of records (nodes, edges, or gates).

- field:

  Name of the list field to extract.

## Value

Unnamed list with one cell per record, in record (insertion) order.
