# dagriculture

`dagriculture` is a pure, value-oriented graph library for R. It is
designed to manage graph structures, topological dependencies,
structural validity, and planning, specifically without coupling itself
to external state or runtime execution engines.

## Installation

``` r
# install.packages("pak")
pak::pak("sims1253/dagriculture")
```

## Example

`dagriculture` provides a purely functional API to build graphs,
establish dependencies, and track structural blockers such as “gates”:

``` r
library(dagriculture)

# 1. Define the kinds of nodes allowed in your graph
registry <- dagri_registry(
  dagri_kind("data_source"),
  dagri_kind("transform")
)

# 2. Create an empty graph
graph <- dagri_graph(registry)

# 3. Add nodes and edges
graph <- graph |>
  dagri_add_node("raw_data", "data_source") |>
  dagri_add_node("cleaned_data", "transform") |>
  dagri_add_edge(from = "raw_data", to = "cleaned_data", id = "edge_1")

# 4. Add a structural blocker (gate) to an edge
graph <- dagri_add_gate(graph, edge = "edge_1", id = "review_gate")

# 5. Compute the structural state
graph <- dagri_recompute_state(graph)

# See which nodes are eligible to proceed
dagri_eligible(graph)
```

``` R
## [1] "raw_data"
```

``` r
# See which nodes are blocked, and why
dagri_blocked(graph)
```

``` R
## $cleaned_data
## [1] "gate"
```

``` r
# Planner-visible external holds stay out of graph state
dagri_plan(
  graph,
  external_holds = list(cleaned_data = "manual_review")
)$external_blocked
```

``` R
## $cleaned_data
## [1] "manual_review"
```

``` r
# 6. Resolve the gate to unblock the downstream node
graph <- dagri_resolve_gate(graph, "review_gate") |>
  dagri_recompute_state()

dagri_eligible(graph)
```

``` R
## [1] "raw_data"     "cleaned_data"
```
