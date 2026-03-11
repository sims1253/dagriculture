# Package index

## Constructors

Functions to create and initialize graphs and registries.

- [`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md)
  : Define a dagriculture kind
- [`dagri_registry()`](https://sims1253.github.io/dagriculture/reference/dagri_registry.md)
  : Define a dagriculture registry
- [`dagri_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_graph.md)
  : Create an empty dagriculture graph

## Graph Editing

Functions to structurally modify nodes, edges, and gates.

- [`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md)
  : Add a node to a dagriculture graph
- [`dagri_update_node()`](https://sims1253.github.io/dagriculture/reference/dagri_update_node.md)
  : Update a node in a dagriculture graph
- [`dagri_remove_node()`](https://sims1253.github.io/dagriculture/reference/dagri_remove_node.md)
  : Remove a node from a dagriculture graph
- [`dagri_add_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_add_edge.md)
  : Add an edge to a dagriculture graph
- [`dagri_remove_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_remove_edge.md)
  : Remove an edge from a dagriculture graph
- [`dagri_add_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_add_gate.md)
  : Add a gate to a dagriculture graph
- [`dagri_resolve_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_resolve_gate.md)
  : Resolve a gate in a dagriculture graph
- [`dagri_reopen_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_reopen_gate.md)
  : Reopen a gate in a dagriculture graph
- [`dagri_remove_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_remove_gate.md)
  : Remove a gate from a dagriculture graph

## Queries and Topology

Accessors and topological traversal functions.

- [`dagri_node()`](https://sims1253.github.io/dagriculture/reference/dagri_node.md)
  : Get a node from a dagriculture graph
- [`dagri_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_edge.md)
  : Get an edge from a dagriculture graph
- [`dagri_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_gate.md)
  : Get a gate from a dagriculture graph
- [`dagri_nodes()`](https://sims1253.github.io/dagriculture/reference/dagri_nodes.md)
  : Get all nodes
- [`dagri_edges()`](https://sims1253.github.io/dagriculture/reference/dagri_edges.md)
  : Get all edges
- [`dagri_gates()`](https://sims1253.github.io/dagriculture/reference/dagri_gates.md)
  : Get all gates
- [`dagri_upstream()`](https://sims1253.github.io/dagriculture/reference/dagri_upstream.md)
  : Get upstream nodes
- [`dagri_downstream()`](https://sims1253.github.io/dagriculture/reference/dagri_downstream.md)
  : Get downstream nodes
- [`dagri_ancestors()`](https://sims1253.github.io/dagriculture/reference/dagri_ancestors.md)
  : Get all ancestors
- [`dagri_descendants()`](https://sims1253.github.io/dagriculture/reference/dagri_descendants.md)
  : Get all descendants
- [`dagri_has_path()`](https://sims1253.github.io/dagriculture/reference/dagri_has_path.md)
  : Check path existence
- [`dagri_roots()`](https://sims1253.github.io/dagriculture/reference/dagri_roots.md)
  : Get graph roots
- [`dagri_leaves()`](https://sims1253.github.io/dagriculture/reference/dagri_leaves.md)
  : Get graph leaves
- [`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)
  : Get topological order

## State and Planning

Functions to resolve structural conditions and produce graph execution
plans.

- [`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md)
  : Recompute graph state
- [`dagri_eligible()`](https://sims1253.github.io/dagriculture/reference/dagri_eligible.md)
  : Get eligible nodes
- [`dagri_blocked()`](https://sims1253.github.io/dagriculture/reference/dagri_blocked.md)
  : Get blocked nodes
- [`dagri_terminal()`](https://sims1253.github.io/dagriculture/reference/dagri_terminal.md)
  : Get terminal nodes
- [`dagri_target_closure()`](https://sims1253.github.io/dagriculture/reference/dagri_target_closure.md)
  : Get the structural closure of target nodes
- [`dagri_pending_gates()`](https://sims1253.github.io/dagriculture/reference/dagri_pending_gates.md)
  : Get pending gates
- [`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md)
  : Create a structural plan

## Internals

Package internal utilities.

- [`abort_dagri()`](https://sims1253.github.io/dagriculture/reference/abort_dagri.md)
  : Abort with a typed dagriculture error
