# API Contracts: `dagriculture`

**Status:** Draft
**Date:** 2026-03-03

## Purpose

Define the public API surface and contract rules for `dagriculture`, the pure
value-oriented graph library. Its primary consumer
[`bayesgrove`](https://github.com/sims1253/bayesgrove) layers caching,
execution, and Bayesian-workflow semantics over these primitives; bayesgrove's
own public contracts live in
[`../bayesgrove/architecture/api-contracts-bayesgrove.md`](../../bayesgrove/architecture/api-contracts-bayesgrove.md).

Conceptual package ownership belongs in
[boundary-contract.md](./boundary-contract.md).
Persistence and schema rules belong in
[persistence-spec.md](./persistence-spec.md).

## Contract Conventions

- Public functions must have stable, explicit return types.
- Query functions must not mutate persisted state.
- `dagri_*` functions are value-in, value-out.
- Contract violations should raise typed errors rather than silently coercing
  ambiguous input.
- For interactive conflict recovery, typed write-conflict errors may attach the
  staged attempted mutation payload in `details` so callers can retry without
  reconstructing intent.

## Identifier Contracts

- Ids are opaque strings.
- Ids are storage keys, not primary UX handles.
- High-level constructors should generate ids by default.
- User-facing tooling should prefer labels or aliases where possible.

## Collection Shape Contract

- named maps in memory correspond to JSON objects keyed by id/name on disk
- readers hydrate those keyed JSON objects directly into named lists/maps
- writers must not switch the same logical collection between array and object
  forms across schema versions without an explicit migration

## Object Model Policy

Use a hybrid model:

- plain lists are the canonical internal and serialized representation
- S7 is the strict public contract layer
- S3 is optional ergonomic sugar only

Rules:

- S7 objects should wrap or validate plain-data payloads
- disk formats must remain valid without S7 reconstruction
- worker protocols must not depend on class attributes
- core correctness must not depend on S3 dispatch

## Canonical Public Types

### `dagriculture`

#### `dagri_graph`

Fields:

- `registry`: `dagri_registry`
- `nodes`: named map of `dagri_node`
- `edges`: named map of `dagri_edge`
- `gates`: named map of `dagri_gate`
- `version`: scalar integer
- `metadata`: named list

Carries S3 class `c("dagri_graph", "list")` so
[print.dagri_graph()] dispatches; underneath it is a plain named list and
serializes identically to a bare list. A graph built by `dagri_graph()` (and
returned by every `dagri_*` mutator) carries the class; a hand-built bare list
does not, and the validator does not require it.

Invariants:

- graph is acyclic
- every node kind exists in `registry`
- every gate targets an existing edge
- `version` increases by exactly `1` in the returned graph for each successful
  `dagri_*` mutator call
- divergent copies may legitimately reach the same numeric version; only
  `bayesgrove` may use persisted compare-and-swap checks to detect conflicts

#### `dagri_registry`

Fields:

- `kinds`: named map of `dagri_kind`
- `metadata`: named list

#### `dagri_kind`

Fields:

- `name`: scalar string
- `input_contract`: `NULL` or named list
- `output_type`: `NULL` or scalar string
- `param_schema`: `NULL` or named list
- `metadata`: named list

Rules:

- `param_schema` must be declarative plain data
- no executable closures in the public contract

#### `dagri_node`

Fields:

- `id`: scalar string
- `kind`: scalar string
- `label`: `NULL` or scalar string
- `params`: named list
- `state`: `new`, `ready`, or `blocked`
- `block_reason`: `none`, `gate`, or `upstream_blocked`
- `metadata`: named list

Rules:

- `upstream_blocked` means an upstream node is structurally blocked

#### `dagri_edge`

Fields:

- `id`: scalar string
- `from`: scalar string
- `to`: scalar string
- `type`: scalar string
- `metadata`: named list

#### `dagri_gate`

Fields:

- `id`: scalar string
- `edge_id`: scalar string
- `status`: `pending` or `resolved`
- `metadata`: named list

#### `dagri_plan`

Carries S3 class `c("dagri_plan", "list")` so [print.dagri_plan()] dispatches;
underneath it is a plain named list and serializes identically to a bare list.

Fields:

- `targets`: character vector
- `topo_order`: character vector
- `eligible`: character vector
- `blocked`: named list mapping node id to block reason
- `external_blocked`: named list mapping node id to opaque external hold reason
- `terminal`: character vector
- `pending_gates`: character vector

## `dagriculture` Public API

### Constructors

```r
dagri_kind(name, input_contract = NULL, output_type = NULL, param_schema = NULL)
dagri_registry(...)
dagri_graph(registry)
```

### Graph Editing

```r
dagri_add_node(graph, id, kind, label = NULL, params = list(), metadata = list())
dagri_update_node(graph, node_id, label = NULL, params = NULL, metadata = NULL)
dagri_remove_node(graph, node_id)

dagri_add_edge(graph, from, to, type = "data", id = NULL, metadata = list())
dagri_remove_edge(graph, edge_id)

dagri_add_gate(graph, edge_id, id = NULL, metadata = list())
dagri_resolve_gate(graph, id)
dagri_reopen_gate(graph, id)
dagri_remove_gate(graph, id)
```

### Queries

```r
dagri_node(graph, node_id)
dagri_edge(graph, edge_id)
dagri_gate(graph, id)

dagri_nodes(graph)
dagri_edges(graph)
dagri_gates(graph)

dagri_upstream(graph, node_id)
dagri_downstream(graph, node_id)
dagri_ancestors(graph, node_id)
dagri_descendants(graph, node_id)
dagri_has_path(graph, from, to)
dagri_roots(graph)
dagri_leaves(graph)
dagri_topo_order(graph, subset = NULL)
```

### Graph Boundary Helpers

Graph-generic edge and diff operations: pure value-oriented topology helpers
that operate on edge objects and structural ids without workflow semantics.

```r
dagri_incoming_edges(graph, node_id)
dagri_outgoing_edges(graph, node_id)
dagri_order_edges(edges)
dagri_edge_ids(edges)
dagri_graph_diff(before, after)
```

Rules:

- `dagri_incoming_edges()` / `dagri_outgoing_edges()` return the edge objects
  (not just neighbor ids — `dagri_upstream()` / `dagri_downstream()` already
  cover neighbor ids), preserving container names.
- `dagri_order_edges()` is deterministic by embedded `edge$id`, used by
  consumers that need a stable fingerprint of multi-input nodes.
- `dagri_edge_ids()` prefers container names when all are non-empty, falling
  back to embedded `edge$id` fields so both the canonical named-map storage
  shape and unnamed edge lists remain diffable; it aborts with
  `dagri_error_invalid_argument` when neither yields complete ids.
- `dagri_graph_diff()` is a pure structural diff with no workflow semantics.

### State And Planning

```r
dagri_recompute_state(graph)
dagri_eligible(graph)
dagri_blocked(graph)
dagri_terminal(graph, targets = NULL)
dagri_plan(graph, targets = NULL, external_holds = list())
```

### Visualization

```r
dagri_mermaid(graph, node_label = NULL, node_class = NULL, direction = "TD")
```

Rules:

- Pure graph-to-text renderer: emits a Mermaid flowchart block as a single
  length-1 character scalar with embedded newlines, zero new dependencies, no
  I/O. Validates the graph once at entry via `dagri_validate_graph()`.
- `node_label` and `node_class` are optional `(node) -> string` injection
  functions; defaults use `node$label %||% node$id` and `node$state %||%
  NA_character_` (the `class` line is skipped when the class is `NA`/empty).
- Pending gates are rendered as edge annotations: an edge carrying one or more
  gates with `status == "pending"` is emitted as
  `  <from> -- "gate: g1, g2" --> <to>`; resolved gates produce no annotation.
- Labels and gate annotation text are sanitized (`"` -> `'`; `[](){}|<>` and
  newlines -> space) because Mermaid breaks on those characters. Node ids are
  NOT sanitized — they are Mermaid node identifiers and must be Mermaid-safe
  (the editing API guarantees alphanumeric/underscore ids by convention).
- consumers may layer label/class injection (via `node_label` / `node_class`)
  on top of this domain-generic renderer.

### Printing

```r
print.dagri_graph(x, ...)
print.dagri_plan(x, ...)
```

Rules:

- `dagri_graph` and `dagri_plan` carry S3 class `c("<type>", "list")` so these
  methods dispatch via `print()` / auto-printing at the console. Both remain
  plain named lists underneath: field access (`graph$nodes`, `plan$targets`),
  `$`/`[[` indexing, and JSON serialization are unchanged. Core correctness
  never depends on S3 dispatch (see Object Model Policy).
- `print.dagri_graph()` writes a concise multi-line summary to stdout via
  `cat()`: package name and version, node/edge/gate counts, `graph$version`,
  and the registry kind names (`(none)` when the registry is empty). It returns
  `x` invisibly.
- `print.dagri_plan()` writes target count, topological-order length, and the
  eligible/blocked/terminal counts plus the pending-gate count. It returns `x`
  invisibly.
- These are ergonomic sugar only. Graph-mutating functions
  (`dagri_add_node()`, `dagri_add_edge()`, `dagri_resolve_gate()`,
  `dagri_recompute_state()`, ...) preserve the `dagri_graph` class on the
  returned copy; `dagri_plan()` stamps the `dagri_plan` class on its return
  value. A hand-built bare list (e.g. a test fixture or a deserialized JSON
  payload without the class attribute) will simply print as a plain list; the
  validator does not require the class.

### Internal Adjacency Index

Traversal and planning internals build a per-call adjacency index via the
internal `dagri_adjacency()`. It is a single O(V+E) pass over `graph$edges`
yielding four named lists keyed by every node id (each initialized to
`character(0)`):

- `forward`: node id -> unique downstream neighbor ids (`edge$from -> edge$to`)
- `reverse`: node id -> unique upstream neighbor ids (`edge$to -> edge$from`)
- `forward_edges`: node id -> outgoing edge ids (not uniqued)
- `reverse_edges`: node id -> incoming edge ids (not uniqued)

Rules:

- The index is derived per call and is never stored on the graph. The pure
  value-oriented, immutable public API is unchanged.
- Public multi-node traversals (`dagri_ancestors()`, `dagri_descendants()`,
  `dagri_has_path()`, `dagri_topo_order()`, `dagri_recompute_state()`,
  `dagri_terminal()`, `dagri_external_blocked()`, `dagri_plan()`) validate the
  graph once at the boundary, build the index once, and thread it through their
  internal walks (`dagri_dfs()`, `dagri_neighbor_lookup()`).
- Single-node public queries (`dagri_upstream()`, `dagri_downstream()`) keep
  their linear scan and remain O(E); for one lookup the index build is not
  worth it. Their complexity is documented in their roxygen.
- `dagri_plan()` builds one shared index across `dagri_topo_order()` and
  `dagri_external_blocked()`, so a single plan call scans the edge list once.
  `dagri_target_closure()` and `dagri_pending_gates()` are internal helpers
  threading the same index; `dagri_plan()` exposes their results via its
  `targets` and `pending_gates` fields.

### `dagriculture` Behavioral Contract

- All mutating functions return a new `dagri_graph`.
- No `dagriculture` function performs I/O or depends on global state.
- `dagri_recompute_state()` returns a new `dagri_graph` with recomputed
  structural state only.
- `dagri_terminal()` is a graph-generic structural helper.
- `dagri_plan()` must not encode cache or execution assumptions.
- `external_holds` and `external_blocked` are opaque planning overlays only and
  must not mutate structural node state.
- A structurally `ready` node may still be skipped by `bayesgrove` when a
  reusable result exists; completion lives in artifact/result overlays, not in
  `dagri_node$state`.

## Typed Error Model

### `dagriculture` Errors

- `dagri_error_invalid_argument`
- `dagri_error_unknown_kind`
- `dagri_error_duplicate_id`
- `dagri_error_not_found`
- `dagri_error_cycle`
- `dagri_error_contract_violation`
- `dagri_error_not_eligible`
- `dagri_error_state_conflict`

### Error Payload Contract

Every public typed error should expose:

- `class`
- `message`
- `code`
- `details`

When relevant, `details` should include ids or paths that localize the failure.

## Canonical Public Return Shapes

### `dagri_plan`

```r
list(
  targets = c("node_fit", "node_diag"),
  topo_order = c("node_data", "node_fit", "node_diag"),
  eligible = character(),
  blocked = list(node_fit = "gate"),
  external_blocked = list(node_diag = "manual_review"),
  terminal = c("node_diag"),
  pending_gates = c("gate_prior_review")
)
```

