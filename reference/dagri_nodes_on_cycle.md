# Nodes that lie on a cycle

Internal helper for the cycle error in
[`dagri_topo_order_impl()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order_impl.md).
The nodes Kahn's algorithm cannot emit include every in-scope cycle and
also the nodes downstream of one, which are on no cycle. A node is on a
cycle exactly when it can reach itself; every in-scope cycle lies inside
`stuck`, so the search stays inside `stuck`. Runs only when a cycle has
already been found.

## Usage

``` r
dagri_nodes_on_cycle(stuck, index)
```

## Arguments

- stuck:

  Character vector of node ids Kahn's algorithm did not emit.

- index:

  Adjacency index from
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md).

## Value

The ids in `stuck` that can reach themselves, in `stuck` order.
