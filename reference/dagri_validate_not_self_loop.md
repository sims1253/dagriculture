# Refuse an edge from a node to itself

A self-loop is a cycle on its own. In an acyclic graph no node reaches
itself, so the path search in
[`dagri_add_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_add_edge.md)
finds nothing for an edge from a node to itself.
[`dagri_add_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_add_edge.md)
calls this before it stores an edge, and
[`dagri_validate_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_graph.md)
calls it for every stored edge, which covers graphs that were loaded or
assembled without the editing API.

## Usage

``` r
dagri_validate_not_self_loop(edge)
```

## Arguments

- edge:

  An edge record with `from`, `to`, and `id`.

## Value

`edge`, invisibly, if it joins two different nodes.
