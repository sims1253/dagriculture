# dagriculture 0.2.0

## Features

- **Cycle detection in `dagri_topo_order()`:** Kahn's algorithm now detects
  cycles instead of silently returning a partial order. After the Kahn loop,
  any node that could not be emitted is reported via an abort of class
  `dagri_error_cycle` with `details$cycle_nodes` naming the cycle-participating
  nodes. `dagri_add_edge()` prevents cycles at edit time, but consumers (e.g.
  bayesgrove) deserialize graphs from JSON, so a corrupted file could previously
  smuggle a cycle past the editor and cause planners to silently drop nodes.
- **`dagri_update_node()` replace semantics documented:** the `params` and
  `metadata` arguments **replace** the existing fields outright (they are not
  merged). This was already the runtime behavior; it is now documented loudly in
  the roxygen `@details`, with a pointer to `utils::modifyList()` for callers
  that need merge semantics. The merge belongs in the consumer (e.g. bayesgrove's
  `bg_update_node()`), not in this primitive.
- **Referential integrity in `dagri_validate_graph()`:** the entry-point
  validator now enforces that every edge's `$from`/`$to` references a node in
  `graph$nodes` and every gate's `$edge_id` references an edge in `graph$edges`.
  Dangling references abort with `dagri_error_invalid_argument` and a `details`
  field naming the offending ids. This guards the same threat model as the new
  cycle check: data loaded from disk bypassed the editing API, so it could
  previously carry dangling references undetected.
- **bayesgrove boundary migration (first tranche):** ported the graph-generic edge and diff helpers that previously lived in bayesgrove's `R/dagri-adapters.R` (`bg_dagri_*` migration candidates) into dagriculture, where the graph lives. bayesgrove pins `dagriculture (>= 0.2.0)` and thins its adapters to pass-throughs. New exported functions:
  - `dagri_incoming_edges(graph, node_id)` and `dagri_outgoing_edges(graph, node_id)` return the incident edge objects (not just neighbor ids — `dagri_upstream()`/`dagri_downstream()` already cover ids), preserving container names.
  - `dagri_order_edges(edges)` deterministically orders an edge list by embedded `edge$id`, for stable fingerprinting of multi-input nodes.
  - `dagri_edge_ids(edges)` returns sorted unique edge ids, preferring container names and falling back to embedded `edge$id` fields; aborts with `dagri_error_invalid_argument` when neither yields complete ids.
  - `dagri_graph_diff(before, after)` returns a pure structural diff (`added_nodes`, `removed_nodes`, `added_edges`, `removed_edges`) with no workflow semantics.

- **Mermaid flowchart export:** added `dagri_mermaid(graph, node_label = NULL, node_class = NULL, direction = "TD")`, a pure graph-to-text renderer that emits a Mermaid flowchart block as a single length-1 character scalar. `node_label` and `node_class` are optional `(node) -> string` injection functions (defaults use `node$label %||% node$id` and `node$state %||% NA_character_`, skipping the `class` line when `NA`/empty). Pending gates are rendered as edge annotations (`<from> -- "gate: g1, g2" --> <to>`); resolved gates are silent. Labels and gate annotation text are sanitized (`"` -> `'`; `[](){}|<>` and newlines -> space) since Mermaid breaks on those characters. Node ids are emitted verbatim as Mermaid identifiers (must be Mermaid-safe by convention). Zero new dependencies, no I/O. This is the domain-generic renderer that bayesgrove's `bg_graph_mermaid()` will wrap to supply branch-aware labels and run-state CSS classes.

- **Print methods and S3 classes:** `dagri_graph()` now stamps S3 class `c("dagri_graph", "list")` on its return value, and `dagri_plan()` stamps `c("dagri_plan", "list")` on its return value. Both remain plain named lists underneath: field access (`graph$nodes`, `plan$targets`), `$`/`[[` indexing, and JSON serialization are unchanged, and `dagri_validate_graph()` does not require the class. New S3 print methods:
  - `print.dagri_graph()` writes a concise multi-line summary (package + version, node/edge/gate counts, `graph$version`, registry kind names) and returns the graph invisibly. Graph-mutating functions preserve the `dagri_graph` class on the returned copy.
  - `print.dagri_plan()` writes target count, topological-order length, and eligible/blocked/terminal/pending-gate counts, and returns the plan invisibly.
  - This is the only interactive UX surface a value-oriented library has; core correctness never depends on S3 dispatch.

- **Getting-started vignette state-semantics table:** added a "Structural State Semantics" section explaining the three structural states (`new`/`ready`/`blocked`), the block reasons (`none`/`gate`/`upstream_blocked`), and explicitly scoping what `dagri_recompute_state()` does NOT track (execution states like `done`/`failed`/`running`/`skipped` are the consumer's overlay, not part of the structural model). This is the most common confusion point for a new consumer.

- **Real package Title:** replaced the template placeholder `Tools for dagriculture` in `DESCRIPTION` with `Pure Value-Oriented Directed Acyclic Graphs for Task Planning`; the `Description` field already matched and is unchanged.
- **Decision record — generic execution layer:** documented in `design/boundary-contract.md` that the eventual extraction of fingerprinting, content-addressed artifact storage, plan-state derivation, and job records out of bayesgrove will NOT land in dagriculture. dagriculture stays pure and value-oriented; the execution layer will be a separate package when a second consumer exists or bayesgrove's scheduler stabilizes the executor contract.

## Performance

- **Internal adjacency index:** added an internal `dagri_adjacency()` that builds forward and reverse neighbor maps plus incident-edge maps in a single O(V+E) pass. Traversal and planning internals (`dagri_ancestors()`, `dagri_descendants()`, `dagri_has_path()`, `dagri_topo_order()`, `dagri_recompute_state()`, `dagri_terminal()`, `dagri_external_blocked()`, `dagri_plan()`) now thread this index through the walk instead of scanning the full edge list per neighbor lookup, taking traversals from O(V*E) to O(V+E) and graph construction (via `dagri_add_edge()`'s cycle check) from O(N^2*E) to O(N^2). The single-node public queries `dagri_upstream()` / `dagri_downstream()` keep their linear scan (documented O(E)) since the index overhead does not pay off for a single lookup. The index is a derived per-call value and is never stored on the graph, so the pure-value, immutable API is unchanged.
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
