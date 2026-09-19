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
#' @param metadata Opaque caller-owned extension data: a named list of plain
#'   data (nested lists, vectors, and scalars are fine). Closures,
#'   environments, formulas, and external pointers are rejected recursively.
#' @return A new `dagri_graph` with the node added and `version` bumped by 1;
#'   the input graph is not modified.
#'
#' @section Errors:
#' - `dagri_error_invalid_argument` when `graph` is malformed, `id`/`kind` is
#'   not a single non-empty string, params miss required `input_contract`
#'   fields, or `metadata` is not a named list of plain data.
#' - `dagri_error_unknown_kind` when `kind` is not in the registry.
#' - `dagri_error_duplicate_id` when `id` already exists.
#'
#' @examples
#' reg <- dagri_registry(dagri_kind("source"))
#' g <- dagri_add_node(
#'   dagri_graph(reg),
#'   id = "raw",
#'   kind = "source",
#'   metadata = list(uri = "source:observations_v1")
#' )
#' g$nodes[["raw"]]$metadata
#' @export
dagri_add_node <- function(graph, id, kind, label = NULL, params = list(), metadata = list()) {
  dagri_validate_graph(graph)
  dagri_validate_id(id, "id")
  dagri_validate_metadata(metadata)

  if (!is.character(kind) || length(kind) != 1 || is.na(kind) || !nzchar(kind)) {
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
#' @details `params` (when non-`NULL`) **replaces** the node's `params` outright;
#'   it is NOT merged into the existing params. Likewise `metadata` (when
#'   non-`NULL`) **replaces** the node's `metadata` outright. To merge partial
#'   updates, do it in the caller, e.g.
#'   `dagri_update_node(graph, id, params = utils::modifyList(old_params, new_params))`.
#'   A `NULL` `params`/`metadata`/`label` leaves that field untouched. Keeping
#'   this a primitive (replace, not merge) means consumers (e.g. bayesgrove's
#'   `bg_update_node()`) must opt into merge explicitly, instead of silently
#'   having their partial update destroy sibling fields.
#'
#' @param graph A \code{dagri_graph}.
#' @param id Node ID.
#' @param label Node label. `NULL` leaves the field unchanged.
#' @param params Node parameters. When non-`NULL`, **replaces** the existing
#'   `params` outright (see Details).
#' @param metadata Node metadata. When non-`NULL`, **replaces** the existing
#'   `metadata` outright (see Details); must be a named list of plain data
#'   (closures, environments, formulas, and external pointers are rejected
#'   recursively).
#' @return A new `dagri_graph` with the node updated and `version` bumped by 1
#'   (the bump happens even when every field argument is `NULL`); the input
#'   graph is not modified.
#'
#' @section Errors:
#' - `dagri_error_invalid_argument` when `graph` is malformed, `id` is not a
#'   single non-empty string, or `metadata` is not a named list of plain data.
#' - `dagri_error_not_found` when `id` is not a node in the graph.
#'
#' @examples
#' reg <- dagri_registry(dagri_kind("source"))
#' g <- dagri_add_node(dagri_graph(reg), "raw", "source")
#' g2 <- dagri_update_node(g, "raw", metadata = list(reviewed = TRUE))
#' g2$nodes[["raw"]]$metadata
#' @export
dagri_update_node <- function(graph, id, label = NULL, params = NULL, metadata = NULL) {
  dagri_validate_graph(graph)
  dagri_validate_id(id, "id")

  if (!id %in% names(graph$nodes)) {
    abort_dagri("dagri_error_not_found", sprintf("Node %s not found.", id))
  }
  if (!is.null(metadata)) {
    dagri_validate_metadata(metadata)
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
  dagri_validate_id(id, "id")

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
#' @param metadata Opaque caller-owned extension data: a named list of plain
#'   data (nested lists, vectors, and scalars are fine). Closures,
#'   environments, formulas, and external pointers are rejected recursively.
#' @return A new `dagri_graph` with the edge added and `version` bumped by 1;
#'   the input graph is not modified.
#'
#' @section Errors:
#' - `dagri_error_invalid_argument` when `graph` is malformed, `from`/`to`/`id`
#'   is not a single non-empty string, `type` is not a single non-empty string,
#'   or `metadata` is not a named list of plain data.
#' - `dagri_error_not_found` when `from` or `to` is not a node in the graph.
#' - `dagri_error_duplicate_id` when `id` already exists as an edge.
#' - `dagri_error_cycle` when the edge would create a cycle.
#'
#' @examples
#' reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
#' g <- dagri_graph(reg) |>
#'   dagri_add_node("raw", "source") |>
#'   dagri_add_node("fit", "process") |>
#'   dagri_add_edge("raw", "fit", metadata = list(weight = 2))
#' g$edges[["edge_raw_fit"]]$metadata
#' @export
dagri_add_edge <- function(graph, from, to, type = "data", id = NULL, metadata = list()) {
  dagri_validate_graph(graph)
  dagri_validate_id(from, "from")
  dagri_validate_id(to, "to")
  if (!is.null(id)) {
    dagri_validate_id(id, "id")
  }
  dagri_validate_metadata(metadata)

  if (!is.character(type) || length(type) != 1 || is.na(type) || !nzchar(type)) {
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

#' Update an edge in a dagriculture graph
#'
#' @details `metadata` (when non-`NULL`) **replaces** the edge's `metadata`
#'   outright; it is NOT merged into the existing metadata. To merge partial
#'   updates, do it in the caller, e.g.
#'   `dagri_update_edge(graph, edge_id, metadata = utils::modifyList(old_metadata, new_metadata))`.
#'   A `NULL` `type`/`metadata` leaves that field untouched. This mirrors
#'   `dagri_update_node()`'s replace-not-merge primitive: consumers must opt
#'   into merge explicitly instead of silently having a partial update destroy
#'   sibling fields.
#'
#'   Known boundary: `dagri_graph_diff()` is a structural id diff — it reports
#'   only added/removed node and edge ids, so metadata and `type` edits made
#'   here do not surface in its output.
#'
#' @param graph A \code{dagri_graph}.
#' @param edge_id Edge ID.
#' @param type Edge type. When non-`NULL`, must be a single non-empty string
#'   and **replaces** the existing `type` (see Details).
#' @param metadata Edge metadata. When non-`NULL`, **replaces** the existing
#'   `metadata` outright (see Details); must be a named list of plain data
#'   (closures, environments, formulas, and external pointers are rejected
#'   recursively).
#' @return A new `dagri_graph` with the edge updated and `version` bumped by 1
#'   (the bump happens even when both field arguments are `NULL`); the input
#'   graph is not modified. `from`/`to` cannot be changed — remove and re-add
#'   the edge to rewire it.
#'
#' @section Errors:
#' - `dagri_error_invalid_argument` when `graph` is malformed, `edge_id` is
#'   not a single non-empty string, `type` is not a single non-empty string,
#'   or `metadata` is not a named list of plain data.
#' - `dagri_error_not_found` when `edge_id` is not an edge in the graph.
#'
#' @examples
#' reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
#' g <- dagri_graph(reg) |>
#'   dagri_add_node("raw", "source") |>
#'   dagri_add_node("fit", "process") |>
#'   dagri_add_edge("raw", "fit", id = "e1", metadata = list(weight = 1))
#'
#' g2 <- dagri_update_edge(g, "e1", type = "control", metadata = list(weight = 2))
#' g2$edges[["e1"]]$type
#' g2$edges[["e1"]]$metadata
#' @export
dagri_update_edge <- function(graph, edge_id, type = NULL, metadata = NULL) {
  dagri_validate_graph(graph)
  dagri_validate_id(edge_id, "edge_id")

  if (!edge_id %in% names(graph$edges)) {
    abort_dagri("dagri_error_not_found", sprintf("Edge %s not found.", edge_id))
  }

  if (!is.null(type)) {
    if (!is.character(type) || length(type) != 1 || is.na(type) || !nzchar(type)) {
      abort_dagri(
        "dagri_error_invalid_argument",
        sprintf("`type` must be a single character string, got %s.", class(type)[1])
      )
    }
  }
  if (!is.null(metadata)) {
    dagri_validate_metadata(metadata)
  }

  edge <- graph$edges[[edge_id]]
  if (!is.null(type)) {
    edge$type <- type
  }
  if (!is.null(metadata)) {
    edge$metadata <- metadata
  }

  graph$edges[[edge_id]] <- edge
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
  dagri_validate_id(id, "id")

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
#' @param edge_id Edge ID.
#' @param id Optional Gate ID.
#' @param metadata Opaque caller-owned extension data: a named list of plain
#'   data (nested lists, vectors, and scalars are fine). Closures,
#'   environments, formulas, and external pointers are rejected recursively.
#' @return A new `dagri_graph` with the gate added (status "pending") and
#'   `version` bumped by 1; the input graph is not modified.
#'
#' @section Errors:
#' - `dagri_error_invalid_argument` when `graph` is malformed, `edge_id`/`id`
#'   is not a single non-empty string, or `metadata` is not a named list of
#'   plain data.
#' - `dagri_error_not_found` when `edge_id` is not an edge in the graph.
#' - `dagri_error_duplicate_id` when `id` already exists as a gate.
#'
#' @examples
#' reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
#' g <- dagri_graph(reg) |>
#'   dagri_add_node("raw", "source") |>
#'   dagri_add_node("fit", "process") |>
#'   dagri_add_edge("raw", "fit", id = "e1") |>
#'   dagri_add_gate("e1", metadata = list(approver = "reviewer_a"))
#' g$gates[["gate_e1"]]$metadata
#' @export
dagri_add_gate <- function(graph, edge_id, id = NULL, metadata = list()) {
  dagri_validate_graph(graph)
  dagri_validate_id(edge_id, "edge_id")
  if (!is.null(id)) {
    dagri_validate_id(id, "id")
  }
  dagri_validate_metadata(metadata)

  if (is.null(id)) {
    id <- paste0("gate_", edge_id)
  }
  if (!edge_id %in% names(graph$edges)) {
    abort_dagri("dagri_error_not_found", sprintf("Edge %s not found.", edge_id))
  }
  if (id %in% names(graph$gates)) {
    abort_dagri("dagri_error_duplicate_id", sprintf("Duplicate gate id: %s.", id))
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

#' Update a gate in a dagriculture graph
#'
#' @details `metadata` (when non-`NULL`) **replaces** the gate's `metadata`
#'   outright; it is NOT merged into the existing metadata. To merge partial
#'   updates, do it in the caller, e.g.
#'   `dagri_update_gate(graph, gate_id, metadata = utils::modifyList(old_metadata, new_metadata))`.
#'   A `NULL` `metadata` leaves the field untouched. This mirrors
#'   `dagri_update_node()`'s replace-not-merge primitive. Gate `status` is not
#'   updatable here: use [dagri_resolve_gate()] / [dagri_reopen_gate()], which
#'   own the status lifecycle.
#'
#'   Known boundary: `dagri_graph_diff()` is a structural id diff — it reports
#'   only added/removed node and edge ids, so metadata edits made here do not
#'   surface in its output.
#'
#' @param graph A \code{dagri_graph}.
#' @param gate_id Gate ID.
#' @param metadata Gate metadata. When non-`NULL`, **replaces** the existing
#'   `metadata` outright (see Details); must be a named list of plain data
#'   (closures, environments, formulas, and external pointers are rejected
#'   recursively).
#' @return A new `dagri_graph` with the gate updated and `version` bumped by 1
#'   (the bump happens even when `metadata` is `NULL`); the input graph is not
#'   modified.
#'
#' @section Errors:
#' - `dagri_error_invalid_argument` when `graph` is malformed, `gate_id` is
#'   not a single non-empty string, or `metadata` is not a named list of plain
#'   data.
#' - `dagri_error_not_found` when `gate_id` is not a gate in the graph.
#'
#' @examples
#' reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
#' g <- dagri_graph(reg) |>
#'   dagri_add_node("raw", "source") |>
#'   dagri_add_node("fit", "process") |>
#'   dagri_add_edge("raw", "fit", id = "e1") |>
#'   dagri_add_gate("e1", id = "g1", metadata = list(approver = "reviewer_a"))
#'
#' g2 <- dagri_update_gate(g, "g1", metadata = list(approver = "reviewer_b"))
#' g2$gates[["g1"]]$metadata
#' @export
dagri_update_gate <- function(graph, gate_id, metadata = NULL) {
  dagri_validate_graph(graph)
  dagri_validate_id(gate_id, "gate_id")

  if (!gate_id %in% names(graph$gates)) {
    abort_dagri("dagri_error_not_found", sprintf("Gate %s not found.", gate_id))
  }

  if (!is.null(metadata)) {
    dagri_validate_metadata(metadata)
  }

  gate <- graph$gates[[gate_id]]
  if (!is.null(metadata)) {
    gate$metadata <- metadata
  }

  graph$gates[[gate_id]] <- gate
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
  dagri_validate_id(id, "id")

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
  dagri_validate_id(id, "id")

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
  dagri_validate_id(id, "id")

  if (!id %in% names(graph$gates)) {
    abort_dagri("dagri_error_not_found", sprintf("Gate %s not found.", id))
  }
  graph$gates[[id]] <- NULL
  graph$version <- graph$version + 1L
  graph
}
