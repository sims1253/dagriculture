# Terminal nodes within an already-scoped target closure

Pure worker shared by
[`dagri_terminal()`](https://sims1253.github.io/dagriculture/reference/dagri_terminal.md)
and
[`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md):
a node is terminal when none of its downstream neighbors are inside
`scoped_targets`.

## Usage

``` r
dagri_terminal_impl(scoped_targets, index)
```

## Arguments

- scoped_targets:

  Character vector of node ids (a target closure).

- index:

  Adjacency index from
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md).

## Value

Character vector of terminal node ids.
