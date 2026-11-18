# dagriculture 0.3.0

This release covers all changes since 0.1.6. Version 0.2.0 was never
released; its changes are listed here.

## Breaking changes

- Minimum R version raised to 4.4.0; `%||%` relies on base R, which provides
  it since 4.4.0.
- `dagri_ancestors()`, `dagri_descendants()`, `dagri_upstream()`,
  `dagri_downstream()`, and `dagri_has_path()` now abort with
  `dagri_error_not_found` for unknown node ids (previously they returned silent
  empties or `FALSE`).
- The id arguments (`id`/`node_id`/`from`/`to`/`edge_id`/`gate_id`/`name`) of
  `dagri_kind()`, `dagri_add_node()`, `dagri_update_node()`,
  `dagri_remove_node()`, `dagri_add_edge()`, `dagri_update_edge()`,
  `dagri_remove_edge()`, `dagri_add_gate()`, `dagri_update_gate()`,
  `dagri_remove_gate()`, `dagri_resolve_gate()`, `dagri_reopen_gate()`,
  `dagri_upstream()`, `dagri_downstream()`, `dagri_ancestors()`,
  `dagri_descendants()`, `dagri_has_path()`, `dagri_incoming_edges()` and
  `dagri_outgoing_edges()` now reject vectors, `NA`, and empty strings with
  `dagri_error_invalid_argument`. The getters `dagri_node()`, `dagri_edge()` and
  `dagri_gate()` do not check their `id` this way.
- `dagri_add_gate(graph, edge, ...)`'s `edge` parameter has been renamed to
  `edge_id` for consistency with the rest of the API. Update named call sites.
- `abort_dagri()`, `dagri_target_closure()`, and `dagri_pending_gates()` are no
  longer exported; their results are reachable through `dagri_plan()`'s
  `targets` and `pending_gates` fields.

## Behavior changes

- `dagri_plan()` now derives node state internally on a local copy of the
  graph, so the returned `eligible`/`blocked` are always current even when the
  input graph was never passed through `dagri_recompute_state()`. The input
  graph value is not mutated.
- `metadata` is now validated at every entry point (`dagri_kind()`,
  `dagri_registry()`, `dagri_graph()`, `dagri_add_node()`, `dagri_update_node()`,
  `dagri_add_edge()`, `dagri_update_edge()`, `dagri_add_gate()`,
  `dagri_update_gate()`): it must be a named list of plain
  data, and closures, environments, formulas, language objects, S4 objects,
  external pointers, or weak references are rejected
  with `dagri_error_invalid_argument` (previously metadata was stored
  unvalidated, so code-bearing or reference-bearing values could silently enter
  graphs and later break serialization).
- **Cycle detection in `dagri_topo_order()`:** Kahn's algorithm aborts with
  `dagri_error_cycle` (`details$cycle_nodes`) instead of silently returning a
  partial order; closes a hole for graphs deserialized from JSON.
  `details$cycle_nodes` and the message name only the nodes that lie on a
  cycle, not the nodes downstream of one. Two edges between the same pair of
  nodes are no longer reported as a cycle.
- **Referential integrity in `dagri_validate_graph()`:** dangling edge
  `from`/`to` or gate `edge_id` references abort with
  `dagri_error_invalid_argument`; guards data loaded from disk.
- **Self-loops are refused:** `dagri_add_edge(graph, "a", "a")` now aborts
  with `dagri_error_cycle` instead of storing an edge from `a` to itself. A
  graph that already holds a self-loop, for example one loaded from disk, is
  refused with the same class by every function that takes a graph, except
  the print methods, with the edge id in `details$edge_id` and the node in
  `details$cycle_nodes`. Before, such a graph
  passed validation: `dagri_has_path(graph, "a", "a")` returned `TRUE`,
  `dagri_mermaid()` drew the loop, and only the topological functions aborted.

## Features

- **Graph boundary helpers:** added `dagri_incoming_edges()`,
  `dagri_outgoing_edges()`, `dagri_order_edges()`, and `dagri_edge_ids()`.
- **Mermaid flowchart export:** added `dagri_mermaid()` — a pure graph-to-text
  renderer with injectable label/class functions and pending-gate annotations.
- **Print methods and S3 classes:** `dagri_graph()` and `dagri_plan()` stamp S3
  classes (still plain lists underneath) and gain `print.dagri_graph()` /
  `print.dagri_plan()` summaries.
- **Metadata support across constructors:** `dagri_kind()`, `dagri_registry()`,
  and `dagri_graph()` now accept a `metadata` argument (named plain data,
  stored as given), so graph/registry/kind metadata no longer requires
  mutating package internals.
- **Edge and gate update mutators:** added `dagri_update_edge()` (optional
  `type`/`metadata` replacement) and `dagri_update_gate()` (optional `metadata`
  replacement). Both are immutable value-in/value-out mutators using the same
  replace-not-merge semantics as `dagri_update_node()`, and both bump
  `graph$version` by 1. `dagri_graph_diff()` reports these
  metadata and `type` edits through `changed_edges`/`changed_gates`.
- **Graph diffing:** added `dagri_graph_diff()`, a pure diff of two graphs.
  It reports `added_nodes`, `removed_nodes`, `added_edges`, `removed_edges`,
  `added_gates`, `removed_gates`, and `changed_nodes` / `changed_edges` /
  `changed_gates`. `changed_*` covers ids present in both
  graphs whose tracked fields differ — node `kind`/`label`/`params`/`state`/
  `block_reason`/`metadata`, edge `from`/`to`/`type`/`metadata`, gate
  `edge_id`/`status`/`metadata` — compared with `identical()` on in-memory
  values; `graph$version` is ignored. The new `include_values = TRUE` adds a
  `values` element carrying `list(before = ..., after = ...)` per changed
  field. `changed_*` ids are ordered by the named-map insertion order of
  `after`.
