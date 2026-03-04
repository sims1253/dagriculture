# groots

`groots` is a pure, value-oriented graph library for R. It is designed
to manage graph structures, topological dependencies, structural
validity, and planning, specifically without coupling itself to external
state or runtime execution engines.

## Installation

``` r
# install.packages("pak")
pak::pak("sims1253/groots")
```

## Example

`groots` provides a purely functional API to build graphs, establish
dependencies, and track structural blockers such as “gates”:

``` r
library(groots)

# 1. Define the kinds of nodes allowed in your graph
registry <- groots_registry(
  groots_kind("data_source"),
  groots_kind("transform")
)

# 2. Create an empty graph
graph <- groots_graph(registry)

# 3. Add nodes and edges
graph <- graph |>
  groots_add_node("raw_data", "data_source") |>
  groots_add_node("cleaned_data", "transform") |>
  groots_add_edge(from = "raw_data", to = "cleaned_data", id = "edge_1")

# 4. Add a structural blocker (gate) to an edge
graph <- groots_add_gate(graph, edge_id = "edge_1", id = "review_gate")

# 5. Compute the structural state
graph <- groots_recompute_state(graph)

# See which nodes are eligible to proceed
groots_eligible(graph)
```

``` R
## [1] "raw_data"
```

``` r
# See which nodes are blocked, and why
groots_blocked(graph)
```

``` R
## $cleaned_data
## [1] "gate"
```

``` r
# 6. Resolve the gate to unblock the downstream node
graph <- groots_resolve_gate(graph, "review_gate") |>
  groots_recompute_state()

groots_eligible(graph)
```

``` R
## [1] "raw_data"     "cleaned_data"
```
