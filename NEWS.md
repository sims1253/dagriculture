# dagriculture 0.3.0

## Behavior changes

- `dagri_plan()` now derives node state internally on a local copy of the
  graph, so the returned `eligible`/`blocked` are always current even when the
  input graph was never passed through `dagri_recompute_state()`. The input
  graph value is not mutated.

## Breaking changes

- `dagri_ancestors()`, `dagri_descendants()`, `dagri_upstream()`,
  `dagri_downstream()`, and `dagri_has_path()` now abort with
  `dagri_error_not_found` for unknown node ids (previously they returned silent
  empties or `FALSE`).
- Id-taking public arguments (`id`/`from`/`to`/`edge_id`/`name`) now reject
  vectors, `NA`, and empty strings with `dagri_error_invalid_argument` instead
  of dying with a base-R "condition has length > 1" error.
- `dagri_add_gate(graph, edge, ...)`'s `edge` parameter has been renamed to
  `edge_id` for consistency with the rest of the API. Update named call sites.
- `abort_dagri()`, `dagri_target_closure()`, and `dagri_pending_gates()` are no
  longer exported; their results are reachable through `dagri_plan()`'s
  `targets` and `pending_gates` fields.
- `dagri_topo_order()` and `dagri_terminal()` no longer accept an `index`
  argument; they build the adjacency index themselves. The index type has no
  public constructor, so threading it through the public API was a footgun.

## Internal

- Minimum R version raised to 4.4.0; `%||%` relies on base R, which provides
  it since 4.4.0.

# dagriculture 0.2.0

## Features

- **Cycle detection in `dagri_topo_order()`:** Kahn's algorithm aborts with
  `dagri_error_cycle` (`details$cycle_nodes`) instead of silently returning a
  partial order; closes a hole for graphs deserialized from JSON.
- **`dagri_update_node()` replace semantics documented:** `params`/`metadata`
  **replace** the existing fields outright (use `utils::modifyList()` to merge);
  the merge belongs in the consumer, not in this primitive.
- **Referential integrity in `dagri_validate_graph()`:** dangling edge
  `from`/`to` or gate `edge_id` references abort with
  `dagri_error_invalid_argument`; guards data loaded from disk.
- **Graph boundary helpers:** added `dagri_incoming_edges()`,
  `dagri_outgoing_edges()`, `dagri_order_edges()`, `dagri_edge_ids()`, and
  `dagri_graph_diff()` (pure structural diff).
- **Mermaid flowchart export:** added `dagri_mermaid()` — a pure graph-to-text
  renderer with injectable label/class functions and pending-gate annotations.
- **Print methods and S3 classes:** `dagri_graph()` and `dagri_plan()` stamp S3
  classes (still plain lists underneath) and gain `print.dagri_graph()` /
  `print.dagri_plan()` summaries.
- **Getting-started vignette:** added a Structural State Semantics section.
- **Real package Title** in DESCRIPTION.
- **Decision record — generic execution layer:** documented that execution,
  caching, and artifact storage stay out of dagriculture (see
  `design/boundary-contract.md`).

## Performance

- **Internal adjacency index:** `dagri_adjacency()` builds forward/reverse
  neighbor maps in one O(V+E) pass; traversals and planning thread it through,
  taking walks from O(V*E) to O(V+E). Single-node `dagri_upstream()` /
  `dagri_downstream()` keep their O(E) scan.
- **Re-validation collapse:** `dagri_has_path()` now runs the downstream walk inline via the shared index, instead of delegating to `dagri_descendants()` (which re-built the index). `dagri_plan()` builds one shared index across its `dagri_topo_order()` and `dagri_external_blocked()` calls. Each public boundary still does its own cheap structural validation but scans the edge list once per call.

# dagriculture 0.1.6

## Fixes

- **Error message consistency**: `dagri_validate_node_ids()`, `dagri_validate_external_holds()`, and `dagri_pending_gates()` now use `sprintf` to embed missing IDs in error messages, matching the pattern used by all other not-found errors.
- **Package metadata**: added explicit `Author` and `Maintainer` fields to `DESCRIPTION` for bare `R CMD check` compatibility alongside the existing `Authors@R` field.
- **Build ignore cleanup**: added `.desloppify`, `.factory`, `.Rcheck`, and `..Rcheck` to `.Rbuildignore`.

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
