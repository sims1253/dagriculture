# Serialization and the Consumer Boundary

``` r

library(dagriculture)
library(jsonlite)
```

`dagriculture` graphs are plain named lists, so they serialize with any
JSON writer. In practice, though, every consumer that persists graphs
with jsonlite rediscovers the same handful of rules: which fields are
required, how `NULL` round-trips, why map keys and embedded ids both
exist, and what the package’s validation actually checks when a graph
comes back on load. This vignette records those rules once, as a
canonical writer and reader recipe you can copy.

The design backdrop is `design/persistence-spec.md` in the repository;
nothing here is new policy — it is that policy applied to jsonlite.

## The graph snapshot shape

A graph is a named list with five fields the entry-point validation
requires (`registry`, `nodes`, `edges`, `gates`, `version`) plus the
graph-level `metadata` that every record type carries. Starred fields
are nullable — they hold R `NULL` when absent:

- **graph**: `registry`, `nodes`, `edges`, `gates`, `version`,
  `metadata`
- **registry**: `kinds`, `metadata`
- **kind**: `name`, `input_contract`*, `output_type`*, `param_schema`\*,
  `metadata`
- **node**: `id`, `kind`, `label`\*, `params`, `state`, `block_reason`,
  `metadata`
- **edge**: `id`, `from`, `to`, `type`, `metadata`
- **gate**: `id`, `edge_id`, `status`, `metadata`

Three shape details matter for serialization:

