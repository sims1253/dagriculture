# Boundary Contract: `dagriculture`, `bayesgrove`, and `glade`

**Status:** Draft
**Date:** 2026-03-03

## Purpose

Define the conceptual boundary for the greenfield rewrite:

1. `dagriculture`: a pure, value-oriented graph library
2. `bayesgrove`: a project-oriented workflow orchestrator built on top of `dagriculture`
3. `glade`: a GUI for `bayesgrove`

This document is about ownership and behavioral boundaries, not storage layout.
It focuses primarily on the `dagriculture` / `bayesgrove` contract; `glade`
should consume orchestrator-facing views rather than redefining graph
semantics.
Persistence details belong in
[persistence-spec.md](./persistence-spec.md).
Concrete public signatures belong in
[api-contracts.md](./api-contracts.md).

## Core Decision

The split is:

- `dagriculture` owns graph structure, graph validity, structural readiness, and
  generic blockers on edges.
- `bayesgrove` owns projects, execution, persistence, artifact/result
  lifecycle, invalidation, recovery, exports, and domain semantics.

The rewrite should preserve that split even if implementation details change.

## Design Constraints

- `dagriculture` is value-oriented: no globals, no file I/O, no async workers, no
  project handles.
- `dagriculture` must remain serializable as plain data.
- `bayesgrove` may be stateful and persistent, but the core API should use
  explicit handles rather than an implicit global current project.
- The alpha should optimize for four user stories:
  - branching and backtracking
  - explicit decision capture
  - background execution with observable progress
  - reproducible handoff

## What `dagriculture` Owns

`dagriculture` owns:

- node, edge, and gate topology
- acyclicity and structural validity
- structural node state:
  - `new`
  - `ready`
  - `blocked`
- structural block reasons:
  - `none`
  - `gate`
  - `upstream_blocked`
- structural planning:
  - target closure
  - topological order
  - structurally eligible nodes
  - blocked nodes
  - terminal targets within a target closure
  - unresolved gates within a target closure
  - optional opaque external-hold overlays in planning output

`dagriculture` does not own freshness. It does not know whether a previously computed
result is reusable, stale, superseded, missing, or cached.

In particular:

- `upstream_blocked` is structural only: it means an upstream node is
  structurally blocked
- planner-visible external holds are opaque overlays only: they may affect
  planning output, but they do not become node state or structural block
  reasons
- a fully executed workflow may still appear entirely `ready` in `dagriculture`
  because "completed" is a `bayesgrove` result-layer concept, not a graph state

## What `dagriculture` Must Not Own

`dagriculture` must not own:

- runtime execution state (`queued`, `running`, `succeeded`, `failed`, etc.)
- artifact manifests or CAS indexes
- result invalidation/freshness
- cache hit detection
- executors or backend plugins
- progress/heartbeat tracking
- jobs, runs, recovery journals
- reports, bundles, or handoff formats
- Bayesian semantics such as priors, fits, diagnostics, or citations

## What `bayesgrove` Owns

`bayesgrove` owns:

- project lifecycle
- persistence and locking
- runtime registries (workflow kinds, backends, extensions)
- node execution and orchestration
- artifact creation and lookup
- result invalidation
- background jobs and optional run grouping
- decision records
- gate semantic payloads (prompt, options, rationale context)
- exports and bundles
- maintenance, health checks, and recovery

## Gates Across The Boundary

The gate split is intentionally two-layered:

- `dagriculture` gate:
  - generic blocker attached to an edge
  - only `id`, `edge_id`, `status`, and structural metadata
- `bayesgrove` gate spec:
  - semantic payload keyed by `id`
  - prompt
  - options
  - optional attachments
  - analyst-facing context

This keeps the generic blocker primitive in `dagriculture` without leaking workflow
semantics into the graph library.

`bg_answer_gate()` is the bridge operation:

- it validates and records the semantic answer in `bayesgrove`
- it must also invoke `dagri_resolve_gate()` internally so the structural
  blocker is cleared in the graph before persistence completes

## Data-Flow Contract

This is the core orchestration model:

- edges carry topology and edge semantics, not values
- root input nodes resolve `source_ref` values against project configuration or
  a source registry before execution begins
