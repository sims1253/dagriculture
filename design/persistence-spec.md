# Persistence Specification: `bayesgrove` / `dagriculture`

**Status:** Draft
**Date:** 2026-03-03

## Purpose

Define the serialization, schema, and wire-format rules for the greenfield
rewrite.

This document is subordinate to:

- [boundary-contract.md](./boundary-contract.md)
- [api-contracts.md](./api-contracts.md)

If the conceptual boundary or public API changes, this document must follow
them rather than silently preserving outdated storage shapes.

## Serialization Policy

- Persist only plain data.
- Do not persist executable closures.
- Do not persist class-dependent objects whose meaning depends on package load
  order.
- Every top-level document must include `schema_name` and `schema_version`.
- Readers must validate before exposing persisted content through public API
  objects.
- Partial writes must be detectable and treated as uncommitted.
- Committed writes must use write-to-temp plus atomic rename (or an equivalent
  atomic replace primitive) under the active write lock.
- Backward compatibility should be explicit and versioned.

## Allowed Persisted Values

Persisted metadata documents may contain:

- strings
- booleans
- integers / finite numbers
- `null`
- arrays
- objects with string keys

Large or backend-specific payloads may be stored as opaque artifact files, but
their metadata must still follow this spec.

Collection rule:

- keyed collections that are named maps in memory should be persisted as JSON
  objects keyed by id, not as arrays of records
- readers should hydrate those keyed JSON objects into named lists/maps without
  rebuilding names from record contents
- writers must emit object keys in stable lexical order so serialized JSON is
  reproducible for hashing and diffing

## Validation Order

Readers should validate in this order:

1. syntactic JSON / JSONL validity
2. `schema_name`
3. `schema_version`
4. required fields
5. field types
6. semantic invariants

## Null / Missingness Policy

- optional fields may be omitted when absent
- required fields that are intentionally empty should be emitted as `null`
- `NA` values from R must not leak through as ambiguous string or numeric
  sentinels
- when hydrating from R, typed `NA_*` values must be normalized before
  serialization:
  - omit the field if the field is optional
  - write `null` if the field is required-but-nullable
- non-finite numerics (`Inf`, `-Inf`, `NaN`) must not be serialized

## Canonical Enums

### Node State

- `new`
- `ready`
- `blocked`

### Node Block Reason

- `none`
- `gate`
- `upstream_blocked`

### Gate Status

- `pending`
- `resolved`

### Decision Status

- `active`
- `superseded`

### Decision Kind

- `gate_answer`
- `note`

### Job Status

- `queued`
- `running`
- `succeeded`
- `failed`
- `cancelled`
- `orphaned`

### Run Status

- `queued`
- `running`
- `succeeded`
- `failed`
- `cancelled`
- `blocked`
- `partial`

### Execution Mode

- `sync`
- `async`

### Workflow State

- `open`
- `idle`
- `running`
- `paused`
- `blocked`
- `degraded`

### Registry Compatibility

- `exact`
- `compatible`
- `upgraded`

### Health

- `ok`
- `warning`
- `error`

### Artifact Index Status

- `active`
- `superseded`

### Bundle Data Policy

- `omit`
- `freeze_source`
- `copy`

Semantics:

- `omit`: do not bundle source bytes
- `freeze_source`: preserve source references, but pin them to resolved
  immutable source bindings/digests
- `copy`: include source bytes in the bundle

## Canonical Formats

### Timestamp

- UTC only
- RFC 3339 / ISO 8601 extended form
- canonical writer form uses trailing `Z`

Example:

- `2026-03-03T14:05:09Z`

### Artifact Reference

- `cas:<algorithm>:<digest>`

Example:

- `cas:sha256:0123abcd...`

### Source Reference

- `source:<source_id>`

Example:

- `source:observations_v1`

### Document References

- project-local refs are stored as relative paths from project root
- bundle-local refs are stored as relative paths from bundle root
- refs must not escape the root via parent traversal

## Core Persisted Documents

### 1. Project Metadata

Schema:

- `schema_name = "bg_project_metadata"`
- `schema_version = 1`

Required fields:

- `project_id`
- `project_name`
- `created_at`
- `updated_at`
- `graph_ref`
- `decision_log_ref`
- `job_log_ref`
- `config_ref`
- `state`

Optional fields:

- `last_run_id`
- `lock_ref`
- `gate_specs_ref`
- `reference_store_ref`
- `notes`

If `lock_ref` is present, it should point to a lock document with:

- `schema_name = "bg_project_lock"`
- `schema_version = 1`
- `project_id`
- `lock_token`
- `pid` (nullable)
- `host`
- `acquired_at`
- `lease_expires_at`
- `active_run_id` (nullable)
- `mode` (`write`)

Recovery rule:

- `bg_recover()` may break a lock only when the owning process is confirmed
  gone, or when the lease has expired and policy permits takeover
- on remote/shared filesystems, lease expiry is the authoritative stale-lock
  signal unless the implementation has a stronger filesystem-local guarantee
