# --- Edge lookup by endpoint ---

#' Incoming edges for a node
#'
#' Returns the edge objects whose `to` endpoint is `node_id`, preserving the
#' container names of `graph$edges`. Unlike `dagri_upstream()`, which returns
#' neighbor node ids, this returns the full edge objects so callers can inspect
#' edge ids, types, and metadata.
#'
#' @param graph A `dagri_graph`.
#' @param node_id Single character string naming a node in `graph`.
#' @return A named list of edge objects (possibly empty).
#' @export
#' @examples
#' graph <- dagri_graph(dagri_registry(dagri_kind("source"), dagri_kind("fit")))
#' graph <- dagri_add_node(graph, "data", "source")
#' graph <- dagri_add_node(graph, "fit", "fit")
#' graph <- dagri_add_edge(graph, "data", "fit", id = "e1")
#' incoming <- dagri_incoming_edges(graph, "fit")
#' length(incoming) == 1
dagri_incoming_edges <- function(graph, node_id) {
  dagri_validate_graph(graph)
  dagri_validate_single_node(graph, node_id)

  Filter(function(edge) identical(edge$to, node_id), graph$edges)
}

#' Outgoing edges for a node
#'
#' Returns the edge objects whose `from` endpoint is `node_id`, preserving the
#' container names of `graph$edges`. Unlike `dagri_downstream()`, which returns
#' neighbor node ids, this returns the full edge objects so callers can inspect
#' edge ids, types, and metadata.
#'
#' @param graph A `dagri_graph`.
#' @param node_id Single character string naming a node in `graph`.
#' @return A named list of edge objects (possibly empty).
#' @export
#' @examples
#' graph <- dagri_graph(dagri_registry(dagri_kind("source"), dagri_kind("fit")))
#' graph <- dagri_add_node(graph, "data", "source")
#' graph <- dagri_add_node(graph, "fit", "fit")
#' graph <- dagri_add_edge(graph, "data", "fit", id = "e1")
#' outgoing <- dagri_outgoing_edges(graph, "data")
#' length(outgoing) == 1
dagri_outgoing_edges <- function(graph, node_id) {
  dagri_validate_graph(graph)
  dagri_validate_single_node(graph, node_id)

  Filter(function(edge) identical(edge$from, node_id), graph$edges)
}

# --- Deterministic edge ordering ---

#' Order edges deterministically by edge id
#'
#' Returns a copy of `edges` sorted by the embedded `edge$id` field (falling
#' back to `""` when an edge has no `id`). Empty or length-1 lists are returned
#' unchanged. Container names are preserved. Used by consumers that need a
#' stable fingerprint of multi-input nodes.
#'
#' @param edges A named or unnamed list of edge objects.
#' @return The same list, reordered by edge id.
#' @export
#' @examples
#' edges <- list(
#'   late = list(id = "edge_z", from = "a", to = "b"),
#'   early = list(id = "edge_a", from = "c", to = "d"),
#'   middle = list(id = "edge_m", from = "e", to = "f")
#' )
#' ordered <- dagri_order_edges(edges)
#' vapply(ordered, function(e) e$id, character(1))
dagri_order_edges <- function(edges) {
  if (length(edges) <= 1) {
    return(edges)
  }

  edge_ids <- vapply(
    edges,
    function(edge) edge$id %||% "",
    character(1)
  )
  edges[order(edge_ids)]
}

# --- Edge id extraction with fallback semantics ---

#' Sorted unique edge ids
#'
#' Extracts edge ids from a list of edge objects. Prefers container
#' `names(edges)` when every name is non-empty; otherwise falls back to the
#' embedded `edge$id` field. This dual path keeps the helper usable both for
#' the canonical named-map storage shape and for unnamed edge lists carrying
#' embedded ids (for example after `unname()`).
#'
#' Aborts with `dagri_error_invalid_argument` when neither path yields complete
#' non-empty ids, since unidentifiable edges cannot be diffed.
#'
#' @param edges A named or unnamed list of edge objects.
#' @return Sorted, de-duplicated character vector of edge ids (possibly empty).
#' @export
#' @examples
#' edges <- list(
#'   e2 = list(id = "e2", from = "a", to = "b"),
#'   e1 = list(id = "e1", from = "c", to = "d")
#' )
#' dagri_edge_ids(edges)
dagri_edge_ids <- function(edges) {
  sort(unique(names(dagri_edge_map(edges))))
}