- successful upstream nodes expose one active `artifact_ref`
- `bg_plan()` resolves upstream dependencies into ordered input bindings
- each input binding contains:
  - `edge_id`
  - `from_node_id`
  - `edge_type`
  - `artifact_ref`
- for alpha, upstream values are materialized eagerly before executor dispatch
- that eager materialization rule is an alpha transport choice, not a permanent
  executor-shape constraint; the executor contract should remain compatible with
  a future mode that passes `artifact_ref` or file-backed handles instead of
  fully materialized values for large artifacts
- executors receive upstream values in deterministic plan order
- successful execution updates artifact/result overlays, not structural graph
  state
- a structurally `ready` node may be skipped by `bayesgrove` when `bg_plan()`
  classifies it as a cache hit

That makes `dagriculture` structurally pure while still giving `bayesgrove` an explicit
execution contract.

## Fingerprint Contract

`bayesgrove` uses intent-based fingerprinting so `bg_plan()` can predict cache
status before any execution starts.

Rules:

- a node fingerprint is a deterministic hash of:
  - the node kind identity and compatible runtime implementation version
  - the node's normalized local parameters
  - the ordered edge/input contract presented to the executor
  - the fingerprints of all resolved upstream dependencies in deterministic
    input order
- downstream fingerprints must be derived from upstream fingerprints, not from
  newly materialized output bytes
- root/source nodes derive their fingerprint from the resolved immutable source
  binding (for example a pinned source digest or frozen source binding), not
  from a mutable path string alone
- if the source binding changes, that source-node fingerprint changes and the
  change cascades through downstream fingerprints
- `bg_plan()` computes predicted fingerprints across the target closure, then
  looks them up in the artifact index to classify `cache_hits` and
  `missing_results`

This keeps cache planning eager and deterministic without introducing runtime
execution state into `dagriculture`.

## Registry Contract

There are two related registries:

- embedded `dagriculture` registry:
  - persisted with the graph snapshot
  - declarative only
  - authoritative for structural validation
- runtime `bayesgrove` registries:
  - attached at `bg_open()`
  - may include executors, backends, and richer domain metadata
  - must be compatible with the persisted graph

`bg_open()` must fail loudly if a saved node kind cannot be interpreted by the
currently attached runtime registries and no explicit upgrader is available.
The default runtime compatibility policy should be:

- accept `compatible`
- accept `upgraded` when an explicit upgrader ran
- reject mismatches only when compatibility cannot be proven

## Handle Model

The primary `bayesgrove` contract is explicit handles:

- `bg_init()` and `bg_open()` return a `bg_handle`
- mutating `bg_*` functions update the supplied handle in place
- mutating functions return purpose-specific ids or records, not replacement
  handles
- `bg_snapshot()` returns an immutable, validated snapshot of current project
  state

`bg_handle` is intentionally reference-semantic:

- it is an S7 contract object over a private environment-backed mutable handle
- `bg_*` mutators update that backing environment in place
- callers should treat it as a live handle, not as a value object

Transactional rule:

- mutators must stage edits against a temporary working snapshot
- in practice, the staged snapshot is a new plain-data project/graph payload;
  the environment-backed handle updates its internal references only after a
  successful commit
- persistence and compare-and-swap validation must succeed before the backing
  environment is updated
- if the write or compare-and-swap check fails, the live handle remains at its
  last committed state and the call fails with a typed conflict/error

Interactive helpers may exist later, but they must remain convenience wrappers,
not the primary API.

## Concurrency Model

Alpha should be conservative:

- one writer per project
- multiple readonly handles may coexist
- writable handles require a lock before mutation
- mutating graph structure while jobs are running is not allowed unless the
  implementation explicitly isolates or cancels those jobs
- plans computed against one graph version must fail or be recomputed if the
  graph changes before submission

The lock must be recoverable after process death:

- lock state should include enough metadata to detect stale ownership
- on remote/shared filesystems, lease expiry is the authoritative stale-lock
  signal unless the implementation can prove a stronger host-local check
- on host-local filesystems, lease expiry alone is not a sufficient stale-lock
  signal for long blocking R calls; implementations should prefer an explicit
  owner-liveness check (for example a reliable host-local PID/session check)
  before reclaiming a lock automatically
