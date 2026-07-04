# Internal adjacency index for traversal and planning.
#
# Building the index is O(V+E) and is performed once per public call.
# The index is a derived value: it is never stored on the graph, so the
# pure-value, immutable public API is unchanged. Internals that previously
# re-scanned the full edge list per neighbor lookup instead index into the
# pre-built maps.

# Initialize four named adjacency maps keyed by every node id, each entry
# starting as `character(0)` so downstream code never has to guard against
# NULLs (e.g. isolated nodes, or nodes with no incoming edges).
dagri_empty_adjacency_maps <- function(node_ids) {
  empty <- rep(list(character(0)), length(node_ids))
  stats::setNames(empty, node_ids)
}

#' Build the internal adjacency index for a graph
#'
#' Performs a single O(V+E) pass over `graph$edges` and returns four named
#' lists keyed by every node id in `names(graph$nodes)` (each initialized to
#' `character(0)` so no NULL-guarding is needed):
#'
#' - `forward`: node -> unique vector of downstream neighbor ids
#'   (`edge$from -> edge$to`)
#' - `reverse`: node -> unique vector of upstream neighbor ids
#'   (`edge$to -> edge$from`)
#' - `forward_edges`: node -> vector of outgoing edge ids (not uniqued;
#'   each edge is distinct)
#' - `reverse_edges`: node -> vector of incoming edge ids (not uniqued)
#'
#' The index is derived per call and is never stored on the graph, so the
#' pure-value, immutable public API is unchanged. Internals that previously
#' re-scanned the full edge list per neighbor lookup instead index into these
#' pre-built maps.
#'
#' @param graph A `dagri_graph`.
#' @return A named list with components `forward`, `reverse`,
#'   `forward_edges`, and `reverse_edges`, each a named list keyed by node id.
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

  list(
    forward = forward,
    reverse = reverse,
    forward_edges = forward_edges,
    reverse_edges = reverse_edges
  )
}