- on host-local filesystems, lease expiry should be treated as advisory for
  long blocking R sessions; implementations should prefer a reliable
  owner-liveness check before automatic takeover
- if automatic lease renewal is implemented, it should refresh
  `lease_expires_at`; otherwise stale-lock takeover should default to explicit
  user confirmation
- when `bg_recover()` successfully breaks a stale lock, it must reconcile the
  job log by appending a new terminal entry with `status = "orphaned"` for any
  currently `queued` or `running` job attributable to the broken writer
  session:
  - prefer jobs under `active_run_id` when the lock recorded one
  - otherwise conservatively orphan all currently non-terminal jobs for the
    project

### 2. Graph Snapshot

Schema:

- `schema_name = "dagri_graph_snapshot"`
- `schema_version = 1`

Required fields:

- `graph_id`
- `version`
- `registry`
- `nodes`
- `edges`
- `gates`
- `metadata`

The embedded `registry` is the declarative `dagriculture` registry. It must be
serializable plain data and is authoritative for structural validation.

Representation rule:

- `registry`, `nodes`, `edges`, and `gates` are persisted as JSON objects keyed
  by id/name, matching their in-memory named-map shape
- writers should commit graph snapshots via write-to-temp plus atomic rename
  under the active write lock rather than in-place overwrite

### 3. Gate Specification Store

Schema:

- `schema_name = "bg_gate_specs"`
- `schema_version = 1`

Required fields:

- `project_id`
- `gates`

Each gate spec record contains:

- `id`
- `edge_id`
- `prompt`
- `options`
- `refs`
- `created_at`
- `metadata`

### 4. Decision Log

Schema:

- `schema_name = "bg_decision_entry"`
- `schema_version = 1`

Storage:

- JSONL
- one decision entry per line
- readers materialize current decision state by reducing to the last valid entry
  for each `decision_id`
- `bg_gc()` may compact this log by rewriting only the latest surviving entry
  per `decision_id`

Required fields per entry:

- `decision_id`
- `project_id`
- `scope`
- `kind`
- `prompt`
- `choice`
- `rationale`
- `refs`
- `evidence`
- `status`
- `created_at`
- `supersedes`
- `metadata`

### 5. Job Log

Schema:

- `schema_name = "bg_job_entry"`
- `schema_version = 1`

Storage:

- JSONL
- one job entry per line
- readers materialize current job state by reducing to the last valid entry for
  each `job_id`
- `bg_gc()` may compact this log by rewriting only the latest surviving entry
  per `job_id`
- crash recovery appends new terminal entries (for example `status =
  "orphaned"`) rather than editing historical lines in place

Required fields per entry:

- `job_id`
- `run_id`
- `project_id`
- `node_id`
- `status`
- `submitted_at`
- `started_at`
- `finished_at`
- `progress`
- `result_ref`
- `error`
- `backend`
- `metadata`

Canonical zero-progress snapshot for queued jobs:

- `{"stage":"queued","percent":0}`

This shape is explicitly valid for `status = "queued"` and should be treated as
the canonical pre-start progress record.

For indeterminate progress, `percent` may be `null` when the backend can report
stage but not a bounded completion fraction.

### 6. Config

Schema:

- `schema_name = "bg_config"`
- `schema_version = 1`

Purpose:

- execution configuration
- source bindings
- persistence options
- backend defaults

### 6a. Reference Store

Schema:

- `schema_name = "bg_reference_store"`
- `schema_version = 1`

Required fields:

- `project_id`
- `entries`

Each entry is keyed by reference id and may contain:

- `id`
- `type`
- `title`
- `authors`
- `issued_at`
- `locator`
- `metadata`

This schema is optional and may remain absent in alpha projects; if
`reference_store_ref` is present, it must point to a document that satisfies
this schema.

### 7. Artifact Manifest

Schema:

- `schema_name = "bg_artifact_manifest"`
- `schema_version = 1`

Required fields:

- `artifact_ref`
- `hash`
- `kind`
- `created_at`
- `size_bytes`
- `node_id`
- `fingerprint`
- `metadata`

### 8. Artifact Index

Schema:

- `schema_name = "bg_artifact_index"`
- `schema_version = 1`

Required fields:

- `project_id`
- `entries`

Each entry should identify the current active result for a `(node_id, fingerprint)`
pair and record whether it is `active` or `superseded`.

Canonical shape:

- `entries` is a JSON object keyed first by `node_id`, then by `fingerprint`
- the leaf value is an index record for that `(node_id, fingerprint)` pair

### 9. Bundle Manifest

Schema:

- `schema_name = "bg_bundle_manifest"`
- `schema_version = 1`

Required fields:

- `bundle_id`
- `project_id`
- `created_at`
- `graph_ref`
- `decision_log_ref`
- `artifact_index_ref`
- `data_policy`
- `include_fits`

Optional fields:

- `reference_store_ref`
- `report_ref`
- `notes`

### 10. Optional Health Summary

Schema:

- `schema_name = "bg_health_summary"`
- `schema_version = 1`

Required fields:

- `project_id`
- `checked_at`
- `health`
- `issues`

