
<!-- README.md is generated from README.Rmd. Re-knit after editing:
     Rscript -e 'rmarkdown::render("README.Rmd")' -->

# dagriculture

<!-- badges: start -->

[![R-CMD-check](https://github.com/sims1253/dagriculture/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/sims1253/dagriculture/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/sims1253/dagriculture/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/sims1253/dagriculture/actions/workflows/pkgdown.yaml)
[![Codecov test
coverage](https://codecov.io/gh/sims1253/dagriculture/branch/main/graph/badge.svg)](https://app.codecov.io/gh/sims1253/dagriculture)
<!-- badges: end -->

**dagriculture** is a pure, value-oriented directed-acyclic-graph
library for R. It manages graph structure, topological dependencies,
structural validity, and task planning — and deliberately nothing else.
Every operation takes a graph value and returns a new graph value:

  - **No mutation.** Graphs are plain R lists; editing verbs return
    modified copies, so snapshots, diffs, and rollbacks are just
    variable assignments.
  - **No execution.** dagriculture tells you *what could run*
    (`dagri_plan()`), never runs anything itself, and holds no opinions
    about what a node does.
  - **No IO and no code.** Graphs contain only data. Node kinds can
    declare parameter schemas, but executable closures are rejected by
    construction — a graph loaded from disk can never smuggle code into
    your session.
  - **Validity by construction.** Duplicate ids, unknown kinds, dangling
    edges, and cycle-creating edges are rejected at edit time with a
    typed error taxonomy (`dagri_error_*`).

This makes it a safe structural core for runtime layers built on top.
Its primary consumer is
[bayesgrove](https://github.com/sims1253/bayesgrove), which layers
caching, execution, and Bayesian-workflow semantics over these
primitives.

## Installation

``` r
# install.packages("pak")
pak::pak("sims1253/dagriculture")
```

## Core concepts

| Concept             | What it is                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| **Registry / kind** | The vocabulary of allowed node types, with optional input contracts and parameter schemas        |
| **Node**            | A typed vertex with params, metadata, and a structural state (`new`, `ready`, `blocked`)         |
| **Edge**            | A typed, id-carrying dependency between nodes; cycle-creating edges are rejected                 |
| **Gate**            | A pending/resolved blocker attached to an edge — downstream nodes stay blocked until it resolves |
| **Plan**            | A pure description of targets, topological order, eligible/blocked nodes, and pending gates      |

Structural state is intentionally minimal: `dagri_recompute_state()`
knows whether a node is *structurally* ready or blocked (upstream not
ready, or a pending gate in the way). Execution states like “done” or
“failed” belong to whatever runtime you build on top.

## Example

``` r
library(dagriculture)

# 1. Define the kinds of nodes allowed in your graph
registry <- dagri_registry(
  dagri_kind("data_source"),
  dagri_kind("transform")
)

# 2. Build a graph; every verb returns a new value
graph <- dagri_graph(registry) |>
  dagri_add_node("raw_data", "data_source") |>
  dagri_add_node("cleaned_data", "transform") |>
  dagri_add_edge(from = "raw_data", to = "cleaned_data", id = "edge_1")

# 3. Gate the edge: downstream work is blocked until the gate resolves
graph <- dagri_add_gate(graph, edge_id = "edge_1", id = "review_gate")

# 4. Compute structural state
graph <- dagri_recompute_state(graph)

dagri_eligible(graph)
#> [1] "raw_data"

dagri_blocked(graph)
#> $cleaned_data
#> [1] "gate"
```

Planning is a pure query that derives state internally — you don’t need
to recompute first — and external holds (reasons imposed by a caller,
such as a policy layer) affect the plan without ever touching graph
state:

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

Because graphs are values, “what changed?” never requires an event log —
keep the old value and compare:

``` r
before <- graph
after <- dagri_add_node(graph, "report", "transform")

setdiff(names(after$nodes), names(before$nodes))
#> [1] "report"
```

## Queries

Beyond editing and planning, the package provides pure structural
queries: `dagri_upstream()` / `dagri_downstream()` for direct neighbors,
`dagri_ancestors()` / `dagri_descendants()` for reachability,
`dagri_roots()` / `dagri_leaves()` / `dagri_terminal()` for boundary
nodes, `dagri_topo_order()` for ordering, and `dagri_has_path()` for
connectivity.

## What dagriculture is not

  - Not a workflow runner — nothing here executes, caches, or schedules.
    Pair it with a runtime layer (see bayesgrove) or write your own.
  - Not a general graph-theory package — it targets typed task DAGs, not
    arbitrary network analysis; use igraph for that.
  - Not a persistence layer — graphs serialize cleanly to JSON because
    they are plain data, but reading and writing them is the caller’s
    job. The contracts are documented in [`design/`](design/).

## Design documents

The `design/` directory is authoritative for the API surface and
boundary guarantees: [`api-contracts.md`](design/api-contracts.md),
[`boundary-contract.md`](design/boundary-contract.md), and
[`persistence-spec.md`](design/persistence-spec.md).
