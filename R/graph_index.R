# Internal adjacency index for traversal and planning.
#
# Building the index is O(V+E+G) and is performed once per public call.
# The index is a derived value: it is never stored on the graph, so the
# pure-value, immutable public API is unchanged. Internals that previously
# re-scanned the full edge list per neighbor lookup (or the full gate list
# per edge) instead index into the pre-built maps.

# Initialize named maps keyed by every id in `ids`, each entry starting as
# `character(0)` so downstream code never has to guard against NULLs (e.g.
# isolated nodes, or nodes with no incoming edges).
dagri_empty_adjacency_maps <- function(ids) {
  empty <- rep(list(character(0)), length(ids))
  stats::setNames(empty, ids)
}

#' Build the internal adjacency index for a graph
#'
#' Performs a single O(V+E+G) pass over `graph$edges` and `graph$gates` and
#' returns five named lists (each initialized to `character(0)` entries so no
#' NULL-guarding is needed):
#'
#' - `forward`: node -> unique vector of downstream neighbor ids
#'   (`edge$from -> edge$to`), keyed by every node id
#' - `reverse`: node -> unique vector of upstream neighbor ids
#'   (`edge$to -> edge$from`), keyed by every node id
#' - `forward_edges`: node -> vector of outgoing edge ids (not uniqued;
#'   each edge is distinct), keyed by every node id
#' - `reverse_edges`: node -> vector of incoming edge ids (not uniqued),
#'   keyed by every node id
#' - `pending_gate_ids_by_edge`: edge -> vector of pending gate ids on that
#'   edge in gate insertion order, keyed by every edge id
#'
#' The index is derived per call and is never stored on the graph, so the
#' pure-value, immutable public API is unchanged. Internals that previously
#' re-scanned the full edge or gate lists per lookup instead index into these
#' pre-built maps.
#'
#' @param graph A `dagri_graph`.
#' @return A named list with components `forward`, `reverse`,
#'   `forward_edges`, `reverse_edges` (each a named list keyed by node id),
#'   and `pending_gate_ids_by_edge` (a named list keyed by edge id).
#' @keywords internal
dagri_adjacency <- function(graph) {
  dagri_validate_graph(graph)

  node_ids <- names(graph$nodes)

  forward <- dagri_empty_adjacency_maps(node_ids)
  reverse <- dagri_empty_adjacency_maps(node_ids)
  forward_edges <- dagri_empty_adjacency_maps(node_ids)
  reverse_edges <- dagri_empty_adjacency_maps(node_ids)

  for (eid in names(graph$edges)) {
    edge <- graph$edges[[eid]]
    from <- edge$from
    to <- edge$to

    forward[[from]] <- unique(c(forward[[from]], to))
    reverse[[to]] <- unique(c(reverse[[to]], from))
    forward_edges[[from]] <- c(forward_edges[[from]], eid)
    reverse_edges[[to]] <- c(reverse_edges[[to]], eid)
  }

  # Pending gates indexed by edge id in a single pass over `graph$gates`, so
  # per-edge gate lookups (node status, state recomputation) never rescan the
  # full gate list. Gate ids append in list order = gate insertion order.
  pending_gate_ids_by_edge <- dagri_empty_adjacency_maps(names(graph$edges))
  for (gid in names(graph$gates)) {
    gate <- graph$gates[[gid]]
    if (identical(gate$status, "pending")) {
      eid <- gate$edge_id
      pending_gate_ids_by_edge[[eid]] <- c(pending_gate_ids_by_edge[[eid]], gid)
    }
  }

  list(
    forward = forward,
    reverse = reverse,
    forward_edges = forward_edges,
    reverse_edges = reverse_edges,
    pending_gate_ids_by_edge = pending_gate_ids_by_edge
  )
}
