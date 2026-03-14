# dagriculture 0.1.5

## Fixes

- **`param_schema` validation**: `dagri_kind()` now validates that `param_schema` is a named list or `NULL` before scanning it for closures, rejecting non-lists and unnamed inputs early.
- **DFS re-validation**: `dagri_dfs()` and `dagri_topo_order()` no longer re-validate the graph on every iteration, improving performance for large reachability queries.
- **Subset validation in `dagri_topo_order()`**: the `subset` argument is now validated and de-duplicated via `dagri_validate_node_ids()` before building the topological sort.
- **Documentation**: fixed `edge_id` parameter name to `edge` in `dagri_add_gate()` calls in README and doc vignette. Expanded `dagri_validate_graph()` description to document full validation scope.

# dagriculture 0.1.4

## Features

- **Graph validation**: all public functions now validate that the `graph` argument has the required structure (`dagri_validate_graph()`), producing a clear error instead of cryptic R failures on malformed input.
- **Input contract enforcement**: `dagri_kind()` validates that `input_contract` is a named list with character or `NULL` values. `dagri_add_node()` checks that node `params` satisfy the kind's `input_contract` at creation time.

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
