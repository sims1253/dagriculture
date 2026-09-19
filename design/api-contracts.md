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

## Metadata Policy

Metadata fields on every record type (`dagri_kind`, `dagri_registry`,
`dagri_graph`, `dagri_node`, `dagri_edge`, `dagri_gate`) are opaque
caller-owned extension data. Chosen policy (issue #14): support metadata
everywhere, at creation and through update mutators, rather than removing it —
consumers never need to mutate graph internals for a supported metadata
change.

Rules:

- Metadata must be a named list (empty allowed) of plain data. Named lists,
  vectors, and scalars are allowed at any nesting depth; unnamed nested lists
  (arrays) are allowed.
- `dagri_validate_metadata()` rejects non-lists (including data.frames),
  unnamed top-level entries, and — recursively — closures, environments,
  formulas, language objects, S4 objects, external pointers, and weak
  references. It runs at every metadata entry point: the
  three constructors and `dagri_add_node()` / `dagri_update_node()` /
  `dagri_add_edge()` / `dagri_update_edge()` / `dagri_add_gate()` /
  `dagri_update_gate()`.
- Update mutators use the same replace-not-merge semantics as
  `dagri_update_node()`: a non-`NULL` `metadata` **replaces** the field
  outright; merging partial metadata belongs in the caller.
- Metadata changes go through the same mutators and therefore bump `version`
  by exactly `1` per successful call, like every `dagri_*` mutation.
- `dagri_graph_diff()` surfaces metadata (and other tracked-field) edits in
  its output through `changed_nodes` / `changed_edges` / `changed_gates` and
  the optional `values` payload; see the Graph Boundary Helpers rules.
- Persistence: the `dagri_graph_snapshot` schema already carries all `metadata`
  fields. Writers that previously always emitted `{}` may now emit populated
  objects; this is backward compatible for readers that treat metadata as
  opaque.

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
- `metadata`: named plain-data list (see [Metadata Policy](#metadata-policy))

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
- `metadata`: named plain-data list (see [Metadata Policy](#metadata-policy))

#### `dagri_kind`

Fields:

- `name`: scalar string
- `input_contract`: `NULL` or named list
- `output_type`: `NULL` or scalar string
- `param_schema`: `NULL` or named list
- `metadata`: named plain-data list (see [Metadata Policy](#metadata-policy))

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
- `metadata`: named plain-data list (see [Metadata Policy](#metadata-policy))

Rules:

- `upstream_blocked` means an upstream node is structurally blocked

#### `dagri_edge`

Fields:

- `id`: scalar string
- `from`: scalar string
- `to`: scalar string
- `type`: scalar string
- `metadata`: named plain-data list (see [Metadata Policy](#metadata-policy))

#### `dagri_gate`

Fields:

- `id`: scalar string
- `edge_id`: scalar string
- `status`: `pending` or `resolved`
- `metadata`: named plain-data list (see [Metadata Policy](#metadata-policy))

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
- `node_status`: named list keyed by node id, covering exactly `targets`
  and ordered by `topo_order`. Each entry is a named list with:
  - `state`: scalar string — the derived structural state after the plan's
    internal recompute (`ready` or `blocked`)
  - `block_reason`: scalar string — the structural block reason (`none`,
    `gate`, or `upstream_blocked`)
  - `pending_gates`: character vector of pending gate ids attached to the
    node's inbound edges; deterministic order — edge insertion order, then
    gate insertion order within each edge; `character(0)` when none
  - `external_hold`: `NULL` when the node is not externally blocked;
    otherwise the scalar propagated hold reason (the same value
    `external_blocked[[id]]` carries after propagation)
  - `upstream_blockers`: character vector of direct upstream neighbor ids
    (incoming-edge sources) whose derived state is not `ready`; unique, in
    incoming-edge insertion order; `character(0)` when none
  - `eligible`: scalar logical — structural eligibility, identical to
    membership in `plan$eligible`. Deliberately remains `TRUE` when the node
    is externally held: structural eligibility and external blocking are
    separate axes, so a node may appear in both `eligible` and
    `external_blocked` (and carry `eligible = TRUE` with a non-`NULL`
    `external_hold`)

## `dagriculture` Public API

### Constructors

```r
dagri_kind(name, input_contract = NULL, output_type = NULL, param_schema = NULL,
           metadata = list())
dagri_registry(..., metadata = list())
dagri_graph(registry, metadata = list())
```

### Graph Editing

```r
dagri_add_node(graph, id, kind, label = NULL, params = list(), metadata = list())
dagri_update_node(graph, node_id, label = NULL, params = NULL, metadata = NULL)
dagri_remove_node(graph, node_id)

dagri_add_edge(graph, from, to, type = "data", id = NULL, metadata = list())
dagri_update_edge(graph, edge_id, type = NULL, metadata = NULL)
dagri_remove_edge(graph, edge_id)

dagri_add_gate(graph, edge_id, id = NULL, metadata = list())
dagri_update_gate(graph, gate_id, metadata = NULL)
dagri_resolve_gate(graph, id)
dagri_reopen_gate(graph, id)
dagri_remove_gate(graph, id)
```

Rules:

- `dagri_update_edge()` and `dagri_update_gate()` mirror `dagri_update_node()`:
  non-`NULL` fields **replace** the existing values (never merge), `NULL`
  leaves a field untouched, and every successful call bumps `version` by
  exactly `1` and returns a new graph.
- `dagri_update_edge()` cannot rewire `from`/`to` (remove and re-add the edge)
  and `dagri_update_gate()` does not touch `status` (`dagri_resolve_gate()` /
  `dagri_reopen_gate()` own the status lifecycle).
- `metadata` arguments at every entry point must satisfy the
  [Metadata Policy](#metadata-policy).

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
dagri_graph_diff(before, after, include_values = FALSE)
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
- `dagri_graph_diff()` is a pure diff with no workflow semantics. The result
  is a named list in this order: `added_nodes`, `removed_nodes`,
  `added_edges`, `removed_edges`, `added_gates`, `removed_gates`,
  `changed_nodes`, `changed_edges`, `changed_gates` — all character vectors.
  The first four keep the exact structural-only semantics (plain `setdiff()`
  over `names(graph$nodes)` and `dagri_edge_ids()`), so existing consumers are
  unaffected; gates follow the same setdiff pattern keyed by
  `names(graph$gates)`.
- `changed_nodes` / `changed_edges` / `changed_gates` list ids present in both
  graphs (by key) where any tracked field differs: node `kind`, `label`,
  `params`, `state`, `block_reason`, `metadata`; edge `from`, `to`, `type`,
  `metadata`; gate `edge_id`, `status`, `metadata`. Fields are compared with
  `identical()` on the stored in-memory values; `graph$version` is ignored
  (derived state, not content). Ordering is deterministic: changed ids appear
  in the named-map insertion order of `after`.
- With `include_values = TRUE` the result additionally carries `values`: a
  named list with `nodes`, `edges`, and `gates` elements, each a named list
  keyed by the changed ids (same ids and order as `changed_*`), each entry a
  named list of only the differing fields, each field
  `list(before = <value>, after = <value>)`. Ids that were only added or
  removed do not appear in `values`. With the default `include_values =
  FALSE` the `values` element is absent.
- Because comparison is `identical()`-based on in-memory values, graphs that
  serialize identically can still diff when their in-memory shapes differ
  (for example `NULL` vs `""`). Callers diffing JSON-round-tripped graphs
  should normalize values first; see the serialization rules in
  [persistence-spec.md](./persistence-spec.md).

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
dagri_mermaid(
  graph,
  node_label = NULL,
  node_class = NULL,
  direction = "TD",
  gate_label = NULL,
  include_resolved_gates = FALSE,
  class_defs = character(),
  header = character()
)
```

Rules:

- Pure graph-to-text renderer: emits a Mermaid flowchart block as a single
  length-1 character scalar with embedded newlines, zero new dependencies, no
  I/O. Validates the graph once at entry via `dagri_validate_graph()`.
- `node_label` and `node_class` are optional `(node) -> string` injection
  functions; defaults use `node$label %||% node$id` and `node$state %||%
  NA_character_` (the `class` line is skipped when the class is `NA`/empty).
- `gate_label` is an optional `(gate, edge) -> string` injection function
  receiving the full gate record (`id`, `edge_id`, `status`, `metadata`) and
  the full edge record. A `NULL` or scalar-`NA` return falls back to the
  default `gate: <id>` label; non-character returns are coerced and
  multi-element returns become `""`, mirroring the `node_label` contract.
- Pending gates are rendered as edge annotations: an edge carrying one or more
  gates with `status == "pending"` is emitted as
  `  <from> -- "gate: g1, g2" --> <to>`; with the default
  `include_resolved_gates = FALSE`, resolved gates produce no annotation.
  With `include_resolved_gates = TRUE`, resolved gates join the annotation in
  the same gate insertion order, each suffixed with the renderer-owned
  constant `" (resolved)"` (appended after sanitization so it survives).
- `class_defs` (character vector, default `character()`) holds Mermaid
  `classDef` statements; each element is sanitized and emitted on its own
  line after the `flowchart` line and before the node lines, in given order.
- `header` (character vector, default `character()`) holds raw Mermaid
  preamble lines (e.g. `%%{init: ...}%%` directives) emitted verbatim before
  the `flowchart` line. These are the deliberate exception to sanitization —
  only control characters (CR/LF/...) are stripped and whitespace collapsed —
  because the full sanitizer would destroy legitimate directives. `header`
  lines are trusted caller input; everything derived from graph data stays
  sanitized.
- Labels, gate annotation text, and `class_defs` lines are sanitized
  (`"` -> `'`; `[](){}|<>` and newlines -> space) because Mermaid breaks on
  those characters. Node ids are NOT sanitized — they are Mermaid node
  identifiers and must be Mermaid-safe (the editing API guarantees
  alphanumeric/underscore ids by convention).
- Node, edge, and gate ordering follows graph insertion order (multi-gate
  annotations join in gate insertion order), so output is deterministic and
  snapshot-friendly. With every argument at its default the output is
  byte-for-byte identical to the renderer without the customization hooks.
- consumers may layer label/class/gate injection (via `node_label`,
  `node_class`, `gate_label`) and styling (via `class_defs` / `header`) on
  top of this domain-generic renderer.

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
  eligible/blocked/terminal counts, the pending-gate count, and the
  `node_status` entry count. It returns `x` invisibly.
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

For a chain `node_data` (kind `data_source`) -> `node_fit` (kind `process`)
-> `node_diag` (kind `process`), where the inbound edge of `node_fit` carries
the pending gate `gate_prior_review`, produced by
`dagri_plan(graph, targets = c("node_fit", "node_diag"), external_holds = list(node_diag = "manual_review"))`
(`targets` carries the planned closure in request order — each requested
target followed by its ancestors — which is not necessarily `topo_order`):

```r
list(
  targets = c("node_fit", "node_data", "node_diag"),
  topo_order = c("node_data", "node_fit", "node_diag"),
  eligible = c("node_data"),
  blocked = list(node_fit = "gate", node_diag = "upstream_blocked"),
  external_blocked = list(node_diag = "manual_review"),
  terminal = c("node_diag"),
  pending_gates = c("gate_prior_review"),
  node_status = list(
    node_data = list(
      state = "ready",
      block_reason = "none",
      pending_gates = character(0),
      external_hold = NULL,
      upstream_blockers = character(0),
      eligible = TRUE
    ),
    node_fit = list(
      state = "blocked",
      block_reason = "gate",
      pending_gates = "gate_prior_review",
      external_hold = NULL,
      upstream_blockers = character(0),
      eligible = FALSE
    ),
    node_diag = list(
      state = "blocked",
      block_reason = "upstream_blocked",
      pending_gates = character(0),
      external_hold = "manual_review",
      upstream_blockers = "node_fit",
      eligible = FALSE
    )
  )
)
```

### `dagri_graph_diff`

With `include_values = TRUE` (a label edit, a gate resolve, and an added
node; the `values` element is absent with the default `include_values =
FALSE`):

```r
list(
  added_nodes = "diag",
  removed_nodes = character(),
  added_edges = character(),
  removed_edges = character(),
  added_gates = character(),
  removed_gates = character(),
  changed_nodes = "fit",
  changed_edges = character(),
  changed_gates = "gate_review",
  values = list(
    nodes = list(
      fit = list(label = list(before = "Fit", after = "Posterior fit"))
    ),
    edges = setNames(list(), character(0)),
    gates = list(
      gate_review = list(status = list(before = "pending", after = "resolved"))
    )
  )
)
```