- if alpha does not implement automatic lease heartbeats, stale locks should
  default to explicit user-driven recovery rather than best-effort process
  guessing
- `bg_recover(force = TRUE)` is the explicit manual override for breaking a
  stale lock after warning the caller about concurrent-writer risk
- `bg_recover()` may break a stale lock only after a valid policy check (for
  example: expired lease, or an implementation-specific owner-liveness check
  that is known to be reliable for the current filesystem/session model)

Persistence writes must also be atomic:

- the graph `version` counter is not itself a cross-process compare-and-swap
  primitive
- `bayesgrove` must pair version checks with an atomic persistence mechanism
  such as write-to-temp plus atomic rename inside the active write lock
- in-place overwrites must not be treated as a valid committed write path

## Failure Taxonomy

The orchestrator should reason explicitly about these failure classes:

- interrupted write
- orphaned job
- stale plan
- lock conflict
- missing artifact
- schema mismatch
- registry mismatch

Recovery policy should be defined against those failures, not against vague
"project corruption."

## Extension Surface

Extension APIs should exist, but they are not the analyst core:

- workflow kind registration
- backend registration
- custom exporters
- advanced maintenance tooling

These should be explicit package-author surfaces, not the default tutorial path.

## Suggested Alpha Surface

The analyst-facing alpha should stay narrow:

- project lifecycle:
  - `bg_init()`
  - `bg_open()`
  - `bg_close()`
  - `bg_snapshot()`
- graph editing:
  - `bg_add_node()`
  - `bg_connect()`
  - `bg_update_node()`
  - `bg_remove_node()`
  - `bg_branch()`
  - `bg_invalidate()`
- gate/decision workflow:
  - `bg_add_gate()`
  - `bg_answer_gate()`
  - `bg_reopen_gate()`
  - `bg_pending_gates()`
  - `bg_record_decision()`
  - `bg_decision()`
  - `bg_decisions()`
- orchestration:
  - `bg_plan()`
  - `bg_run()`
  - `bg_submit()`
  - `bg_wait()`
  - `bg_cancel()`
  - `bg_status()`
  - `bg_jobs()`
  - `bg_progress()`
- results:
  - `bg_result()`
  - `bg_result_meta()`
  - `bg_collect()`
- handoff and maintenance:
  - `bg_export_report()`
  - `bg_bundle()`
  - `bg_recover()`
  - `bg_health()`
  - `bg_gc()`
- analyst ergonomics:
  - pipe-friendly convenience wrappers may ship in alpha, but they are wrappers
    over the canonical low-level handle-and-id contract rather than a separate
    core execution model

Anything outside that set should justify itself against a concrete alpha story.

## Product Lessons From The Prototype

Keep:

- graph-centric branching and backtracking
- explicit decision records
- background execution with observable state
- reproducible handoff/bundling

Rework:

- avoid leaking plugin-author APIs into analyst workflows
- avoid hidden singleton project state
- keep direct result access first-class
- keep gate semantics separate from decision logs

Throw away:

- prototype-specific storage quirks
- API shapes that force users through manifests or bundle internals
- any assumption that the prototype surface must be source-compatible

## Current Default Decisions

The current draft resolves these previously open choices:

1. Keep structural node states in `dagriculture`.
2. Default runtime registry compatibility to `compatible`, with `upgraded`
   allowed when an explicit upgrader ran.
3. Keep alpha eager-only for input materialization.
4. Keep alpha branching to single-node cloning.
5. Keep the references module post-alpha.
6. Keep the current id-and-handle mutation return model for alpha.
7. Ship pipe-friendly convenience wrappers in alpha as ergonomic sugar, while
   keeping the low-level return contracts canonical.
8. Use a shared cross-package contract fixture suite to validate `dagriculture` /
   `bayesgrove` / `glade` boundary assumptions.

## Open Questions

1. Where should the shared cross-package contract fixture suite live
   (`bayesgrove` test helpers, a dedicated support package, or generated test
   fixtures checked into both repos)?
2. Should alpha implement renewable lock leases automatically, or require
   explicit/manual stale-lock recovery until heartbeat infrastructure exists?
