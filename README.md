
<!-- README.md is generated from README.Rmd. Re-knit after editing:
     Rscript -e 'rmarkdown::render("README.Rmd")' -->

# dagriculture

<!-- badges: start -->

[![R-CMD-check](https://github.com/sims1253/dagriculture/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/sims1253/dagriculture/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/sims1253/dagriculture/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/sims1253/dagriculture/actions/workflows/pkgdown.yaml)
[![Codecov test
coverage](https://codecov.io/gh/sims1253/dagriculture/graph/badge.svg)](https://app.codecov.io/gh/sims1253/dagriculture)
<!-- badges: end -->

dagriculture is an R package for task graphs: directed acyclic graphs
whose nodes are steps of a workflow and whose edges are dependencies
between them. It stores the graph, rejects edits that would make it
invalid, and tells you which nodes are ready to run and which are
blocked. It does not run anything.

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

`dagri_plan()` computes state itself, so you can call it on a graph that
was never passed through `dagri_recompute_state()`. External holds are
reasons a caller gives for keeping a node back, for example a policy
check. They change the plan but not the graph:

``` r
plan <- dagri_plan(
  graph,
  external_holds = list(cleaned_data = "manual_review")
)

plan$topo_order
#> [1] "raw_data"     "cleaned_data"

plan$external_blocked
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

The state is structural only. `dagri_recompute_state()` marks a node
`blocked` when a node upstream is blocked or a pending gate sits on an
incoming edge, and `ready` otherwise. States such as “done” or “failed”
belong to the runtime you build on top.

## Other functions

- Neighbors and reachability: `dagri_upstream()`, `dagri_downstream()`,
  `dagri_ancestors()`, `dagri_descendants()`, `dagri_has_path()`.
- Boundary nodes and order: `dagri_roots()`, `dagri_leaves()`,
  `dagri_terminal()`, `dagri_topo_order()`.
- Comparison: `dagri_graph_diff()` lists added, removed and changed
  nodes, edges and gates, and with `include_values = TRUE` the old and
  new values.
- Tables: `dagri_nodes_df()`, `dagri_edges_df()` and `dagri_gates_df()`
  return data frames.
- Diagrams: `dagri_mermaid()` returns Mermaid flowchart text.

## Limits

dagriculture does not execute, cache or schedule nodes. Write a runtime
for that, or use one such as bayesgrove.

It handles typed task graphs, not general network analysis. Use igraph
for that.

It does not read or write files. A graph that holds only plain data can
be written as JSON; `vignette("serialization-boundary")` gives a writer
and reader that round-trip a graph.

The package checks `metadata` and `param_schema` for closures and other
code-bearing values when you create them, but it does not check node
`params`, and it does not re-check a graph that was loaded from an RDS
file or edited by hand. Load graphs only from sources you trust, or
check them as the serialization vignette shows.

## Design documents

The `design/` directory describes the API and its guarantees:
[`api-contracts.md`](design/api-contracts.md),
[`boundary-contract.md`](design/boundary-contract.md) and
[`persistence-spec.md`](design/persistence-spec.md).
