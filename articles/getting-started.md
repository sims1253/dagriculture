# Getting Started with groots

`groots` is a pure, value-oriented graph library. It is designed to
manage graph structures, topological dependencies, structural validity,
and task planning. It does not natively orchestrate runtime execution or
manage side effects; rather, it tracks structural states (`new`,
`ready`, `blocked`) and enforces declarative dependency rules.

## Core Concepts

- **Registry:** Defines the allowable `kinds` of nodes in a graph.
- **Graph:** The main immutable data structure carrying nodes, edges,
  and gates. Operations return a new graph and bump the internal
  `$version`.
- **Nodes & Edges:** Represent units of computation (or data) and their
  dependencies.
- **Gates:** Explicit structural blockers attached to edges, which
  prevent downstream nodes from becoming `ready` until the gate is
  resolved.
- **Planning:** Topologically sorting and tracking the structural
  readiness of nodes.

## Installation

``` r
# install.packages("pak")
pak::pak("sims1253/groots")
```

## Basic Workflow

### 1. Define a Registry

First, establish a registry to strictly define what kind of nodes are
allowed in your graphs.

``` r
library(groots)

reg <- groots_registry(
  groots_kind("input", output_type = "data.frame"),
  groots_kind("model"),
  groots_kind("report")
)
```

### 2. Build the Graph

Start with an empty graph, and add nodes and edges. Because `groots`
uses value semantics, every mutating function returns a new updated
graph instance.

``` r
g <- groots_graph(reg)

g <- g |>
  groots_add_node(id = "data", kind = "input", label = "Raw Data") |>
  groots_add_node(id = "fit", kind = "model", label = "Statistical Fit") |>
  groots_add_node(id = "plot", kind = "report", label = "Final Plot") |>
  groots_add_edge(from = "data", to = "fit", id = "e_data_fit") |>
  groots_add_edge(from = "fit", to = "plot", id = "e_fit_plot")

# The internal version tracks changes
g$version
#> [1] 5
```

### 3. Add a Gate

You can place a “gate” on an edge to represent a manual or external
block—for instance, requiring human approval before the statistical fit
proceeds.

``` r
g <- groots_add_gate(g, edge_id = "e_data_fit", id = "approval_gate")
```

### 4. Compute State and Plan

Use
[`groots_recompute_state()`](https://sims1253.github.io/groots/reference/groots_recompute_state.md)
to evaluate the graph topologically and determine which nodes are
structurally ready and which are blocked.

``` r
g_state <- groots_recompute_state(g)

# The 'data' node is a root and has no blockers
groots_eligible(g_state)
#> [1] "data"

# The 'fit' node is blocked by the gate; the 'plot' node is blocked because 'fit' is blocked.
groots_blocked(g_state)
#> $fit
#> [1] "gate"
#> 
#> $plot
#> [1] "upstream_blocked"
```

We can generate a structural plan to see how dependencies shake out:

``` r
plan <- groots_plan(g_state)
plan$targets
#> [1] "data" "fit"  "plot"
plan$blocked
#> $fit
#> [1] "gate"
#> 
#> $plot
#> [1] "upstream_blocked"
plan$pending_gates
#> [1] "approval_gate"
```

### 5. Resolve the Gate

Once the external condition is met, you can resolve the gate. Computing
the state again reveals that the downstream dependencies are now
unblocked.

``` r
g_unblocked <- groots_resolve_gate(g_state, id = "approval_gate") |>
  groots_recompute_state()

# Everything is unblocked and ready for execution
groots_eligible(g_unblocked)
#> [1] "data" "fit"  "plot"
groots_blocked(g_unblocked)
#> named list()
```

## Querying Topology

`groots` includes standard helpers for topological traversal and
queries.

``` r
groots_upstream(g_unblocked, "plot")
#> [1] "fit"
groots_descendants(g_unblocked, "data")
#> [1] "fit"  "plot"
groots_leaves(g_unblocked)
#> [1] "plot"
groots_topo_order(g_unblocked)
#> [1] "data" "fit"  "plot"
```
