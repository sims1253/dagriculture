# dagriculture 0.1.3

## Fixes

- **CI and structural helper linting**: fixed `.lintr` snapshot exclusions for current `lintr`, documented `dagri_target_closure()` and `dagri_pending_gates()`, updated `dagri_terminal()` docs for scoped targets, and shortened structural test fixture names to satisfy CI lint checks.

# dagriculture 0.1.2

## Fixes

- **Node deletion cleanup**: `dagri_remove_node()` now removes incident edges and any gates attached to those edges, preventing dangling references after structural deletes.

# dagriculture 0.1.1

## Features

- **Planner-visible external holds**: `dagri_plan()` now accepts caller-supplied `external_holds`, preserves structural `eligible` semantics, and returns propagated non-structural holds in `external_blocked` without mutating the graph.

# dagriculture 0.1.0

## Features

- **Constructors**: Functions to create and define kinds, registries, and the core graph structure (`dagri_kind()`, `dagri_registry()`, `dagri_graph()`).
- **Graph Editing**: Implemented structural modifiers to add/remove/update nodes, edges, and explicit blockers called gates.
- **Topology Queries**: Topological sorting and traversal utilities (ancestors, descendants, upstream, downstream, roots, leaves, reachability).
- **Structural Planning**: Determine node eligibility and blocked reasons through declarative resolution without side-effects or executing runtime jobs (`dagri_recompute_state()`, `dagri_plan()`).

## Internal

- All structures fully align with the plain-data spec and are serialized purely as nested named lists (JSON compatible).
- Defined explicit typed errors in `abort_dagri()`.
- Removed `hello()` template code.

# dagriculture 0.0.0.9000

- Initial development version.
