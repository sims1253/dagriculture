# Diff shared records field by field

Internal worker for
[`dagri_graph_diff()`](https://sims1253.github.io/dagriculture/reference/dagri_graph_diff.md):
walks `common_ids` (ids present in both graphs, already ordered by the
caller) and compares the tracked `fields` per record with
[`identical()`](https://rdrr.io/r/base/identical.html) on the stored
values, so `NULL` vs `NULL` compares equal.

## Usage

``` r
dagri_diff_records(before_map, after_map, common_ids, fields, include_values)
```

## Arguments

- before_map:

  Named list of before-state records keyed by id.

- after_map:

  Named list of after-state records keyed by id.

- common_ids:

  Character vector of ids present in both maps.

- fields:

  Character vector of field names to compare.

- include_values:

  Whether to collect before/after values per change.

## Value

A list with `changed_ids` (character vector in `common_ids` order) and
`values` (named list keyed by changed ids; each entry a named list of
only the differing fields, each
`list(before = <value>, after = <value>)`; an empty named list when
`include_values` is `FALSE`).
