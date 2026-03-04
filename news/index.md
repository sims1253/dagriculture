# Changelog

## groots 0.1.0

### Features

- **Constructors**: Functions to create and define kinds, registries,
  and the core graph structure
  ([`groots_kind()`](https://sims1253.github.io/groots/reference/groots_kind.md),
  [`groots_registry()`](https://sims1253.github.io/groots/reference/groots_registry.md),
  [`groots_graph()`](https://sims1253.github.io/groots/reference/groots_graph.md)).
- **Graph Editing**: Implemented structural modifiers to
  add/remove/update nodes, edges, and explicit blockers called gates.
- **Topology Queries**: Topological sorting and traversal utilities
  (ancestors, descendants, upstream, downstream, roots, leaves,
  reachability).
- **Structural Planning**: Determine node eligibility and blocked
  reasons through declarative resolution without side-effects or
  executing runtime jobs
  ([`groots_recompute_state()`](https://sims1253.github.io/groots/reference/groots_recompute_state.md),
  [`groots_plan()`](https://sims1253.github.io/groots/reference/groots_plan.md)).

### Internal

- All structures fully align with the plain-data spec and are serialized
  purely as nested named lists (JSON compatible).
- Defined explicit typed errors in
  [`abort_groots()`](https://sims1253.github.io/groots/reference/abort_groots.md).
- Removed `hello()` template code.

## groots 0.0.0.9000

- Initial development version.