## Canonical Persisted Examples

### Project Metadata

```json
{
  "schema_name": "bg_project_metadata",
  "schema_version": 1,
  "project_id": "proj_01JNB5J2X4D6Q5Q8Y7K3M1P9TA",
  "project_name": "Pilot Prior Sensitivity",
  "created_at": "2026-03-03T14:05:09Z",
  "updated_at": "2026-03-03T14:42:11Z",
  "graph_ref": ".bayesgrove/graph/current.json",
  "gate_specs_ref": ".bayesgrove/gates/current.json",
  "decision_log_ref": ".bayesgrove/logs/decisions.jsonl",
  "job_log_ref": ".bayesgrove/logs/jobs.jsonl",
  "config_ref": ".bayesgrove/config.json",
  "state": "idle",
  "last_run_id": "run_01JNB5R4J5ATW0VVBEM6D3J8TW"
}
```

### Graph Snapshot

```json
{
  "schema_name": "dagri_graph_snapshot",
  "schema_version": 1,
  "graph_id": "graph_01JNB5R8KQ3MF2B57CBK6K4Y2J",
  "version": 7,
  "registry": {
    "data_source": {
      "name": "data_source",
      "input_contract": null,
      "output_type": "data.frame",
      "param_schema": {
        "required": [
          "source_ref"
        ]
      },
      "metadata": {}
    }
  },
  "nodes": {
    "node_data": {
      "id": "node_data",
      "kind": "data_source",
      "label": "Observed data",
      "params": {
        "source_ref": "source:observations_v1"
      },
      "state": "ready",
      "block_reason": "none",
      "metadata": {}
    }
  },
  "edges": {},
  "gates": {},
  "metadata": {}
}
```

### Project Lock

```json
{
  "schema_name": "bg_project_lock",
  "schema_version": 1,
  "project_id": "proj_01JNB5J2X4D6Q5Q8Y7K3M1P9TA",
  "lock_token": "lock_01JNB66BX9V4W7GG1D3H4P6R0M",
  "pid": 24817,
  "host": "analysis-box",
  "acquired_at": "2026-03-03T14:40:00Z",
  "lease_expires_at": "2026-03-03T14:45:00Z",
  "active_run_id": "run_01JNB5R4J5ATW0VVBEM6D3J8TW",
  "mode": "write"
}
```

### Gate Specification Store

```json
{
  "schema_name": "bg_gate_specs",
  "schema_version": 1,
  "project_id": "proj_01JNB5J2X4D6Q5Q8Y7K3M1P9TA",
  "gates": {
    "gate_prior_review": {
      "id": "gate_prior_review",
      "edge_id": "edge_data_fit",
      "prompt": "Proceed with the baseline weakly informative prior?",
      "options": [
        "yes",
        "no"
      ],
      "refs": [],
      "created_at": "2026-03-03T14:43:00Z",
      "metadata": {}
    }
  }
}
```

### Reference Store

```json
{
  "schema_name": "bg_reference_store",
  "schema_version": 1,
  "project_id": "proj_01JNB5J2X4D6Q5Q8Y7K3M1P9TA",
  "entries": {
    "ref_kruschke_2015": {
      "id": "ref_kruschke_2015",
      "type": "book",
      "title": "Doing Bayesian Data Analysis",
      "authors": [
        "John K. Kruschke"
      ],
      "issued_at": "2015-01-01",
      "locator": "isbn:9780124058880",
      "metadata": {}
    }
  }
}
```

### Artifact Index

```json
{
  "schema_name": "bg_artifact_index",
  "schema_version": 1,
  "project_id": "proj_01JNB5J2X4D6Q5Q8Y7K3M1P9TA",
  "entries": {
    "node_fit": {
      "sha256:7c2a91de": {
        "artifact_ref": "cas:sha256:abcdef1234567890",
        "status": "active",
        "created_at": "2026-03-03T14:49:33Z",
        "run_id": "run_01JNB5R4J5ATW0VVBEM6D3J8TW",
        "metadata": {}
      }
    }
  }
}
```

### Job Entry

```json
{
  "schema_name": "bg_job_entry",
  "schema_version": 1,
  "job_id": "job_01JNB5T49W3QDS0X1EQFQYKBMQ",
  "run_id": "run_01JNB5R4J5ATW0VVBEM6D3J8TW",
  "project_id": "proj_01JNB5J2X4D6Q5Q8Y7K3M1P9TA",
  "node_id": "node_fit",
  "status": "running",
  "submitted_at": "2026-03-03T14:45:00Z",
  "started_at": "2026-03-03T14:45:01Z",
  "finished_at": null,
  "progress": {
    "stage": "sampling",
    "percent": 42
  },
  "result_ref": null,
  "error": null,
  "backend": "local",
  "metadata": {}
}
```

## Hard Prohibitions

- Do not emit multiple canonical shapes for the same document type.
- Do not persist executable functions in project metadata.
- Do not use absolute machine-specific paths in portable bundle manifests.
- Do not encode enums as integers.
- Do not persist non-finite numeric values in JSON metadata documents.
