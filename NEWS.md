# groots 0.1.0

## Features

- **Constructors**: Functions to create and define kinds, registries, and the core graph structure (`groots_kind()`, `groots_registry()`, `groots_graph()`).
- **Graph Editing**: Implemented structural modifiers to add/remove/update nodes, edges, and explicit blockers called gates.
- **Topology Queries**: Topological sorting and traversal utilities (ancestors, descendants, upstream, downstream, roots, leaves, reachability).
- **Structural Planning**: Determine node eligibility and blocked reasons through declarative resolution without side-effects or executing runtime jobs (`groots_recompute_state()`, `groots_plan()`).

## Internal

- All structures fully align with the plain-data spec and are serialized purely as nested named lists (JSON compatible).
- Defined explicit typed errors in `abort_groots()`.
- Removed `hello()` template code.

# groots 0.0.0.9000

- Initial development version.
