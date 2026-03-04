# Package index

## Constructors

Functions to create and initialize graphs and registries.

- [`groots_kind()`](https://sims1253.github.io/groots/reference/groots_kind.md)
  : Define a groots kind
- [`groots_registry()`](https://sims1253.github.io/groots/reference/groots_registry.md)
  : Define a groots registry
- [`groots_graph()`](https://sims1253.github.io/groots/reference/groots_graph.md)
  : Create an empty groots graph

## Graph Editing

Functions to structurally modify nodes, edges, and gates.

- [`groots_add_node()`](https://sims1253.github.io/groots/reference/groots_add_node.md)
  : Add a node to a groots graph
- [`groots_update_node()`](https://sims1253.github.io/groots/reference/groots_update_node.md)
  : Update a node in a groots graph
- [`groots_remove_node()`](https://sims1253.github.io/groots/reference/groots_remove_node.md)
  : Remove a node from a groots graph
- [`groots_add_edge()`](https://sims1253.github.io/groots/reference/groots_add_edge.md)
  : Add an edge to a groots graph
- [`groots_remove_edge()`](https://sims1253.github.io/groots/reference/groots_remove_edge.md)
  : Remove an edge from a groots graph
- [`groots_add_gate()`](https://sims1253.github.io/groots/reference/groots_add_gate.md)
  : Add a gate to a groots graph
- [`groots_resolve_gate()`](https://sims1253.github.io/groots/reference/groots_resolve_gate.md)
  : Resolve a gate in a groots graph
- [`groots_reopen_gate()`](https://sims1253.github.io/groots/reference/groots_reopen_gate.md)
  : Reopen a gate in a groots graph
- [`groots_remove_gate()`](https://sims1253.github.io/groots/reference/groots_remove_gate.md)
  : Remove a gate from a groots graph

## Queries and Topology

Accessors and topological traversal functions.

- [`groots_node()`](https://sims1253.github.io/groots/reference/groots_node.md)
  : Get a node from a groots graph
- [`groots_edge()`](https://sims1253.github.io/groots/reference/groots_edge.md)
  : Get an edge from a groots graph
- [`groots_gate()`](https://sims1253.github.io/groots/reference/groots_gate.md)
  : Get a gate from a groots graph
- [`groots_nodes()`](https://sims1253.github.io/groots/reference/groots_nodes.md)
  : Get all nodes
- [`groots_edges()`](https://sims1253.github.io/groots/reference/groots_edges.md)
  : Get all edges
- [`groots_gates()`](https://sims1253.github.io/groots/reference/groots_gates.md)
  : Get all gates
- [`groots_upstream()`](https://sims1253.github.io/groots/reference/groots_upstream.md)
  : Get upstream nodes
- [`groots_downstream()`](https://sims1253.github.io/groots/reference/groots_downstream.md)
  : Get downstream nodes
- [`groots_ancestors()`](https://sims1253.github.io/groots/reference/groots_ancestors.md)
  : Get all ancestors
- [`groots_descendants()`](https://sims1253.github.io/groots/reference/groots_descendants.md)
  : Get all descendants
- [`groots_has_path()`](https://sims1253.github.io/groots/reference/groots_has_path.md)
  : Check path existence
- [`groots_roots()`](https://sims1253.github.io/groots/reference/groots_roots.md)
  : Get graph roots
- [`groots_leaves()`](https://sims1253.github.io/groots/reference/groots_leaves.md)
  : Get graph leaves
- [`groots_topo_order()`](https://sims1253.github.io/groots/reference/groots_topo_order.md)
  : Get topological order

## State and Planning

Functions to resolve structural conditions and produce graph execution
plans.

- [`groots_recompute_state()`](https://sims1253.github.io/groots/reference/groots_recompute_state.md)
  : Recompute graph state
- [`groots_eligible()`](https://sims1253.github.io/groots/reference/groots_eligible.md)
  : Get eligible nodes
- [`groots_blocked()`](https://sims1253.github.io/groots/reference/groots_blocked.md)
  : Get blocked nodes
- [`groots_terminal()`](https://sims1253.github.io/groots/reference/groots_terminal.md)
  : Get terminal nodes
- [`groots_plan()`](https://sims1253.github.io/groots/reference/groots_plan.md)
  : Create an execution plan

## Internals

Package internal utilities.

- [`abort_groots()`](https://sims1253.github.io/groots/reference/abort_groots.md)
  : Abort with a typed groots error
