#' Add a node to a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param id Node ID.
#' @param kind Node kind.
#' @param label Node label.
#' @param params Node parameters.
#' @param metadata Node metadata.
#' @export
groots_add_node <- function(graph, id, kind, label = NULL, params = list(), metadata = list()) {
  if (!kind %in% names(graph$registry$kinds)) {
    abort_groots("groots_error_unknown_kind", "Unknown node kind.")
  }
  if (id %in% names(graph$nodes)) {
    abort_groots("groots_error_duplicate_id", "Duplicate node id.")
  }

  node <- list(
    id = id,
    kind = kind,
    label = label,
    params = params,
    state = "new",
    block_reason = "none",
    metadata = metadata
  )

  graph$nodes[[id]] <- node
  graph$version <- graph$version + 1L
  graph
}

#' Update a node in a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param node_id Node ID.
#' @param label Node label.
#' @param params Node parameters.
#' @param metadata Node metadata.
#' @export
groots_update_node <- function(graph, node_id, label = NULL, params = NULL, metadata = NULL) {
  if (!node_id %in% names(graph$nodes)) {
    abort_groots("groots_error_not_found", "Node not found.")
  }

  node <- graph$nodes[[node_id]]
  if (!is.null(label)) {
    node$label <- label
  }
  if (!is.null(params)) {
    node$params <- params
  }
  if (!is.null(metadata)) {
    node$metadata <- metadata
  }

  graph$nodes[[node_id]] <- node
  graph$version <- graph$version + 1L
  graph
}

#' Remove a node from a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param node_id Node ID.
#' @export
groots_remove_node <- function(graph, node_id) {
  if (!node_id %in% names(graph$nodes)) {
    abort_groots("groots_error_not_found", "Node not found.")
  }
  graph$nodes[[node_id]] <- NULL
  graph$version <- graph$version + 1L
  graph
}

#' Add an edge to a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param from Upstream node ID.
#' @param to Downstream node ID.
#' @param type Edge type.
#' @param id Optional Edge ID.
#' @param metadata Edge metadata.
#' @export
groots_add_edge <- function(graph, from, to, type = "data", id = NULL, metadata = list()) {
  if (is.null(id)) {
    id <- paste0("edge_", from, "_", to)
  }
  if (!from %in% names(graph$nodes) || !to %in% names(graph$nodes)) {
    abort_groots("groots_error_not_found", "Missing node.")
  }

  if (groots_has_path(graph, to, from)) {
    abort_groots("groots_error_cycle", "Cycle detected.")
  }

  edge <- list(
    id = id,
    from = from,
    to = to,
    type = type,
    metadata = metadata
  )

  graph$edges[[id]] <- edge
  graph$version <- graph$version + 1L
  graph
}

#' Remove an edge from a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param edge_id Edge ID.
#' @export
groots_remove_edge <- function(graph, edge_id) {
  if (!edge_id %in% names(graph$edges)) {
    abort_groots("groots_error_not_found", "Missing edge.")
  }
  graph$edges[[edge_id]] <- NULL
  graph$version <- graph$version + 1L
  graph
}

#' Add a gate to a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param edge_id Edge ID.
#' @param id Optional Gate ID.
#' @param metadata Gate metadata.
#' @export
groots_add_gate <- function(graph, edge_id, id = NULL, metadata = list()) {
  if (is.null(id)) {
    id <- paste0("gate_", edge_id)
  }
  if (!edge_id %in% names(graph$edges)) {
    abort_groots("groots_error_not_found", "Missing edge.")
  }

  gate <- list(
    id = id,
    edge_id = edge_id,
    status = "pending",
    metadata = metadata
  )

  graph$gates[[id]] <- gate
  graph$version <- graph$version + 1L
  graph
}

#' Resolve a gate in a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param id Gate ID.
#' @export
groots_resolve_gate <- function(graph, id) {
  if (!id %in% names(graph$gates)) {
    abort_groots("groots_error_not_found", "Missing gate.")
  }
  graph$gates[[id]]$status <- "resolved"
  graph$version <- graph$version + 1L
  graph
}

#' Reopen a gate in a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param id Gate ID.
#' @export
groots_reopen_gate <- function(graph, id) {
  if (!id %in% names(graph$gates)) {
    abort_groots("groots_error_not_found", "Missing gate.")
  }
  graph$gates[[id]]$status <- "pending"
  graph$version <- graph$version + 1L
  graph
}

#' Remove a gate from a groots graph
#'
#' @param graph A \code{groots_graph}.
#' @param id Gate ID.
#' @export
groots_remove_gate <- function(graph, id) {
  if (!id %in% names(graph$gates)) {
    abort_groots("groots_error_not_found", "Missing gate.")
  }
  graph$gates[[id]] <- NULL
  graph$version <- graph$version + 1L
  graph
}
