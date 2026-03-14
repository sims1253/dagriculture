#' Add a node to a dagriculture graph
#'
#' Nodes are created with state "new". Call \code{dagri_recompute_state()} to
#' compute structural readiness (state becomes "ready" or "blocked").
#'
#' @param graph A \code{dagri_graph}.
#' @param id Node ID.
#' @param kind Node kind.
#' @param label Node label.
#' @param params Node parameters.
#' @param metadata Node metadata.
#' @export
dagri_add_node <- function(graph, id, kind, label = NULL, params = list(), metadata = list()) {
  dagri_validate_graph(graph)

  if (!is.character(kind) || length(kind) != 1) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf("`kind` must be a single character string, got %s.", class(kind)[1])
    )
  }
  if (!kind %in% names(graph$registry$kinds)) {
    abort_dagri("dagri_error_unknown_kind", sprintf("Unknown node kind: %s.", kind))
  }
  if (id %in% names(graph$nodes)) {
    abort_dagri("dagri_error_duplicate_id", sprintf("Duplicate node id: %s.", id))
  }

  kind_obj <- graph$registry$kinds[[kind]]
  if (!is.null(kind_obj$input_contract)) {
    contract <- kind_obj$input_contract
    missing_params <- setdiff(names(contract), names(params))
    if (length(missing_params) > 0) {
      abort_dagri(
        "dagri_error_invalid_argument",
        sprintf(
          "Node '%s' of kind '%s' is missing required input_contract fields: %s.",
          id,
          kind,
          paste(missing_params, collapse = ", ")
        )
      )
    }
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

#' Update a node in a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param id Node ID.
#' @param label Node label.
#' @param params Node parameters.
#' @param metadata Node metadata.
#' @export
dagri_update_node <- function(graph, id, label = NULL, params = NULL, metadata = NULL) {
  dagri_validate_graph(graph)

  if (!id %in% names(graph$nodes)) {
    abort_dagri("dagri_error_not_found", sprintf("Node %s not found.", id))
  }

  node <- graph$nodes[[id]]
  if (!is.null(label)) {
    node$label <- label
  }
  if (!is.null(params)) {
    node$params <- params
  }
  if (!is.null(metadata)) {
    node$metadata <- metadata
  }

  graph$nodes[[id]] <- node
  graph$version <- graph$version + 1L
  graph
}

#' Remove a node from a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param id Node ID.
#' @export
dagri_remove_node <- function(graph, id) {
  dagri_validate_graph(graph)

  if (!id %in% names(graph$nodes)) {
    abort_dagri("dagri_error_not_found", sprintf("Node %s not found.", id))
  }

  incident_edge_ids <- names(Filter(
    function(edge) identical(edge$from, id) || identical(edge$to, id),
    graph$edges %||% list()
  ))
  if (length(incident_edge_ids) > 0) {
    graph$edges[incident_edge_ids] <- NULL

    gate_ids <- names(Filter(
      function(gate) gate$edge_id %in% incident_edge_ids,
      graph$gates %||% list()
    ))
    if (length(gate_ids) > 0) {
      graph$gates[gate_ids] <- NULL
    }
  }

  graph$nodes[[id]] <- NULL
  graph$version <- graph$version + 1L
  graph
}

#' Add an edge to a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param from Upstream node ID.
#' @param to Downstream node ID.
#' @param type Edge type.
#' @param id Optional Edge ID.
#' @param metadata Edge metadata.
#' @export
dagri_add_edge <- function(graph, from, to, type = "data", id = NULL, metadata = list()) {
  dagri_validate_graph(graph)

  if (!is.character(type) || length(type) != 1) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf("`type` must be a single character string, got %s.", class(type)[1])
    )
  }
  if (is.null(id)) {
    id <- paste0("edge_", from, "_", to)
  }
  if (!from %in% names(graph$nodes)) {
    abort_dagri("dagri_error_not_found", sprintf("Node %s not found.", from))
  }
  if (!to %in% names(graph$nodes)) {
    abort_dagri("dagri_error_not_found", sprintf("Node %s not found.", to))
  }
  if (id %in% names(graph$edges)) {
    abort_dagri("dagri_error_duplicate_id", sprintf("Duplicate edge id: %s.", id))
  }

  if (dagri_has_path(graph, to, from)) {
    abort_dagri("dagri_error_cycle", "Cycle detected.")
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

#' Remove an edge from a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param id Edge ID.
#' @export
dagri_remove_edge <- function(graph, id) {
  dagri_validate_graph(graph)

  if (!id %in% names(graph$edges)) {
    abort_dagri("dagri_error_not_found", sprintf("Edge %s not found.", id))
  }

  gate_ids <- names(Filter(
    function(gate) identical(gate$edge_id, id),
    graph$gates %||% list()
  ))
  if (length(gate_ids) > 0) {
    graph$gates[gate_ids] <- NULL
  }

  graph$edges[[id]] <- NULL
  graph$version <- graph$version + 1L
  graph
}

#' Add a gate to a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param edge Edge ID.
#' @param id Optional Gate ID.
#' @param metadata Gate metadata.
#' @export
dagri_add_gate <- function(graph, edge, id = NULL, metadata = list()) {
  dagri_validate_graph(graph)

  if (is.null(id)) {
    id <- paste0("gate_", edge)
  }
  if (!edge %in% names(graph$edges)) {
    abort_dagri("dagri_error_not_found", sprintf("Edge %s not found.", edge))
  }
  if (id %in% names(graph$gates)) {
    abort_dagri("dagri_error_duplicate_id", sprintf("Duplicate gate id: %s.", id))
  }

  gate <- list(
    id = id,
    edge_id = edge,
    status = "pending",
    metadata = metadata
  )

  graph$gates[[id]] <- gate
  graph$version <- graph$version + 1L
  graph
}

#' Resolve a gate in a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param id Gate ID.
#' @export
dagri_resolve_gate <- function(graph, id) {
  dagri_validate_graph(graph)

  if (!id %in% names(graph$gates)) {
    abort_dagri("dagri_error_not_found", sprintf("Gate %s not found.", id))
  }
  graph$gates[[id]]$status <- "resolved"
  graph$version <- graph$version + 1L
  graph
}

#' Reopen a gate in a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param id Gate ID.
#' @export
dagri_reopen_gate <- function(graph, id) {
  dagri_validate_graph(graph)

  if (!id %in% names(graph$gates)) {
    abort_dagri("dagri_error_not_found", sprintf("Gate %s not found.", id))
  }
  graph$gates[[id]]$status <- "pending"
  graph$version <- graph$version + 1L
  graph
}

#' Remove a gate from a dagriculture graph
#'
#' @param graph A \code{dagri_graph}.
#' @param id Gate ID.
#' @export
dagri_remove_gate <- function(graph, id) {
  dagri_validate_graph(graph)

  if (!id %in% names(graph$gates)) {
    abort_dagri("dagri_error_not_found", sprintf("Gate %s not found.", id))
  }
  graph$gates[[id]] <- NULL
  graph$version <- graph$version + 1L
  graph
}