#' Key an edge collection by id, preserving storage order
#'
#' Internal building block for the graph diff: returns the edge objects as a
#' named list keyed by edge id in storage (insertion) order. Follows the same
#' dual path as [dagri_edge_ids()] — container `names(edges)` when every name
#' is non-empty, otherwise the embedded `edge$id` fields — so both the
#' canonical named-map storage shape and unnamed edge lists with embedded ids
#' are supported.
#'
#' Aborts with `dagri_error_invalid_argument` when neither path yields
#' complete non-empty ids, since unidentifiable edges cannot be diffed.
#'
#' @param edges A named or unnamed list of edge objects.
#' @return A named list of edge objects keyed by edge id (possibly empty).
#' @keywords internal
dagri_edge_map <- function(edges) {
  if (length(edges) == 0) {
    return(stats::setNames(list(), character(0)))
  }

  edge_names <- names(edges) %||% rep("", length(edges))
  if (!all(nzchar(edge_names))) {
    edge_names <- vapply(
      edges,
      function(edge) edge$id %||% "",
      character(1)
    )
    if (!all(nzchar(edge_names))) {
      abort_dagri(
        "dagri_error_invalid_argument",
        "Graph edges must be named or carry non-empty `id` fields for diffing."
      )
    }
  }

  stats::setNames(edges, edge_names)
}

# --- Graph diff ---

#' Diff shared records field by field
#'
#' Internal worker for [dagri_graph_diff()]: walks `common_ids` (ids present in
#' both graphs, already ordered by the caller) and compares the tracked
#' `fields` per record with [identical()] on the stored values, so `NULL` vs
#' `NULL` compares equal.
#'
#' @param before_map Named list of before-state records keyed by id.
#' @param after_map Named list of after-state records keyed by id.
#' @param common_ids Character vector of ids present in both maps.
#' @param fields Character vector of field names to compare.
#' @param include_values Whether to collect before/after values per change.
#' @return A list with `changed_ids` (character vector in `common_ids` order)
#'   and `values` (named list keyed by changed ids; each entry a named list of
#'   only the differing fields, each `list(before = <value>, after =
#'   <value>)`; an empty named list when `include_values` is `FALSE`).
#' @keywords internal
dagri_diff_records <- function(before_map, after_map, common_ids, fields, include_values) {
  changed_ids <- character(0)
  changed_values <- stats::setNames(list(), character(0))

  for (id in common_ids) {
    before_record <- before_map[[id]]
    after_record <- after_map[[id]]

    differing <- fields[
      !vapply(
        fields,
        function(field) identical(before_record[[field]], after_record[[field]]),
        logical(1)
      )
    ]
    if (length(differing) == 0) {
      next
    }

    changed_ids <- c(changed_ids, id)
    if (include_values) {
      changed_values[[id]] <- stats::setNames(
        lapply(
          differing,
          function(field) {
            list(before = before_record[[field]], after = after_record[[field]])
          }
        ),
        differing
      )
    }
  }

  list(changed_ids = changed_ids, values = changed_values)
}