- **Tabular accessors:** added `dagri_nodes_df()`, `dagri_edges_df()`, and
  `dagri_gates_df()` — base `data.frame` views of the stored node, edge, and
  gate records for reporting consumers. Rows follow graph insertion order,
  `params`/`metadata` stay list-columns holding the stored lists verbatim,
  ids live in the `id` column instead of row names, and empty graphs yield
  zero-row frames with identical column names and classes.
- **Customization hooks for `dagri_mermaid()`:** the renderer gains
  `gate_label`, `include_resolved_gates`, `class_defs`, and `header`
  arguments without changing its pure graph-to-text contract. With every
  argument at its default the output is byte-for-byte identical to before.
- **`gate_label` callback:** `function(gate, edge) -> string` supplies
  per-gate edge annotation labels (e.g. "pending review", reviewer names)
  instead of the default `gate: <id>` text; `NULL`/`NA` returns fall back
  to the default, and non-character or multi-element returns are coerced
  exactly like `node_label` returns.
- **`include_resolved_gates`:** opt-in flag that also annotates resolved
  gates on their edge, each suffixed with `" (resolved)"`, in gate
  insertion order; pending gates render exactly as before.
- **`class_defs` / `header` styling injection:** `class_defs` adds Mermaid
  `classDef` statements after the `flowchart` line, and `header` adds
  preamble lines (e.g. `%%{init: ...}%%` directives) before it. `class_defs`
  go through the same sanitizer as node labels and gate annotations: double
  quotes become single quotes, brackets, braces, parentheses, pipes, angle
  brackets and line breaks become spaces, runs of spaces and tabs become
  one space, and leading and trailing whitespace is trimmed. Header lines
  are trusted caller input: control characters become spaces, runs of spaces
  and tabs become one space, and the ends are trimmed, nothing else. Node
  ids, edge endpoints and `direction` are emitted verbatim, and so is a
  class name that `node_class` returns.
- **Per-node status view in `dagri_plan()`:** plans now carry a `node_status`
  field — a named list keyed by node id covering the target closure in
  `topo_order` order — so consumers no longer re-derive why each node is
  blocked. Each entry exposes the derived structural `state` and
  `block_reason`, the `pending_gates` on the node's inbound edges (edge
  insertion order, then gate insertion order), the propagated
  `external_hold` reason (`NULL` when none), the direct `upstream_blockers`
  (unique, incoming-edge insertion order), and final structural `eligible`.
  `eligible` is identical to membership in `plan$eligible` and deliberately
  stays `TRUE` under external holds, preserving the existing separation
  between structural eligibility and external blocking. Existing plan fields
  are unchanged; the new field is additive.

## Performance

- **Internal adjacency index:** traversals, topological ordering, state
  recomputation and planning build one adjacency index per call, in one pass
  over the edges, and look up each node's neighbours and incoming edges in
  it. Before, every lookup scanned all edges. One more pass, over the gates,
  groups pending gates by edge, so per-edge gate lookups no longer scan all
  gates. `dagri_plan()` builds the index once and shares it among the steps
  that look up neighbours; it still scans the gates to fill
  `plan$pending_gates`. The index is internal; public functions build it
  themselves.
  `dagri_upstream()` and `dagri_downstream()` still scan the edge list.

## Documentation

- **Serialization vignette:** added "Serialization and the Consumer Boundary"
  (`vignette("serialization-boundary")`): the graph snapshot shape, a canonical
  jsonlite writer/reader recipe (`auto_unbox`/`null`/`digits` options,
  `simplifyVector = FALSE`, null normalization, key/id consistency check),
  the recommended safe id pattern, the exact no-code boundary of
  `dagri_validate_graph()` on load (including the RDS path), and a direct
  statement that `param_schema` is declarative and not enforced against node
  params. `jsonlite` added to `Suggests`; the recipe is covered by tests.
- **Vignette: branching and comparing graphs:** the getting-started vignette
  now demonstrates forking a graph into two alternatives with the public
  mutators and reading `dagri_graph_diff()` results — structural
  added/removed id vectors as well as value-aware `include_values = TRUE`
  output with per-field before/after values for changed nodes, edges, and
  gates.
- **Vignette: Mermaid rendering:** the getting-started vignette now renders
  its running example with `dagri_mermaid()` — the default output plus a
  customized one exercising `gate_label` and `class_defs`, and a
  `class.output = "mermaid"` chunk that documentation sites loading
  mermaid.js render as a live diagram while plain R documentation keeps the
  readable flowchart text.
- **`dagri_update_node()` replace semantics documented:** `params`/`metadata`
  **replace** the existing fields outright (use `utils::modifyList()` to merge);
  the merge belongs in the consumer, not in this primitive.
- **Getting-started vignette:** added a Structural State Semantics section.
- **Decision record — generic execution layer:** documented that execution,
  caching, and artifact storage stay out of dagriculture (see
  `design/boundary-contract.md`).
- **Real package Title** in DESCRIPTION.
- **Complexity notes removed:** the help pages no longer claim O(V+E) for
  traversals, topological ordering, state recomputation and planning, or O(E)
  for `dagri_upstream()` and `dagri_downstream()`. The code does not meet
  those bounds: every call validates the graph first, and the validation and
  the traversals use `%in%`, `setdiff()` and lookups by name in named lists,
  each of which takes time proportional to the length of the vector or list
  it searches.

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
