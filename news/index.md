# Changelog

## dagriculture (development version)

### Documentation

- **Serialization vignette:** added “Serialization and the Consumer
  Boundary”
  ([`vignette("serialization-boundary")`](https://sims1253.github.io/dagriculture/articles/serialization-boundary.md)):
  the graph snapshot shape, a canonical jsonlite writer/reader recipe
  (`auto_unbox`/`null`/`digits` options, `simplifyVector = FALSE`, null
  normalization, key/id consistency check), the recommended safe id
  pattern, the exact no-code boundary of
  [`dagri_validate_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_graph.md)
  on load (including the RDS path), and a direct statement that
  `param_schema` is declarative and not enforced against node params.
  `jsonlite` added to `Suggests`; the recipe is covered by tests.

### Features

- **Metadata support across constructors:**
  [`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md),
  [`dagri_registry()`](https://sims1253.github.io/dagriculture/reference/dagri_registry.md),
  and
  [`dagri_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_graph.md)
  now accept a `metadata` argument (named plain data, stored as given),
  so graph/registry/kind metadata no longer requires mutating package
  internals.
- **Edge and gate update mutators:** added
  [`dagri_update_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_update_edge.md)
  (optional `type`/`metadata` replacement) and
  [`dagri_update_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_update_gate.md)
  (optional `metadata` replacement). Both are immutable
  value-in/value-out mutators using the same replace-not-merge semantics
  as
  [`dagri_update_node()`](https://sims1253.github.io/dagriculture/reference/dagri_update_node.md),
  and both bump `graph$version` by 1. Value-aware
  [`dagri_graph_diff()`](https://sims1253.github.io/dagriculture/reference/dagri_graph_diff.md)
  now reports these metadata and `type` edits through
  `changed_edges`/`changed_gates`.
- **Value-aware graph diffing with gate support:**
  [`dagri_graph_diff()`](https://sims1253.github.io/dagriculture/reference/dagri_graph_diff.md)
  now also reports `added_gates`, `removed_gates`, and `changed_nodes` /
  `changed_edges` / `changed_gates` alongside the existing structural
  vectors (which are unchanged). `changed_*` covers ids present in both
  graphs whose tracked fields differ — node
  `kind`/`label`/`params`/`state`/ `block_reason`/`metadata`, edge
  `from`/`to`/`type`/`metadata`, gate `edge_id`/`status`/`metadata` —
  compared with [`identical()`](https://rdrr.io/r/base/identical.html)
  on in-memory values; `graph$version` is ignored. The new
  `include_values = TRUE` adds a `values` element carrying
  `list(before = ..., after = ...)` per changed field. `changed_*` ids
  are ordered by the named-map insertion order of `after`.
- **Tabular accessors:** added
  [`dagri_nodes_df()`](https://sims1253.github.io/dagriculture/reference/dagri_nodes_df.md),
  [`dagri_edges_df()`](https://sims1253.github.io/dagriculture/reference/dagri_edges_df.md),
  and
  [`dagri_gates_df()`](https://sims1253.github.io/dagriculture/reference/dagri_gates_df.md)
  — base `data.frame` views of the stored node, edge, and gate records
  for reporting consumers. Rows follow graph insertion order,
  `params`/`metadata` stay list-columns holding the stored lists
  verbatim, ids live in the `id` column instead of row names, and empty
  graphs yield zero-row frames with identical column names and classes.
- **Customization hooks for
  [`dagri_mermaid()`](https://sims1253.github.io/dagriculture/reference/dagri_mermaid.md):**
  the renderer gains `gate_label`, `include_resolved_gates`,
  `class_defs`, and `header` arguments without changing its pure
  graph-to-text contract. With every argument at its default the output
  is byte-for-byte identical to before.
- **`gate_label` callback:** `function(gate, edge) -> string` supplies
  per-gate edge annotation labels (e.g. “pending review”, reviewer
  names) instead of the default `gate: <id>` text; `NULL`/`NA` returns
  fall back to the default, and non-character or multi-element returns
  are coerced exactly like `node_label` returns.
- **`include_resolved_gates`:** opt-in flag that also annotates resolved
  gates on their edge, each suffixed with `" (resolved)"`, in gate
  insertion order; pending gates render exactly as before.
- **`class_defs` / `header` styling injection:** Mermaid `classDef`
  statements are sanitized and emitted after the `flowchart` line; raw
  preamble lines (e.g. `%%{init: ...}%%` directives) pass through
  verbatim before it, with only control characters stripped. Header
  lines are trusted caller input; everything derived from graph data
  stays sanitized.

### Behavior changes

- `metadata` is now validated at every entry point
  ([`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md),
  [`dagri_registry()`](https://sims1253.github.io/dagriculture/reference/dagri_registry.md),
  [`dagri_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_graph.md),
  [`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md),
  [`dagri_update_node()`](https://sims1253.github.io/dagriculture/reference/dagri_update_node.md),
  [`dagri_add_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_add_edge.md),
  [`dagri_add_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_add_gate.md)):
  it must be a named list of plain data, and closures, environments,
  formulas, language objects, S4 objects, external pointers, or weak
  references are rejected with `dagri_error_invalid_argument`
  (previously metadata was stored unvalidated, so code-bearing or
  reference-bearing values could silently enter graphs and later break
  serialization).
- **Per-node status view in
  [`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md):**
  plans now carry a `node_status` field — a named list keyed by node id
  covering the target closure in `topo_order` order — so consumers no
  longer re-derive why each node is blocked. Each entry exposes the
  derived structural `state` and `block_reason`, the `pending_gates` on
  the node’s inbound edges (edge insertion order, then gate insertion
  order), the propagated `external_hold` reason (`NULL` when none), the
  direct `upstream_blockers` (unique, incoming-edge insertion order),
  and final structural `eligible`. `eligible` is identical to membership
  in `plan$eligible` and deliberately stays `TRUE` under external holds,
  preserving the existing separation between structural eligibility and
  external blocking. Existing plan fields are unchanged; the new field
  is additive.

## dagriculture 0.3.0

### Behavior changes

- [`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md)
  now derives node state internally on a local copy of the graph, so the
  returned `eligible`/`blocked` are always current even when the input
  graph was never passed through
  [`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md).
  The input graph value is not mutated.

### Breaking changes

- [`dagri_ancestors()`](https://sims1253.github.io/dagriculture/reference/dagri_ancestors.md),
  [`dagri_descendants()`](https://sims1253.github.io/dagriculture/reference/dagri_descendants.md),
  [`dagri_upstream()`](https://sims1253.github.io/dagriculture/reference/dagri_upstream.md),
  [`dagri_downstream()`](https://sims1253.github.io/dagriculture/reference/dagri_downstream.md),
  and
  [`dagri_has_path()`](https://sims1253.github.io/dagriculture/reference/dagri_has_path.md)
  now abort with `dagri_error_not_found` for unknown node ids
  (previously they returned silent empties or `FALSE`).
- Id-taking public arguments (`id`/`from`/`to`/`edge_id`/`name`) now
  reject vectors, `NA`, and empty strings with
  `dagri_error_invalid_argument` instead of dying with a base-R
  “condition has length \> 1” error.
- `dagri_add_gate(graph, edge, ...)`’s `edge` parameter has been renamed
  to `edge_id` for consistency with the rest of the API. Update named
  call sites.
- [`abort_dagri()`](https://sims1253.github.io/dagriculture/reference/abort_dagri.md),
  [`dagri_target_closure()`](https://sims1253.github.io/dagriculture/reference/dagri_target_closure.md),
  and
  [`dagri_pending_gates()`](https://sims1253.github.io/dagriculture/reference/dagri_pending_gates.md)
  are no longer exported; their results are reachable through
  [`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md)’s
  `targets` and `pending_gates` fields.
- [`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)
  and
  [`dagri_terminal()`](https://sims1253.github.io/dagriculture/reference/dagri_terminal.md)
  no longer accept an `index` argument; they build the adjacency index
  themselves. The index type has no public constructor, so threading it
  through the public API was a footgun.

### Internal

- Minimum R version raised to 4.4.0; `%||%` relies on base R, which
  provides it since 4.4.0.

## dagriculture 0.2.0

### Features

- **Cycle detection in
  [`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md):**
  Kahn’s algorithm aborts with `dagri_error_cycle`
  (`details$cycle_nodes`) instead of silently returning a partial order;
  closes a hole for graphs deserialized from JSON.
- **[`dagri_update_node()`](https://sims1253.github.io/dagriculture/reference/dagri_update_node.md)
  replace semantics documented:** `params`/`metadata` **replace** the
  existing fields outright (use
  [`utils::modifyList()`](https://rdrr.io/r/utils/modifyList.html) to
  merge); the merge belongs in the consumer, not in this primitive.
- **Referential integrity in
  [`dagri_validate_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_graph.md):**
  dangling edge `from`/`to` or gate `edge_id` references abort with
  `dagri_error_invalid_argument`; guards data loaded from disk.
- **Graph boundary helpers:** added
  [`dagri_incoming_edges()`](https://sims1253.github.io/dagriculture/reference/dagri_incoming_edges.md),
  [`dagri_outgoing_edges()`](https://sims1253.github.io/dagriculture/reference/dagri_outgoing_edges.md),
  [`dagri_order_edges()`](https://sims1253.github.io/dagriculture/reference/dagri_order_edges.md),
  [`dagri_edge_ids()`](https://sims1253.github.io/dagriculture/reference/dagri_edge_ids.md),
  and
  [`dagri_graph_diff()`](https://sims1253.github.io/dagriculture/reference/dagri_graph_diff.md)
  (pure structural diff).
- **Mermaid flowchart export:** added
  [`dagri_mermaid()`](https://sims1253.github.io/dagriculture/reference/dagri_mermaid.md)
  — a pure graph-to-text renderer with injectable label/class functions
  and pending-gate annotations.
- **Print methods and S3 classes:**
  [`dagri_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_graph.md)
  and
  [`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md)
  stamp S3 classes (still plain lists underneath) and gain
  [`print.dagri_graph()`](https://sims1253.github.io/dagriculture/reference/print.dagri_graph.md)
  /
  [`print.dagri_plan()`](https://sims1253.github.io/dagriculture/reference/print.dagri_plan.md)
  summaries.
- **Getting-started vignette:** added a Structural State Semantics
  section.
- **Real package Title** in DESCRIPTION.
- **Decision record — generic execution layer:** documented that
  execution, caching, and artifact storage stay out of dagriculture (see
  `design/boundary-contract.md`).

### Performance

- **Internal adjacency index:**
  [`dagri_adjacency()`](https://sims1253.github.io/dagriculture/reference/dagri_adjacency.md)
  builds forward/reverse neighbor maps in one O(V+E) pass; traversals
  and planning thread it through, taking walks from O(V\*E) to O(V+E).
  Single-node
  [`dagri_upstream()`](https://sims1253.github.io/dagriculture/reference/dagri_upstream.md)
  /
  [`dagri_downstream()`](https://sims1253.github.io/dagriculture/reference/dagri_downstream.md)
  keep their O(E) scan.
- **Re-validation collapse:**
  [`dagri_has_path()`](https://sims1253.github.io/dagriculture/reference/dagri_has_path.md)
  now runs the downstream walk inline via the shared index, instead of
  delegating to
  [`dagri_descendants()`](https://sims1253.github.io/dagriculture/reference/dagri_descendants.md)
  (which re-built the index).
  [`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md)
  builds one shared index across its
  [`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)
  and
  [`dagri_external_blocked()`](https://sims1253.github.io/dagriculture/reference/dagri_external_blocked.md)
  calls. Each public boundary still does its own cheap structural
  validation but scans the edge list once per call.

## dagriculture 0.1.6

### Fixes

- **Error message consistency**:
  [`dagri_validate_node_ids()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_node_ids.md),
  [`dagri_validate_external_holds()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_external_holds.md),
  and
  [`dagri_pending_gates()`](https://sims1253.github.io/dagriculture/reference/dagri_pending_gates.md)
  now use `sprintf` to embed missing IDs in error messages, matching the
  pattern used by all other not-found errors.
- **Package metadata**: added explicit `Author` and `Maintainer` fields
  to `DESCRIPTION` for bare `R CMD check` compatibility alongside the
  existing `Authors@R` field.
- **Build ignore cleanup**: added `.desloppify`, `.factory`, `.Rcheck`,
  and `..Rcheck` to `.Rbuildignore`.

## dagriculture 0.1.5

### Fixes

- **`param_schema` validation**:
  [`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md)
  now validates that `param_schema` is a named list or `NULL` before
  scanning it for closures, rejecting non-lists and unnamed inputs
  early.
- **DFS re-validation**:
  [`dagri_dfs()`](https://sims1253.github.io/dagriculture/reference/dagri_dfs.md)
  and
  [`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)
  no longer re-validate the graph on every iteration, improving
  performance for large reachability queries.
- **Subset validation in
  [`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)**:
  the `subset` argument is now validated and de-duplicated via
  [`dagri_validate_node_ids()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_node_ids.md)
  before building the topological sort.
- **Documentation**: fixed `edge_id` parameter name to `edge` in
  [`dagri_add_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_add_gate.md)
  calls in README and doc vignette. Expanded
  [`dagri_validate_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_graph.md)
  description to document full validation scope.

## dagriculture 0.1.4

### Features

- **Graph validation**: all public functions now validate that the
  `graph` argument has the required structure
  ([`dagri_validate_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_graph.md)),
  producing a clear error instead of cryptic R failures on malformed
  input.
- **Input contract enforcement**:
  [`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md)
  validates that `input_contract` is a named list with character or
  `NULL` values.
  [`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md)
  checks that node `params` satisfy the kind’s `input_contract` at
  creation time.

## dagriculture 0.1.3

### Fixes

- **CI and structural helper linting**: fixed `.lintr` snapshot
  exclusions for current `lintr`, documented
  [`dagri_target_closure()`](https://sims1253.github.io/dagriculture/reference/dagri_target_closure.md)
  and
  [`dagri_pending_gates()`](https://sims1253.github.io/dagriculture/reference/dagri_pending_gates.md),
  updated
  [`dagri_terminal()`](https://sims1253.github.io/dagriculture/reference/dagri_terminal.md)
  docs for scoped targets, and shortened structural test fixture names
  to satisfy CI lint checks.

## dagriculture 0.1.2

### Fixes

- **Node deletion cleanup**:
  [`dagri_remove_node()`](https://sims1253.github.io/dagriculture/reference/dagri_remove_node.md)
  now removes incident edges and any gates attached to those edges,
  preventing dangling references after structural deletes.

## dagriculture 0.1.1

### Features

- **Planner-visible external holds**:
  [`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md)
  now accepts caller-supplied `external_holds`, preserves structural
  `eligible` semantics, and returns propagated non-structural holds in
  `external_blocked` without mutating the graph.

## dagriculture 0.1.0

### Features

- **Constructors**: Functions to create and define kinds, registries,
  and the core graph structure
  ([`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md),
  [`dagri_registry()`](https://sims1253.github.io/dagriculture/reference/dagri_registry.md),
  [`dagri_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_graph.md)).
- **Graph Editing**: Implemented structural modifiers to
  add/remove/update nodes, edges, and explicit blockers called gates.
- **Topology Queries**: Topological sorting and traversal utilities
  (ancestors, descendants, upstream, downstream, roots, leaves,
  reachability).
- **Structural Planning**: Determine node eligibility and blocked
  reasons through declarative resolution without side-effects or
  executing runtime jobs
  ([`dagri_recompute_state()`](https://sims1253.github.io/dagriculture/reference/dagri_recompute_state.md),
  [`dagri_plan()`](https://sims1253.github.io/dagriculture/reference/dagri_plan.md)).

### Internal

- All structures fully align with the plain-data spec and are serialized
  purely as nested named lists (JSON compatible).
- Defined explicit typed errors in
  [`abort_dagri()`](https://sims1253.github.io/dagriculture/reference/abort_dagri.md).
- Removed `hello()` template code.

## dagriculture 0.0.0.9000

- Initial development version.