#' Diff two graphs: structure and tracked field values
#'
#' Returns a pure diff with no workflow semantics: which node, edge, and gate
#' ids were added or removed going from `before` to `after`, which ids present
#' in both graphs had tracked fields change, and (with `include_values = TRUE`)
#' the before/after values of every changed field. Nodes are keyed by
#' `names(graph$nodes)`; edges by [dagri_edge_ids()] so both named-map storage
#' and unnamed edge lists with embedded ids are supported; gates by
#' `names(graph$gates)`.
#'
#' @details Tracked fields, compared per field with [identical()] on the stored
#'   in-memory values (`NULL` vs `NULL` compares equal):
#'
#'   - nodes: `kind`, `label`, `params`, `state`, `block_reason`, `metadata`
#'   - edges: `from`, `to`, `type`, `metadata`
#'   - gates: `edge_id`, `status`, `metadata`
#'
#'   `graph$version` is ignored: it is derived bookkeeping, not content.
#'
#'   Because comparison is `identical()`-based on in-memory values, two graphs
#'   that serialize identically can still diff when their in-memory shapes
#'   differ (for example `NULL` vs `""`, or list attribute differences).
#'   Callers diffing JSON-round-tripped graphs should normalize values before
#'   diffing; the serialization rules live in `design/persistence-spec.md`.
#'
#' @param before A `dagri_graph` (the prior state).
#' @param after A `dagri_graph` (the new state).
#' @param include_values Single `TRUE` or `FALSE`, default `FALSE`. When
#'   `TRUE`, the result additionally carries a `values` element with the
#'   before/after values of every changed field.
#' @return A named list, in this order:
#'
#'   - `added_nodes`, `removed_nodes`, `added_edges`, `removed_edges`,
#'     `added_gates`, `removed_gates`: character vectors of ids present in
#'     only one of the two graphs. The first four keep the exact semantics of
#'     the original structural-only diff: plain [setdiff()] over node names
#'     and [dagri_edge_ids()].
#'   - `changed_nodes`, `changed_edges`, `changed_gates`: character vectors of
#'     ids present in both graphs (by key) where at least one tracked field
#'     differs. Deterministic: ids appear in the named-map insertion order of
#'     `after`.
#'   - `values`: only present when `include_values = TRUE`. A named list with
#'     elements `nodes`, `edges`, and `gates`; each is a named list keyed by
#'     the changed ids (same ids and order as the matching `changed_*`
#'     vector), and each entry is a named list of only the differing fields,
#'     each field `list(before = <value>, after = <value>)`. Ids that were
#'     only added or removed do not appear in `values`.
#' @export
#' @examples
#' reg <- dagri_registry(dagri_kind("source"), dagri_kind("fit"))
#' before <- dagri_graph(reg) |>
#'   dagri_add_node("data", "source") |>
#'   dagri_add_node("fit", "fit", label = "Fit") |>
#'   dagri_add_edge("data", "fit", id = "e1")
#' after <- dagri_add_node(before, "diag", "fit")
#' diff <- dagri_graph_diff(before, after)
#' diff$added_nodes
#'
#' # A relabel is invisible to the structural vectors but shows up as a
#' # change; include_values = TRUE carries the before/after values along.
#' relabeled <- dagri_update_node(after, "fit", label = "Posterior fit")
#' value_diff <- dagri_graph_diff(after, relabeled, include_values = TRUE)
#' value_diff$changed_nodes
#' value_diff$values$nodes$fit$label$before
#' value_diff$values$nodes$fit$label$after
dagri_graph_diff <- function(before, after, include_values = FALSE) {
  dagri_validate_graph(before)
  dagri_validate_graph(after)
  dagri_validate_flag(include_values, "include_values")

  before_nodes <- names(before$nodes %||% list()) %||% character(0)
  after_nodes <- names(after$nodes %||% list()) %||% character(0)
  before_gates <- names(before$gates %||% list()) %||% character(0)
  after_gates <- names(after$gates %||% list()) %||% character(0)

  before_edge_map <- dagri_edge_map(before$edges %||% list())
  after_edge_map <- dagri_edge_map(after$edges %||% list())
  # Same as dagri_edge_ids() on the same collections: sorted unique keys.
  before_edges <- sort(unique(names(before_edge_map)))
  after_edges <- sort(unique(names(after_edge_map)))

  # intersect() preserves the order of its first argument, so shared ids are
  # compared in `after`'s named-map insertion order and changed_* inherits it.
  node_diff <- dagri_diff_records(
    before$nodes %||% list(),
    after$nodes %||% list(),
    intersect(after_nodes, before_nodes),
    c("kind", "label", "params", "state", "block_reason", "metadata"),
    include_values
  )
  edge_diff <- dagri_diff_records(
    before_edge_map,
    after_edge_map,
    intersect(names(after_edge_map), before_edges),
    c("from", "to", "type", "metadata"),
    include_values
  )
  gate_diff <- dagri_diff_records(
    before$gates %||% list(),
    after$gates %||% list(),
    intersect(after_gates, before_gates),
    c("edge_id", "status", "metadata"),
    include_values
  )

  result <- list(
    added_nodes = setdiff(after_nodes, before_nodes),
    removed_nodes = setdiff(before_nodes, after_nodes),
    added_edges = setdiff(after_edges, before_edges),
    removed_edges = setdiff(before_edges, after_edges),
    added_gates = setdiff(after_gates, before_gates),
    removed_gates = setdiff(before_gates, after_gates),
    changed_nodes = node_diff$changed_ids,
    changed_edges = edge_diff$changed_ids,
    changed_gates = gate_diff$changed_ids
  )
  if (include_values) {
    result$values <- list(
      nodes = node_diff$values,
      edges = edge_diff$values,
      gates = gate_diff$values
    )
  }
  result
}

# --- Internal: single-string node-id presence check ---

dagri_validate_single_node <- function(graph, node_id) {
  dagri_validate_id(node_id, "node_id")
  if (!node_id %in% names(graph$nodes)) {
    abort_dagri(
      "dagri_error_not_found",
      sprintf("Node %s not found.", node_id)
    )
  }
  invisible(node_id)
}

dagri_validate_id <- function(x, arg = "id") {
  if (!is.character(x) || length(x) != 1 || is.na(x) || !nzchar(x)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`%s` must be a single non-empty character string, got %s.",
        arg,
        paste(class(x), collapse = "/")
      )
    )
  }
  invisible(x)
}

dagri_validate_flag <- function(x, arg) {
  if (!is.logical(x) || length(x) != 1 || is.na(x)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`%s` must be a single TRUE or FALSE, got %s.",
        arg,
        paste(class(x), collapse = "/")
      )
    )
  }
  invisible(x)
}
