# dagriculture

dagriculture is an R package for task graphs: directed acyclic graphs
whose nodes are steps of a workflow and whose edges are dependencies
between them. It stores the graph, rejects edits that would make it
invalid, and tells you which nodes nothing in the graph blocks (it calls
them eligible) and which are blocked. It does not run anything.

It is meant for people who write a workflow tool or pipeline runner in R
and want the graph model kept apart from execution.
[bayesgrove](https://github.com/sims1253/bayesgrove) uses it this way:
it adds caching, execution and Bayesian-workflow semantics on top.

A graph is a list with a class attribute. Functions that edit a graph
return a new graph and leave their input unchanged, so keeping an old
version means keeping a variable. The editing functions reject duplicate
ids, unknown node kinds, edges to missing nodes and edges that would
create a cycle, each with a typed error (`dagri_error_*`).

## Installation

``` r

# install.packages("pak")
pak::pak("sims1253/dagriculture")
```

## Example

``` r

library(dagriculture)

# The registry lists the kinds of node a graph may hold.
registry <- dagri_registry(
  dagri_kind("data_source"),
  dagri_kind("transform")
)

graph <- dagri_graph(registry) |>
  dagri_add_node("raw_data", "data_source") |>
  dagri_add_node("cleaned_data", "transform") |>
  dagri_add_edge(from = "raw_data", to = "cleaned_data", id = "edge_1")

# A pending gate on the edge blocks everything downstream of it.
graph <- dagri_add_gate(graph, edge_id = "edge_1", id = "review_gate")

graph <- dagri_recompute_state(graph)

dagri_eligible(graph)
#> [1] "raw_data"

dagri_blocked(graph)
#> $cleaned_data
#> [1] "gate"
```

[`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md)
computes state itself, so you can call it on a graph that was never
passed through
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md).
External holds are reasons a caller gives for keeping a node back, for
example a policy check. They change the plan but not the graph, and they
do not change which nodes the graph itself blocks. Here `raw_data` is
held: it stays in `plan$eligible`, because nothing in the graph blocks
it, and also appears in `plan$external_blocked`, as does `cleaned_data`
downstream of it:

``` r

plan <- dagri_plan(
  graph,
  external_holds = list(raw_data = "manual_review")
)

plan$topo_order
#> [1] "raw_data"     "cleaned_data"

plan$eligible
#> [1] "raw_data"

plan$external_blocked
#> $raw_data
#> [1] "manual_review"
#> 
#> $cleaned_data
#> [1] "manual_review"

plan$pending_gates
#> [1] "review_gate"
```

Resolving the gate unblocks the downstream node:

``` r

graph <- dagri_resolve_gate(graph, "review_gate") |>
  dagri_recompute_state()

dagri_eligible(graph)
#> [1] "raw_data"     "cleaned_data"
```

To see what changed between two versions, keep both and compare them:

``` r

before <- graph
after <- dagri_add_node(graph, "report", "transform")

dagri_graph_diff(before, after)$added_nodes
#> [1] "report"
```

## Concepts

| Concept | What it is |
|----|----|
| Registry and kind | The node types a graph allows, each with an optional input contract and parameter schema |
| Node | A vertex of one kind, with params, metadata and a structural state (`new`, `ready` or `blocked`) |
| Edge | A dependency between two nodes, with its own id and type |
| Gate | A blocker on an edge, `pending` or `resolved`; nodes downstream of a pending gate are blocked |
| Plan | The targets, their topological order, the eligible and blocked nodes, and the pending gates |

The state is structural only.
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md)
marks a node `blocked` when a node upstream is blocked or a pending gate
sits on an incoming edge, and `ready` otherwise. States such as “done”
or “failed” belong to the runtime you build on top.

## Other functions

- Neighbors and reachability:
  [`dagri_upstream()`](https://sims1253.github.io/dagriculture/reference/dagri_upstream.md),
  [`dagri_downstream()`](https://sims1253.github.io/dagriculture/reference/dagri_downstream.md),
  [`dagri_ancestors()`](https://sims1253.github.io/dagriculture/reference/dagri_ancestors.md),
  [`dagri_descendants()`](https://sims1253.github.io/dagriculture/reference/dagri_descendants.md),
  [`dagri_has_path()`](https://sims1253.github.io/dagriculture/reference/dagri_has_path.md).
- Boundary nodes and order:
  [`dagri_roots()`](https://sims1253.github.io/dagriculture/reference/dagri_roots.md),
  [`dagri_leaves()`](https://sims1253.github.io/dagriculture/reference/dagri_leaves.md),
  [`dagri_terminal()`](https://sims1253.github.io/dagriculture/reference/dagri_terminal.md),
  [`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md).
- Comparison:
  [`dagri_graph_diff()`](https://sims1253.github.io/dagriculture/reference/dagri_graph_diff.md)
  lists added, removed and changed nodes, edges and gates, and with
  `include_values = TRUE` the old and new values.
- Tables:
  [`dagri_nodes_df()`](https://sims1253.github.io/dagriculture/reference/dagri_nodes_df.md),
  [`dagri_edges_df()`](https://sims1253.github.io/dagriculture/reference/dagri_edges_df.md)
  and
  [`dagri_gates_df()`](https://sims1253.github.io/dagriculture/reference/dagri_gates_df.md)
  return data frames.
- Diagrams:
  [`dagri_mermaid()`](https://sims1253.github.io/dagriculture/reference/dagri_mermaid.md)
  returns Mermaid flowchart text.

## Limits

dagriculture does not execute, cache or schedule nodes. Write a runtime
for that, or use one such as bayesgrove.

It handles typed task graphs, not general network analysis. Use igraph
for that.

It does not read or write files. A graph that holds only plain data can
be written as JSON; the [serialization
article](https://sims1253.github.io/dagriculture/articles/serialization-boundary.html)
gives a writer and reader that round-trip a graph.

Every function that takes `metadata` rejects closures, environments,
formulas and other code-bearing values among its elements, at any depth.
[`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md)
requires a `param_schema`, if given, to be a named list with no
functions among its elements, but accepts formulas and environments in
it. Neither check looks at attributes, so a value can still carry code
there. Node `params` are not checked, except that
[`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md)
requires the names in the kind’s input contract. A graph loaded from an
RDS file or edited by hand is checked only for its structure, its
references and self-loops. Longer cycles are found by
[`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md),
[`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md)
and
[`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md).
Nothing checks it again for code-bearing values, so load graphs only
from sources you trust, or check them as the [serialization
article](https://sims1253.github.io/dagriculture/articles/serialization-boundary.html)
shows.

## Design documents

The `design/` directory describes the API and its guarantees:
[`api-contracts.md`](https://sims1253.github.io/dagriculture/design/api-contracts.md),
[`boundary-contract.md`](https://sims1253.github.io/dagriculture/design/boundary-contract.md)
and
[`persistence-spec.md`](https://sims1253.github.io/dagriculture/design/persistence-spec.md).
