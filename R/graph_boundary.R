# Graph boundary helpers migrated from bayesgrove.
#
# These graph-generic operations used to live in bayesgrove's
# `R/dagri-adapters.R` as `bg_dagri_*` migration candidates. They are pure
# value-oriented topology helpers that belong here, where the graph lives.
# See `design/api-contracts.md` for the boundary contract.

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
  if (length(edges) == 0) {
    return(character())
  }

  edge_names <- names(edges) %||% rep("", length(edges))
  if (all(nzchar(edge_names))) {
    return(sort(unique(edge_names)))
  }

  edge_ids <- vapply(
    edges,
    function(edge) edge$id %||% "",
    character(1)
  )
  if (!all(nzchar(edge_ids))) {
    abort_dagri(
      "dagri_error_invalid_argument",
      "Graph edges must be named or carry non-empty `id` fields for diffing."
    )
  }

  sort(unique(edge_ids))
}

# --- Structural graph diff ---

#' Structural diff of two graphs
#'
#' Returns a pure structural diff with no workflow semantics: which node and
#' edge ids were added or removed going from `before` to `after`. Nodes use
#' `names(graph$nodes)`; edges use `dagri_edge_ids()` so both named-map storage
#' and unnamed edge lists with embedded ids are supported.
#'
#' @param before A `dagri_graph` (the prior state).
#' @param after A `dagri_graph` (the new state).
#' @return A list with `added_nodes`, `removed_nodes`, `added_edges`, and
#'   `removed_edges` (each a character vector).
#' @export
#' @examples
#' reg <- dagri_registry(dagri_kind("source"), dagri_kind("fit"))
#' before <- dagri_graph(reg) |>
#'   dagri_add_node("data", "source") |>
#'   dagri_add_node("fit", "fit") |>
#'   dagri_add_edge("data", "fit", id = "e1")
#' after <- dagri_add_node(before, "diag", "fit")
#' diff <- dagri_graph_diff(before, after)
#' diff$added_nodes
dagri_graph_diff <- function(before, after) {
  dagri_validate_graph(before)
  dagri_validate_graph(after)

  before_nodes <- names(before$nodes %||% list())
  after_nodes <- names(after$nodes %||% list())
  before_edges <- dagri_edge_ids(before$edges %||% list())
  after_edges <- dagri_edge_ids(after$edges %||% list())

  list(
    added_nodes = setdiff(after_nodes, before_nodes),
    removed_nodes = setdiff(before_nodes, after_nodes),
    added_edges = setdiff(after_edges, before_edges),
    removed_edges = setdiff(before_edges, after_edges)
  )
}

# --- Internal: single-string node-id presence check ---

dagri_validate_single_node <- function(graph, node_id) {
  if (!is.character(node_id) || length(node_id) != 1 || is.na(node_id)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`node_id` must be a single character string, got %s.",
        paste(class(node_id), collapse = "/")
      )
    )
  }
  if (!node_id %in% names(graph$nodes)) {
    abort_dagri(
      "dagri_error_not_found",
      sprintf("Node %s not found.", node_id)
    )
  }
  invisible(node_id)
}