- **`registry`, `nodes`, `edges`, and `gates` are named maps keyed by
  id** (kinds by kind name), not arrays of records. Empty maps are
  *named, empty lists* — `setNames(list(), character(0))` — and
  serialize as [`{}`](https://rdrr.io/r/base/Paren.html), not `[]`.
- **Nullable fields hold R `NULL`** when absent, and must come back as R
  `NULL` after a round trip, not as empty lists.
- **`metadata` is opaque caller-owned plain data** on every record: a
  named list whose values contain no closures, environments, formulas,
  language objects, S4 objects, external pointers, or weak references,
  at any depth.

`state`/`block_reason`/`status` are plain strings with fixed enums
(`new`/`ready`/`blocked`, `none`/`gate`/`upstream_blocked`,
`pending`/`resolved`); `version` is a single R integer that counts
edits.

``` r

reg <- dagri_registry(
  dagri_kind("source", output_type = "data.frame"),
  dagri_kind("fit", param_schema = list(required = c("model")))
)

g <- dagri_graph(reg, metadata = list(project = "pilot")) |>
  dagri_add_node("raw", "source", label = "Raw Data") |>
  dagri_add_node("m1", "fit", params = list(model = "baseline")) |>
  dagri_add_edge("raw", "m1", id = "e1") |>
  dagri_add_gate("e1", id = "g1")

names(g)
#> [1] "registry" "nodes"    "edges"    "gates"    "version"  "metadata"
names(g$nodes)
#> [1] "raw" "m1"
g$nodes$m1$label           # contractually nullable -> NULL
#> NULL
g$registry$kinds$source$param_schema  # also nullable -> NULL
#> NULL
```

Note that `dagriculture` itself does not add
`schema_name`/`schema_version` wrapper fields. If you persist snapshots
under the persistence spec, wrap the graph yourself and unwrap before
hydrating:

``` r

snapshot <- c(
  list(
    schema_name = "dagri_graph_snapshot",
    schema_version = 1,
    graph_id = "graph_pilot"
  ),
  g
)

names(snapshot)
#> [1] "schema_name"    "schema_version" "graph_id"       "registry"      
#> [5] "nodes"          "edges"          "gates"          "version"       
#> [9] "metadata"
```

The wrapper supplies exactly the three fields the in-memory graph lacks,
so the snapshot carries the spec’s full required list (`graph_id`,
`version`, `registry`, `nodes`, `edges`, `gates`, `metadata`).
`graph_id` is required by the snapshot spec while the in-memory graph
does not carry one, so pick a stable caller-chosen id at the wrap site
and reuse it across rewrites of the same graph. The rest of the recipe
round-trips the wrapped document: the writer below serializes
`snapshot`, and the reader unwraps it back into a graph before
hydrating.

## Writing: one canonical call

``` r

# The four named maps are keyed collections: emit their records in
# radix-sorted key order so the bytes do not depend on insertion order.
# Unnamed arrays are passed through untouched.
canonical_order <- function(x) {
  x$registry$kinds <-
    x$registry$kinds[sort(names(x$registry$kinds), method = "radix")]
  x$nodes <- x$nodes[sort(names(x$nodes), method = "radix")]
  x$edges <- x$edges[sort(names(x$edges), method = "radix")]
  x$gates <- x$gates[sort(names(x$gates), method = "radix")]
  x
}

write_graph_json <- function(snapshot, file = NULL, pretty = FALSE) {
  txt <- toJSON(
    canonical_order(snapshot),
    auto_unbox = TRUE,
    null = "null",
    digits = NA,
    pretty = pretty
  )
  if (is.null(file)) {
    txt
  } else {
    # Commit atomically: write a sibling temp file, replace only on success.
    tmp <- tempfile(tmpdir = dirname(file), fileext = ".json")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(txt, tmp)
    stopifnot(file.rename(tmp, file))
    invisible(file)
  }
}
```

When `file` is supplied the write commits atomically: the text goes to a
temporary file *in the destination’s own directory* first, and only a
fully written temp file is moved over the destination with
[`file.rename()`](https://rdrr.io/r/base/files.html) — a same-directory
rename is a single atomic directory-entry swap, so a failed or
interrupted write leaves the previous snapshot in place.

Each option is load-bearing; the jsonlite defaults break round trips:

- `auto_unbox = TRUE` writes length-1 atomic vectors as JSON scalars
  (`"state": "new"` instead of `["new"]`).
- `null = "null"` writes R `NULL` as JSON `null`. The jsonlite *default*
  (`null = "list"`) emits [`{}`](https://rdrr.io/r/base/Paren.html),
  which reads back as an empty list, not `NULL` — the classic broken
  round trip.
- `digits = NA` writes doubles at full precision. The default
  `digits = 4` silently truncates `1.23456789` to `1.2346`.

``` r

txt <- write_graph_json(snapshot)
cat(txt)
#> {"schema_name":"dagri_graph_snapshot","schema_version":1,"graph_id":"graph_pilot","registry":{"kinds":{"fit":{"name":"fit","input_contract":null,"output_type":null,"param_schema":{"required":"model"},"metadata":[]},"source":{"name":"source","input_contract":null,"output_type":"data.frame","param_schema":null,"metadata":[]}},"metadata":[]},"nodes":{"m1":{"id":"m1","kind":"fit","label":null,"params":{"model":"baseline"},"state":"new","block_reason":"none","metadata":[]},"raw":{"id":"raw","kind":"source","label":"Raw Data","params":[],"state":"new","block_reason":"none","metadata":[]}},"edges":{"e1":{"id":"e1","from":"raw","to":"m1","type":"data","metadata":[]}},"gates":{"g1":{"id":"g1","edge_id":"e1","status":"pending","metadata":[]}},"version":4,"metadata":{"project":"pilot"}}
```

Two caveats to know about, both consequences of JSON being shape-blind:

- `auto_unbox = TRUE` cannot distinguish a scalar from a length-1
  vector: `params = list(cols = c("x"))` writes `"cols": "x"`. If a
  length-1 array must stay an array, wrap it in
  [`I()`](https://rdrr.io/r/base/AsIs.html)
  (`params = list(cols = I(c("x")))` writes `"cols": ["x"]`).
- An empty *unnamed* list writes as `[]`, an empty *named* list as
  [`{}`](https://rdrr.io/r/base/Paren.html). dagriculture’s collections
  are always named, so they emit
  [`{}`](https://rdrr.io/r/base/Paren.html). The default
  `metadata = list()` is unnamed-empty and emits `[]`; both forms read
  back as empty lists and both are valid metadata.

For reproducible bytes (hashing, diffing), pin every option — including
`pretty`.
[`toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
preserves the insertion order of the R list, and two graphs holding the
same records can carry them in different insertion orders, so the writer
canonicalizes key order itself: `canonical_order()` re-indexes `nodes`,
`edges`, `gates`, and the registry’s `kinds` with
`sort(names(...), method = "radix")` before
[`toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
runs — exactly the stable lexical order the persistence spec asks of
writers. Two graphs built by inserting the same records in different
orders therefore serialize to identical bytes. The `method = "radix"`
argument is what makes this safe across machines: radix sorting compares
strings byte-wise in the C locale, so the written keys — and any hash of
the bytes — are machine-independent, whereas
[`sort()`](https://rdrr.io/r/base/sort.html)’s default collation
(`LC_COLLATE`) orders the id charset’s `-`, `_`, `.` differently in
locales like `en_US.UTF-8`. Only the four named maps are re-ordered;
unnamed arrays (a default `params = list()`, for example) keep their
shape and order untouched.

## Reading: simplify, normalize, check, validate

The reader is the mirror image, plus three fixes jsonlite will not do
for you. Parse the snapshot with `simplifyVector = FALSE`, confirm its
`schema_name`, and extract the graph fields; then normalize JSON `null`
back to the nullable R fields, check map keys against embedded ids, and
confirm the revived graph through a public call — the recipe ends with
[`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md),
which exercises the validation every public function runs on entry and
additionally rejects cyclic snapshots.

`fromJSON(txt, simplifyVector = FALSE)` keeps every JSON object a named
list and never coerces arrays or heterogeneous values. With the default
simplification, `["a", null, "b"]` collapses to `c("a", NA, "b")` — your
`NULL` param value silently becomes `NA` — and length-1 arrays collapse
to scalars.

``` r

# JSON null (and the {} that non-canonical writers emit for absent nullable
# fields) must land as R NULL on the contractually nullable fields.
normalize_nulls <- function(graph) {
  nullable_kind_fields <- c("input_contract", "output_type", "param_schema")
  for (i in seq_along(graph$registry$kinds)) {
    kind <- graph$registry$kinds[[i]]
    for (field in nullable_kind_fields) {
      if (is.list(kind[[field]]) && length(kind[[field]]) == 0L) {
        kind[[field]] <- NULL
      }
    }
    graph$registry$kinds[[i]] <- kind
  }
  for (i in seq_along(graph$nodes)) {
    node <- graph$nodes[[i]]
    if (is.list(node$label) && length(node$label) == 0L) {
      node$label <- NULL
    }
    graph$nodes[[i]] <- node
  }
  graph
}

# Named-map keys are the canonical lookup; the embedded id/name fields must
# agree with them (see the next section).
check_snapshot_maps <- function(graph) {
  stopifnot(
    identical(names(graph$nodes), unname(vapply(graph$nodes, `[[`, character(1), "id"))),
    identical(names(graph$edges), unname(vapply(graph$edges, `[[`, character(1), "id"))),
    identical(names(graph$gates), unname(vapply(graph$gates, `[[`, character(1), "id"))),
    identical(
      names(graph$registry$kinds),
      unname(vapply(graph$registry$kinds, `[[`, character(1), "name"))
    )
  )
  invisible(TRUE)
}

read_graph_json <- function(txt) {
  snapshot <- fromJSON(txt, simplifyVector = FALSE)
  stopifnot(identical(snapshot$schema_name, "dagri_graph_snapshot"))
  graph <-
    snapshot[c("registry", "nodes", "edges", "gates", "version", "metadata")]
  graph <- normalize_nulls(graph)
  check_snapshot_maps(graph)
  # Restore the S3 class so print.dagri_graph() dispatches.
  structure(graph, class = c("dagri_graph", "list"))
}
```

``` r

g2 <- read_graph_json(txt)

is.null(g2$nodes$m1$label)                  # nullable field restored as NULL
#> [1] TRUE
is.null(g2$registry$kinds$source$param_schema)
#> [1] TRUE
identical(names(g2$gates), "g1")
#> [1] TRUE

dagri_topo_order(g2)
#> [1] "raw" "m1"
```

[`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)
is the public load check: every `dagriculture` function validates graph
structure on entry, and topological ordering additionally rejects cyclic
snapshots — exactly the hydration hazard a revived file can carry. A
revived graph that sorts cleanly is structurally sound *and* acyclic.
The validation is deliberately kept cheap and structural, so note what
it does *not* do (next sections).

One asymmetry to remember when comparing:
[`toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
writes R atomic vectors as JSON arrays, and `simplifyVector = FALSE`
reads JSON arrays back as R *lists*. So
`param_schema = list(required = c("model"))` round-trips as
`list(required = list("model"))` — semantically equal, not
[`identical()`](https://rdrr.io/r/base/identical.html). Normalize both
sides (for example, re-serialize each with `write_graph_json()` and
compare the text) instead of calling
[`identical()`](https://rdrr.io/r/base/identical.html) on a reloaded
graph.

## Named-map keys and embedded ids

Both exist on purpose. The map keys (`names(graph$nodes)`) are what
dagriculture itself looks things up by —
[`dagri_node()`](https://sims1253.github.io/dagriculture/reference/dagri_node.md),
referential checks in the entry-point validation, duplicate detection in
the editors. The embedded `id` (or `name`, for kinds) travels *inside*
the record so snapshot consumers that iterate records without a map
context (JSONL exports, database rows) still know what they are looking
at.

The entry-point validation uses the map keys for referential integrity
but does not compare them to the embedded ids, so a hand-edited file
where the two disagree passes every public call and misbehaves later.
That is what `check_snapshot_maps()` above guards:

``` r

check_snapshot_maps(g2)

# A key/id mismatch is invisible to the entry-point validation: it resolves
# references by map key and never reads the embedded id. Rename the key of
# an edge-less node and public calls still pass...
tampered <- dagri_add_node(g2, "iso", "source")
names(tampered$nodes)[[3]] <- "renamed"
dagri_topo_order(tampered)
#> [1] "raw"     "renamed" "m1"
```

``` r

# ...but the map check catches it:
check_snapshot_maps(tampered)
#> Error in `check_snapshot_maps()`:
#> ! identical(names(graph$nodes), unname(vapply(graph$nodes, `[[`,  .... is not TRUE
```

## Choosing ids

The *enforced* rule is narrow: every id-taking argument of the
constructors and editors
([`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md)’s
`name`,
[`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md)’s
`id`,
[`dagri_add_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_add_edge.md)’s
`from`/`to`/`id`,
[`dagri_add_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_add_gate.md)’s
`edge_id`/`id`, and the update/remove functions) must be a single
non-empty, non-`NA` character string. dagriculture does not restrict the
character set and does not sanitize ids on load.

The *recommended* pattern is `[A-Za-z0-9_.-]+`. Ids become JSON object
keys, file names, and (via
[`dagri_mermaid()`](https://sims1253.github.io/dagriculture/reference/dagri_mermaid.md))
Mermaid node identifiers, which dagriculture does not sanitize — ids
outside that pattern work in memory but tend to break one of those
consumers. Two more key-shape rules worth respecting:

- Keep map keys unique. R named lists can technically carry duplicate
  names; JSON objects cannot, and duplicate keys silently collapse to
  the last value on read. The editors already reject duplicate
  node/edge/gate ids at edit time.
- Remember that ids are matched exactly, never normalized: `"fit_1"` and
  `"fit.1"` are different nodes.

## The no-code boundary on load

The persistence rule is: persist plain data, never executable code. JSON
gives you that by construction — a closure cannot survive
[`toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html).
An RDS file can, which is where the boundary needs stating precisely.

Every public `dagriculture` function runs the same cheap structural
check before doing anything with a graph — the validator behind it
([`dagri_validate_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_graph.md))
is internal and unexported, so public calls are the boundary. It checks
structure only:

1.  required top-level fields are present and components are lists (not
    data.frames),
2.  `version` is a single non-`NA` integer,
3.  every edge’s `from`/`to` resolves against `names(graph$nodes)`,
4.  every gate’s `edge_id` resolves against `names(graph$edges)`.

It does **not** scan `params`, `metadata`, or `param_schema` for
closures or other reference-bearing values, and it does not detect
cycles (that is
[`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md)’s
job when you traverse). Concretely, a graph smuggled through
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html) with a closure in
`params` passes every structural check:

``` r

suspicious <- dagri_graph(reg) |>
  dagri_add_node("raw", "source", params = list(loader = function(x) x))

f <- tempfile(fileext = ".rds")
saveRDS(suspicious, f)
loaded <- readRDS(f)

class(loaded$nodes$raw$params$loader)  # the closure survived the round trip
#> [1] "function"
dagri_topo_order(loaded)               # ...and the public surface accepts it
#> [1] "raw"
```

So where does the no-code guarantee actually come from? From the *entry
points*, not from the load boundary. Stated precisely:

- `metadata` is validated as named plain data by every constructor and
  editor that accepts it
  ([`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md),
  [`dagri_registry()`](https://sims1253.github.io/dagriculture/reference/dagri_registry.md),
  [`dagri_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_graph.md),
  [`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md),
  [`dagri_update_node()`](https://sims1253.github.io/dagriculture/reference/dagri_update_node.md),
  [`dagri_add_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_add_edge.md),
  [`dagri_update_edge()`](https://sims1253.github.io/dagriculture/reference/dagri_update_edge.md),
  [`dagri_add_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_add_gate.md),
  [`dagri_update_gate()`](https://sims1253.github.io/dagriculture/reference/dagri_update_gate.md)):
  closures, environments, formulas, language objects, S4 objects,
  external pointers, and weak references are rejected recursively.
- `param_schema` gets a shape check and a no-closure check — but only
  when
  [`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md)
  runs.
- Nothing re-scans the caller-owned fields of an *already assembled*
  graph.
  [`dagri_validate_graph()`](https://sims1253.github.io/dagriculture/reference/dagri_validate_graph.md),
  which every public call runs, checks structure and referential
  integrity only; cycles surface later, through traversal calls like
  [`dagri_topo_order()`](https://sims1253.github.io/dagriculture/reference/dagri_topo_order.md).
  So the `params`, `metadata`, and `param_schema` of a graph loaded from
  RDS — or handed in after direct assignment like
  `graph$nodes$raw$metadata <- list(env = new.env())` — are exactly as
  trustworthy as the source they came from.

Practical guidance: treat the JSON recipe above as your persistence
format and RDS only as a trusted-cache format. If you must load a graph
from RDS you do not fully trust, scan its caller-owned fields with the
same recursive plain-data test the entry points apply before using it:

``` r

is_plain_data <- function(x) {
  if (
    is.function(x) || is.environment(x) || is.language(x) || isS4(x) ||
      inherits(x, "formula") ||
      identical(typeof(x), "externalptr") || identical(typeof(x), "weakref")
  ) {
    return(FALSE)
  }
  if (is.list(x)) {
    return(all(vapply(x, is_plain_data, logical(1))))
  }
  TRUE
}

graph_is_plain_data <- function(graph) {
  is_plain_data(graph$metadata) &&
    is_plain_data(graph$registry$metadata) &&
    all(vapply(
      graph$registry$kinds,
      function(k) is_plain_data(k$param_schema) && is_plain_data(k$metadata),
      logical(1)
    )) &&
    all(vapply(
      graph$nodes,
      function(n) is_plain_data(n$params) && is_plain_data(n$metadata),
      logical(1)
    )) &&
    all(vapply(graph$edges, function(e) is_plain_data(e$metadata), logical(1))) &&
    all(vapply(graph$gates, function(g) is_plain_data(g$metadata), logical(1)))
}

graph_is_plain_data(loaded)  # FALSE: params$loader is a closure
#> [1] FALSE
graph_is_plain_data(g)       # TRUE: fields that passed the entry points
#> [1] TRUE
```

The alternative — reconstruction — is only a partial substitute. Pushing
a record back through
[`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md)/[`dagri_update_node()`](https://sims1253.github.io/dagriculture/reference/dagri_update_node.md)
re-validates its `metadata`, and
[`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md)
additionally enforces the kind’s `input_contract` for required params,
but neither mutator plain-data-checks arbitrary `params`, and
`param_schema` is only checked when
[`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md)
runs. For untrusted payloads, the scan above is the guarantee.

## `param_schema` is declarative

A kind’s `param_schema` is documentary.
[`dagri_kind()`](https://sims1253.github.io/dagriculture/reference/dagri_kind.md)
validates its *shape* — a named list, arbitrarily nested, free of
closures — but dagriculture does **not** enforce schema constraints
against node `params`, ever. Nothing stops
`dagri_add_node(g, "m1", "fit", params = list(wrong = 1))` under a kind
whose `param_schema` says `required = c("model")`.

The one params check that does exist is a different, weaker mechanism:
[`dagri_add_node()`](https://sims1253.github.io/dagriculture/reference/dagri_add_node.md)
enforces the kind’s `input_contract` — params must *contain* the
contract’s field names (types are not checked). If you need
`param_schema` actually enforced, validate node params against it in
your own constructor or wrapper before they enter a graph.

## Comparing and hashing after a reload

- Fix the writer options (`auto_unbox`, `null`, `digits`, `pretty`) and
  the canonical key order — any change to either rewrites every
  serialized value.
- Normalize before comparing: run the reader recipe on both sides so
  nullable fields are `NULL`, keys are checked, and vectors-versus-lists
  differences are resolved.
- `graph$version` is a reliable structural edit counter, but it is not a
  content hash: two graphs built in different orders can differ in
  `version`, map order, and `state` while being structurally equal.
